#!/bin/bash
###############################################################################
#  TP DataWarehouse - Solution 100% Docker Compose pour Arch Linux
#  ================================================================
#  
#  ARCHITECTURE : Tout tourne dans des conteneurs Docker orchestrés par
#  docker-compose. PAS de Docker-in-Docker. Ton Arch Linux n'a besoin
#  QUE de Docker + Docker Compose installés.
#
#  Conteneurs :
#    1. mssql      → SQL Server 2022 (base de données)
#    2. etl-runner → Python + ODBC (exécute les scripts ETL)
#    3. metabase   → Metabase (visualisation, remplace Power BI)
#
#  Usage :
#    chmod +x setup.sh && ./setup.sh
#
#  Ou manuellement :
#    docker compose up -d mssql        # 1. Lancer SQL Server
#    ./setup.sh init                   # 2. Créer le DW + restaurer AW
#    ./setup.sh etl                    # 3. Exécuter les ETL
#    docker compose up -d metabase     # 4. Lancer Metabase
#
###############################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SA_PASSWORD="StrongP@ssw0rd2025!"
COMPOSE_CMD=""

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()     { echo -e "${RED}[ERR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $1${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════════════════${NC}\n"; }

# Detect docker compose command
detect_compose() {
    if docker compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif docker-compose version &>/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        log_err "Ni 'docker compose' ni 'docker-compose' trouvé."
        echo "  → sudo pacman -S docker docker-compose"
        exit 1
    fi
    log_ok "Compose trouvé : $COMPOSE_CMD"
}

# Run SQL inside the mssql container
run_sql() {
    local query="$1"
    local db="${2:-master}"
    docker exec mssql_dw /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U SA -P "$SA_PASSWORD" -C -d "$db" -Q "$query" -b 2>&1
}

run_sql_file() {
    local file="$1"
    local db="${2:-master}"
    docker exec -i mssql_dw /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U SA -P "$SA_PASSWORD" -C -d "$db" -b < "$file" 2>&1
}

wait_for_sql() {
    log_info "Attente de SQL Server (peut prendre 30-60s au premier lancement)..."
    local max=40
    for i in $(seq 1 $max); do
        if docker exec mssql_dw /opt/mssql-tools18/bin/sqlcmd \
            -S localhost -U SA -P "$SA_PASSWORD" -C -Q "SELECT 1" &>/dev/null; then
            log_ok "SQL Server est prêt !"
            return 0
        fi
        printf "."
        sleep 3
    done
    echo ""
    log_err "SQL Server n'a pas démarré. Vérifier : docker logs mssql_dw"
    exit 1
}

# ============================================================================
# GENERATE ALL PROJECT FILES
# ============================================================================
generate_files() {
    log_step "Génération de l'arborescence du projet"

    mkdir -p "$PROJECT_DIR"/{sql,etl,screenshots,backups,metabase-data}

    # ================================================================
    # docker-compose.yml
    # ================================================================
    cat > "$PROJECT_DIR/docker-compose.yml" << 'EOYML'
# TP Datawarehouse - Docker Compose
# Tout l'environnement dans des conteneurs

services:
  # ── SQL Server 2022 ──────────────────────────────────────────
  mssql:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: mssql_dw
    hostname: mssql_dw
    environment:
      ACCEPT_EULA: "Y"
      MSSQL_SA_PASSWORD: "StrongP@ssw0rd2025!"
      MSSQL_PID: "Developer"
    ports:
      - "1433:1433"
    volumes:
      - mssql-data:/var/opt/mssql
      - ./backups:/var/opt/mssql/backup
      - ./sql:/sql
    networks:
      - dw-net
    restart: unless-stopped
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P "StrongP@ssw0rd2025!" -C -Q "SELECT 1" || exit 1
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  # ── ETL Runner (Python + ODBC) ──────────────────────────────
  etl-runner:
    build:
      context: .
      dockerfile: Dockerfile.etl
    container_name: etl_runner
    depends_on:
      mssql:
        condition: service_healthy
    volumes:
      - ./etl:/app/etl
      - ./sql:/app/sql
    networks:
      - dw-net
    environment:
      SQL_SERVER: mssql_dw
      SA_PASSWORD: "StrongP@ssw0rd2025!"
    # Le conteneur reste en veille, on y exécute des commandes
    command: ["tail", "-f", "/dev/null"]

  # ── Metabase (Visualisation / Power BI replacement) ─────────
  metabase:
    image: metabase/metabase:latest
    container_name: metabase_dw
    depends_on:
      mssql:
        condition: service_healthy
    ports:
      - "3000:3000"
    volumes:
      - ./metabase-data:/metabase-data
    environment:
      MB_DB_FILE: /metabase-data/metabase.db
    networks:
      - dw-net
    restart: unless-stopped

volumes:
  mssql-data:

networks:
  dw-net:
    driver: bridge
EOYML
    log_ok "docker-compose.yml créé"

    # ================================================================
    # Dockerfile.etl  (Python + ODBC Driver)
    # ================================================================
    cat > "$PROJECT_DIR/Dockerfile.etl" << 'EODOCKERFILE'
FROM python:3.11-slim-bookworm

# Installer les dépendances système + driver ODBC Microsoft
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl gnupg2 unixodbc-dev apt-transport-https && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] \
        https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Python packages
RUN pip install --no-cache-dir pyodbc

WORKDIR /app
EODOCKERFILE
    log_ok "Dockerfile.etl créé"

    # ================================================================
    # SQL : TP1 - Création du DW
    # ================================================================
    cat > "$PROJECT_DIR/sql/01_create_database.sql" << 'EOSQL'
USE master;
GO
IF DB_ID('LightAdventureWorksDW') IS NOT NULL
    DROP DATABASE LightAdventureWorksDW;
GO
CREATE DATABASE LightAdventureWorksDW
ON PRIMARY (
    NAME = N'LightAdventureWorksDW',
    FILENAME = N'/var/opt/mssql/data/LightAdventureWorksDW.mdf',
    SIZE = 307200KB, FILEGROWTH = 10240KB
)
LOG ON (
    NAME = N'LightAdventureWorksDW_log',
    FILENAME = N'/var/opt/mssql/data/LightAdventureWorksDW_log.ldf',
    SIZE = 51200KB, FILEGROWTH = 10%
);
GO
ALTER DATABASE LightAdventureWorksDW SET RECOVERY SIMPLE WITH NO_WAIT;
GO
PRINT '>>> Base LightAdventureWorksDW créée.';
GO
EOSQL

    cat > "$PROJECT_DIR/sql/02_create_dimensions.sql" << 'EOSQL'
USE LightAdventureWorksDW;
GO

-- Dimension Customers
IF OBJECT_ID('dbo.InternetSales','U') IS NOT NULL DROP TABLE dbo.InternetSales;
IF OBJECT_ID('dbo.Customers','U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Products','U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Dates','U') IS NOT NULL DROP TABLE dbo.Dates;
GO

CREATE TABLE dbo.Customers (
    CustomerKey         INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerAlternateKey INT          NOT NULL,
    FullName            NVARCHAR(150) NULL,
    Address             NVARCHAR(150) NULL,
    EmailAddress        NVARCHAR(50)  NULL,
    City                NVARCHAR(30)  NULL,
    StateProvince       NVARCHAR(50)  NULL,
    CountryRegion       NVARCHAR(50)  NULL
);
GO

-- Dimension Products (ProductKey = business key, PAS IDENTITY)
CREATE TABLE dbo.Products (
    ProductKey       INT           NOT NULL PRIMARY KEY,
    ProductName      NVARCHAR(50)  NULL,
    Color            NVARCHAR(15)  NULL,
    Size             NVARCHAR(50)  NULL,
    SubcategoryName  NVARCHAR(50)  NULL,
    CategoryName     NVARCHAR(50)  NULL
);
GO

-- Dimension Dates
CREATE TABLE dbo.Dates (
    DateKey          INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    FullDate         DATE          NOT NULL,
    MonthNumberName  NVARCHAR(15)  NULL,
    CalendarQuarter  TINYINT       NULL,
    CalendarYear     SMALLINT      NULL
);
GO

PRINT '>>> Dimensions Customers, Products, Dates créées.';
GO
EOSQL

    cat > "$PROJECT_DIR/sql/03_create_fact_table.sql" << 'EOSQL'
USE LightAdventureWorksDW;
GO

CREATE TABLE dbo.InternetSales (
    InternetSalesKey INT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerKey      INT       NOT NULL,
    ProductKey       INT       NOT NULL,
    DateKey          INT       NOT NULL,
    OrderQuantity    SMALLINT  NOT NULL DEFAULT 0,
    SalesAmount      MONEY     NOT NULL DEFAULT 0
);
GO

ALTER TABLE dbo.InternetSales ADD CONSTRAINT
    FK_InternetSales_Customers FOREIGN KEY(CustomerKey)
    REFERENCES dbo.Customers(CustomerKey);
ALTER TABLE dbo.InternetSales ADD CONSTRAINT
    FK_InternetSales_Products FOREIGN KEY(ProductKey)
    REFERENCES dbo.Products(ProductKey);
ALTER TABLE dbo.InternetSales ADD CONSTRAINT
    FK_InternetSales_Dates FOREIGN KEY(DateKey)
    REFERENCES dbo.Dates(DateKey);
GO

PRINT '>>> Table de faits InternetSales créée (star schema).';
GO
EOSQL

    cat > "$PROJECT_DIR/sql/04_restore_adventureworks.sql" << 'EOSQL'
USE master;
GO
IF DB_ID('AdventureWorks2022') IS NOT NULL
    DROP DATABASE AdventureWorks2022;
GO
RESTORE DATABASE AdventureWorks2022
FROM DISK = '/var/opt/mssql/backup/AdventureWorks2022.bak'
WITH MOVE 'AdventureWorks2022' TO '/var/opt/mssql/data/AdventureWorks2022.mdf',
     MOVE 'AdventureWorks2022_log' TO '/var/opt/mssql/data/AdventureWorks2022_log.ldf',
     REPLACE;
GO
PRINT '>>> AdventureWorks2022 restaurée.';
GO
EOSQL

    cat > "$PROJECT_DIR/sql/05_verify_schema.sql" << 'EOSQL'
USE LightAdventureWorksDW;
GO
PRINT '=== TABLES DU DATAWAREHOUSE ===';
SELECT t.name AS TableName, SUM(p.rows) AS RowCount
FROM sys.tables t
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id < 2
GROUP BY t.name ORDER BY t.name;
GO
PRINT '=== CLÉS ÉTRANGÈRES ===';
SELECT fk.name AS FK_Name, tp.name AS ParentTable, tr.name AS RefTable
FROM sys.foreign_keys fk
JOIN sys.tables tp ON fk.parent_object_id = tp.object_id
JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id;
GO
EOSQL
    log_ok "Scripts SQL créés (01 à 05)"

    # ================================================================
    # ETL : TP2 - Dimensions
    # ================================================================
    cat > "$PROJECT_DIR/etl/etl_dimensions.py" << 'EOPY'
#!/usr/bin/env python3
"""
TP2 : ETL des Dimensions — Python/pyodbc (remplace SSIS)
"""
import os, sys, pyodbc, calendar
from datetime import datetime

SERVER = os.environ.get("SQL_SERVER", "mssql_dw")
PASSWORD = os.environ.get("SA_PASSWORD", "StrongP@ssw0rd2025!")
CONN = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER},1433;UID=SA;PWD={PASSWORD};TrustServerCertificate=yes;"

def conn(db="master"):
    return pyodbc.connect(CONN + f"DATABASE={db};")

def log(m):
    print(f"[{datetime.now():%H:%M:%S}] {m}", flush=True)

# ─── I. PRODUCT ──────────────────────────────────────────────
def etl_product():
    log("═" * 55)
    log("I. ETL Dimension Product")
    log("═" * 55)

    q = """
    SELECT pro.ProductID, pro.Name AS ProductName, pro.Color, pro.[Size],
           sub.Name AS SubcategoryName, cat.Name AS CategoryName
    FROM Production.Product AS pro
    INNER JOIN Production.ProductSubcategory AS sub
        ON pro.ProductSubcategoryID = sub.ProductSubcategoryID
    INNER JOIN Production.ProductCategory AS cat
        ON sub.ProductCategoryID = cat.ProductCategoryID
    ORDER BY pro.ProductID
    """
    src = conn("AdventureWorks2022")
    rows = src.cursor().execute(q).fetchall()
    log(f"  [Extract] {len(rows)} lignes extraites")

    dst = conn("LightAdventureWorksDW")
    c = dst.cursor()
    c.execute("DELETE FROM dbo.InternetSales"); c.execute("DELETE FROM dbo.Products")
    dst.commit()

    n = 0
    for r in rows:
        c.execute("INSERT INTO dbo.Products VALUES (?,?,?,?,?,?)",
                   r.ProductID, r.ProductName, r.Color, r.Size,
                   r.SubcategoryName, r.CategoryName)
        n += 1
    dst.commit()
    log(f"  [Load] ✓ {n} lignes → Products")

    c.execute("SELECT TOP 3 * FROM dbo.Products ORDER BY ProductKey")
    for r in c.fetchall():
        log(f"    | {r.ProductKey:>4} | {r.ProductName:<35} | {str(r.CategoryName):<12} |")
    src.close(); dst.close()
    return n

# ─── II. CUSTOMER ────────────────────────────────────────────
def etl_customer():
    log("═" * 55)
    log("II. ETL Dimension Customer")
    log("═" * 55)

    q = """
    SELECT c.CustomerID, p.FirstName, p.MiddleName, p.LastName,
           ea.EmailAddress, a.AddressLine1, a.AddressLine2,
           a.City, sp.Name AS StateProvince, cr.Name AS CountryRegion
    FROM Sales.Customer AS c
    INNER JOIN Person.Person AS p ON c.PersonID = p.BusinessEntityID
    LEFT JOIN Person.EmailAddress AS ea ON p.BusinessEntityID = ea.BusinessEntityID
    LEFT JOIN Person.BusinessEntityAddress AS bea ON p.BusinessEntityID = bea.BusinessEntityID
    LEFT JOIN Person.Address AS a ON bea.AddressID = a.AddressID
    LEFT JOIN Person.StateProvince AS sp ON a.StateProvinceID = sp.StateProvinceID
    LEFT JOIN Person.CountryRegion AS cr ON sp.CountryRegionCode = cr.CountryRegionCode
    ORDER BY c.CustomerID
    """
    src = conn("AdventureWorks2022")
    rows = src.cursor().execute(q).fetchall()
    log(f"  [Extract] {len(rows)} lignes extraites")

    seen = set(); transformed = []
    for r in rows:
        if r.CustomerID in seen: continue
        seen.add(r.CustomerID)
        parts = [r.FirstName]
        if r.MiddleName: parts.append(r.MiddleName)
        parts.append(r.LastName)
        addr = (r.AddressLine1 or '')
        if r.AddressLine2: addr += ' ' + r.AddressLine2
        transformed.append((r.CustomerID, ' '.join(parts),
                            addr or None, r.EmailAddress,
                            r.City, r.StateProvince, r.CountryRegion))
    log(f"  [Transform] {len(transformed)} clients uniques (doublons supprimés)")

    dst = conn("LightAdventureWorksDW")
    c = dst.cursor()
    c.execute("DELETE FROM dbo.InternetSales"); c.execute("DELETE FROM dbo.Customers")
    c.execute("DBCC CHECKIDENT ('dbo.Customers', RESEED, 0)")
    dst.commit()

    n = 0
    for t in transformed:
        c.execute("""INSERT INTO dbo.Customers
            (CustomerAlternateKey,FullName,Address,EmailAddress,City,StateProvince,CountryRegion)
            VALUES (?,?,?,?,?,?,?)""", t)
        n += 1
    dst.commit()
    log(f"  [Load] ✓ {n} lignes → Customers")
    src.close(); dst.close()
    return n

# ─── III. DATE ───────────────────────────────────────────────
def etl_date():
    log("═" * 55)
    log("III. ETL Dimension Date")
    log("═" * 55)

    q = "SELECT DISTINCT CAST(DueDate AS DATE) AS FullDate FROM Sales.SalesOrderHeader ORDER BY FullDate"
    src = conn("AdventureWorks2022")
    rows = src.cursor().execute(q).fetchall()
    log(f"  [Extract] {len(rows)} dates distinctes")

    transformed = []
    for r in rows:
        d = r.FullDate
        transformed.append((d, calendar.month_name[d.month],
                            (d.month-1)//3+1, d.year))

    dst = conn("LightAdventureWorksDW")
    c = dst.cursor()
    c.execute("DELETE FROM dbo.InternetSales"); c.execute("DELETE FROM dbo.Dates")
    c.execute("DBCC CHECKIDENT ('dbo.Dates', RESEED, 0)")
    dst.commit()

    n = 0
    for t in transformed:
        c.execute("INSERT INTO dbo.Dates (FullDate,MonthNumberName,CalendarQuarter,CalendarYear) VALUES (?,?,?,?)", t)
        n += 1
    dst.commit()
    log(f"  [Load] ✓ {n} lignes → Dates")
    src.close(); dst.close()
    return n

# ─── MAIN ────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n" + "=" * 55)
    print("  TP2 — ETL Dimensions (Python/pyodbc)")
    print("=" * 55 + "\n")
    try:
        np = etl_product()
        nc = etl_customer()
        nd = etl_date()
        print(f"\n{'='*55}")
        print(f"  RÉSUMÉ : Products={np} | Customers={nc} | Dates={nd}")
        print(f"{'='*55}\n")
    except Exception as e:
        log(f"ERREUR: {e}")
        import traceback; traceback.print_exc()
        sys.exit(1)
EOPY

    # ================================================================
    # ETL : TP3 - Table de Faits
    # ================================================================
    cat > "$PROJECT_DIR/etl/etl_fact_internetsales.py" << 'EOPY'
#!/usr/bin/env python3
"""
TP3 : ETL Table de Faits InternetSales — Python/pyodbc (remplace SSIS)
"""
import os, sys, pyodbc
from datetime import datetime

SERVER = os.environ.get("SQL_SERVER", "mssql_dw")
PASSWORD = os.environ.get("SA_PASSWORD", "StrongP@ssw0rd2025!")
CONN = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER},1433;UID=SA;PWD={PASSWORD};TrustServerCertificate=yes;"

def conn(db="master"):
    return pyodbc.connect(CONN + f"DATABASE={db};")

def log(m):
    print(f"[{datetime.now():%H:%M:%S}] {m}", flush=True)

def etl_fact():
    log("═" * 55)
    log("TP3 — ETL Table de Faits InternetSales")
    log("═" * 55)

    # ── EXTRACT ──
    q = """
    SELECT sod.OrderQty, sod.UnitPrice, sod.UnitPriceDiscount,
           soh.DueDate, soh.CustomerID, sod.ProductID
    FROM Sales.SalesOrderHeader AS soh
    INNER JOIN Sales.SalesOrderDetail AS sod
        ON soh.SalesOrderID = sod.SalesOrderID
    """
    src = conn("AdventureWorks2022")
    rows = src.cursor().execute(q).fetchall()
    log(f"  [Extract] {len(rows)} lignes extraites")

    # ── TRANSFORM (colonnes dérivées) ──
    transformed = []
    for r in rows:
        qty = int(r.OrderQty)
        amount = float(r.UnitPrice) * qty * (1 - float(r.UnitPriceDiscount))
        due = r.DueDate.date() if hasattr(r.DueDate, 'date') else r.DueDate
        transformed.append({
            'qty': qty, 'amount': round(amount, 4),
            'due': due, 'cid': r.CustomerID, 'pid': r.ProductID
        })
    log(f"  [Transform] {len(transformed)} lignes transformées")

    # ── LOOKUP (correspondance dimensions) ──
    dw = conn("LightAdventureWorksDW")
    c = dw.cursor()

    c.execute("SELECT ProductKey FROM dbo.Products")
    pkeys = {r.ProductKey for r in c.fetchall()}

    c.execute("SELECT DateKey, FullDate FROM dbo.Dates")
    dlookup = {r.FullDate: r.DateKey for r in c.fetchall()}

    c.execute("SELECT CustomerKey, CustomerAlternateKey FROM dbo.Customers")
    clookup = {r.CustomerAlternateKey: r.CustomerKey for r in c.fetchall()}

    log(f"  [Lookup] Products={len(pkeys)} | Dates={len(dlookup)} | Customers={len(clookup)}")

    matched = []
    skip = {'product': 0, 'date': 0, 'customer': 0}
    for t in transformed:
        if t['pid'] not in pkeys:    skip['product'] += 1; continue
        if t['due'] not in dlookup:  skip['date'] += 1; continue
        if t['cid'] not in clookup:  skip['customer'] += 1; continue
        matched.append((clookup[t['cid']], t['pid'], dlookup[t['due']], t['qty'], t['amount']))

    log(f"  [Match] {len(matched)} lignes avec correspondance")
    for k, v in skip.items():
        if v > 0: log(f"  [Skip] {v} sans correspondance {k}")

    # ── LOAD ──
    c.execute("DELETE FROM dbo.InternetSales")
    c.execute("DBCC CHECKIDENT ('dbo.InternetSales', RESEED, 0)")
    dw.commit()

    batch = 1000
    for i in range(0, len(matched), batch):
        c.executemany(
            "INSERT INTO dbo.InternetSales (CustomerKey,ProductKey,DateKey,OrderQuantity,SalesAmount) VALUES (?,?,?,?,?)",
            matched[i:i+batch])
    dw.commit()
    log(f"  [Load] ✓ {len(matched)} lignes → InternetSales")

    # Stats
    c.execute("""
        SELECT COUNT(*) AS N, SUM(CAST(SalesAmount AS FLOAT)) AS Total,
               COUNT(DISTINCT CustomerKey) AS Clients, COUNT(DISTINCT ProductKey) AS Produits
        FROM dbo.InternetSales
    """)
    s = c.fetchone()
    log(f"\n  STATS : {s.N} ventes | CA=${s.Total:,.2f} | {s.Clients} clients | {s.Produits} produits")

    src.close(); dw.close()
    return len(matched)

if __name__ == "__main__":
    print("\n" + "=" * 55)
    print("  TP3 — ETL Faits InternetSales (Python/pyodbc)")
    print("=" * 55 + "\n")
    try:
        n = etl_fact()
        print(f"\n  ✓ TERMINÉ : {n} lignes dans InternetSales\n")
    except Exception as e:
        log(f"ERREUR: {e}")
        import traceback; traceback.print_exc()
        sys.exit(1)
EOPY
    log_ok "Scripts ETL Python créés"

    # ================================================================
    # Screenshot helper
    # ================================================================
    cat > "$PROJECT_DIR/screenshot.sh" << 'EOSS'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)/screenshots"
mkdir -p "$DIR"
NAME="${1:-capture}"
FILE="$DIR/${NAME}_$(date +%Y%m%d_%H%M%S).png"

for tool in flameshot grim scrot spectacle gnome-screenshot import; do
    if command -v "$tool" &>/dev/null; then
        case "$tool" in
            flameshot)       flameshot gui --path "$DIR" ;;
            grim)            grim -g "$(slurp)" "$FILE" ;;
            scrot)           scrot -s "$FILE" ;;
            spectacle)       spectacle -r -b -o "$FILE" ;;
            gnome-screenshot) gnome-screenshot -a -f "$FILE" ;;
            import)          import "$FILE" ;;
        esac
        echo "✓ Sauvegardé : $FILE"
        exit 0
    fi
done
echo "Aucun outil trouvé. Installe : sudo pacman -S scrot  (ou flameshot, grim)"
EOSS
    chmod +x "$PROJECT_DIR/screenshot.sh"
    log_ok "Utilitaire screenshot.sh créé"

    log_ok "Tous les fichiers générés dans $PROJECT_DIR/"
}

# ============================================================================
# COMMANDS
# ============================================================================
cmd_up() {
    log_step "Démarrage des conteneurs (SQL Server + build ETL)"
    cd "$PROJECT_DIR"
    $COMPOSE_CMD up -d --build mssql etl-runner
    wait_for_sql
    log_ok "SQL Server et ETL Runner sont prêts."
}

cmd_init() {
    log_step "TP1 : Création du Datawarehouse"

    log_info "Création de la base LightAdventureWorksDW..."
    run_sql_file "$PROJECT_DIR/sql/01_create_database.sql"
    log_ok "Base de données créée."

    log_info "Création des dimensions..."
    run_sql_file "$PROJECT_DIR/sql/02_create_dimensions.sql" "LightAdventureWorksDW"
    log_ok "Dimensions créées."

    log_info "Création de la table de faits..."
    run_sql_file "$PROJECT_DIR/sql/03_create_fact_table.sql" "LightAdventureWorksDW"
    log_ok "Table de faits + FK créées."

    # Télécharger et restaurer AdventureWorks
    log_step "Restauration de AdventureWorks2022 (source OLTP)"
    local BAK="$PROJECT_DIR/backups/AdventureWorks2022.bak"
    if [ ! -f "$BAK" ]; then
        log_info "Téléchargement (~200MB)..."
        curl -L -o "$BAK" \
            "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak"
        log_ok "Téléchargement terminé."
    else
        log_info "AdventureWorks2022.bak déjà présent."
    fi

    log_info "Restauration de la base..."
    run_sql_file "$PROJECT_DIR/sql/04_restore_adventureworks.sql"
    log_ok "AdventureWorks2022 restaurée."

    log_info "Vérification du schéma..."
    run_sql_file "$PROJECT_DIR/sql/05_verify_schema.sql" "LightAdventureWorksDW"
    log_ok "TP1 TERMINÉ — Schéma en étoile créé ✓"
}

cmd_etl() {
    log_step "TP2 + TP3 : Exécution des ETL"

    log_info "ETL Dimensions (TP2)..."
    docker exec etl_runner python /app/etl/etl_dimensions.py
    log_ok "ETL Dimensions terminé."

    log_info "ETL Table de Faits (TP3)..."
    docker exec etl_runner python /app/etl/etl_fact_internetsales.py
    log_ok "ETL Faits terminé."

    log_info "Vérification finale..."
    run_sql_file "$PROJECT_DIR/sql/05_verify_schema.sql" "LightAdventureWorksDW"
    log_ok "TP2 + TP3 TERMINÉS ✓"
}

cmd_metabase() {
    log_step "Lancement de Metabase (Visualisation / Power BI)"
    cd "$PROJECT_DIR"
    $COMPOSE_CMD up -d metabase
    log_ok "Metabase lancé sur http://localhost:3000"
    echo ""
    echo "  Configuration dans Metabase :"
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │  Type     : SQL Server                     │"
    echo "  │  Host     : mssql_dw                       │"
    echo "  │  Port     : 1433                           │"
    echo "  │  Database : LightAdventureWorksDW          │"
    echo "  │  Username : SA                             │"
    echo "  │  Password : $SA_PASSWORD     │"
    echo "  └────────────────────────────────────────────┘"
}

cmd_sql() {
    log_info "Connexion sqlcmd interactive..."
    docker exec -it mssql_dw /opt/mssql-tools18/bin/sqlcmd \
        -S localhost -U SA -P "$SA_PASSWORD" -C
}

cmd_status() {
    log_step "Statut des conteneurs"
    cd "$PROJECT_DIR"
    $COMPOSE_CMD ps
    echo ""
    log_info "Vérification des données :"
    run_sql "
        SELECT 'Products' AS T, COUNT(*) AS N FROM dbo.Products UNION ALL
        SELECT 'Customers', COUNT(*) FROM dbo.Customers UNION ALL
        SELECT 'Dates', COUNT(*) FROM dbo.Dates UNION ALL
        SELECT 'InternetSales', COUNT(*) FROM dbo.InternetSales;
    " "LightAdventureWorksDW" 2>/dev/null || log_warn "Base pas encore initialisée."
}

cmd_stop() {
    log_step "Arrêt de tous les conteneurs"
    cd "$PROJECT_DIR"
    $COMPOSE_CMD down
    log_ok "Conteneurs arrêtés."
}

cmd_clean() {
    log_step "Nettoyage complet (conteneurs + volumes)"
    cd "$PROJECT_DIR"
    $COMPOSE_CMD down -v
    log_ok "Conteneurs et volumes supprimés."
}

cmd_all() {
    cmd_up
    cmd_init
    cmd_etl
    cmd_metabase
    echo ""
    log_step "TOUT EST PRÊT !"
    cat << 'BANNER'

  ╔═══════════════════════════════════════════════════════╗
  ║     TP DATAWAREHOUSE — TERMINÉ AVEC SUCCÈS !         ║
  ╠═══════════════════════════════════════════════════════╣
  ║                                                       ║
  ║  TP1 ✓ LightAdventureWorksDW (star schema)           ║
  ║  TP2 ✓ ETL Dimensions (Products, Customers, Dates)   ║
  ║  TP3 ✓ ETL Faits (InternetSales) + Metabase          ║
  ║                                                       ║
  ║  ► Metabase : http://localhost:3000                   ║
  ║  ► SQL      : ./setup.sh sql                          ║
  ║  ► Screenshots : ./screenshot.sh tp1_schema           ║
  ║                                                       ║
  ╚═══════════════════════════════════════════════════════╝

BANNER
}

# ============================================================================
# MAIN
# ============================================================================
print_usage() {
    cat << EOF
Usage: ./setup.sh [COMMANDE]

Commandes :
  (aucune)   Exécute tout (up + init + etl + metabase)
  up         Démarre SQL Server + ETL Runner
  init       Crée le DW (TP1) + restaure AdventureWorks
  etl        Exécute les ETL dimensions (TP2) + faits (TP3)
  metabase   Lance Metabase (visualisation)
  sql        Ouvre une console sqlcmd interactive
  status     Affiche l'état des conteneurs et des données
  stop       Arrête les conteneurs
  clean      Supprime conteneurs + volumes (reset complet)
  help       Affiche cette aide

Exemples :
  ./setup.sh           # Tout d'un coup
  ./setup.sh up        # Juste démarrer SQL Server
  ./setup.sh etl       # Relancer les ETL
  ./setup.sh sql       # Console SQL interactive
EOF
}

# Prérequis
if ! command -v docker &>/dev/null; then
    log_err "Docker n'est pas installé."
    echo "  → sudo pacman -S docker docker-compose"
    echo "  → sudo systemctl enable --now docker"
    echo "  → sudo usermod -aG docker \$USER  (puis re-login)"
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    log_err "Docker daemon n'est pas démarré."
    echo "  → sudo systemctl start docker"
    exit 1
fi

detect_compose

# Générer les fichiers si nécessaire
if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    generate_files
fi

# Dispatch
case "${1:-all}" in
    up)        cmd_up ;;
    init)      cmd_init ;;
    etl)       cmd_etl ;;
    metabase)  cmd_metabase ;;
    sql)       cmd_sql ;;
    status)    cmd_status ;;
    stop)      cmd_stop ;;
    clean)     cmd_clean ;;
    all)       cmd_all ;;
    help|-h)   print_usage ;;
    *)         log_err "Commande inconnue : $1"; print_usage; exit 1 ;;
esac
