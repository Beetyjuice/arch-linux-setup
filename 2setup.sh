#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config/rice-backups/$(date +%Y%m%d_%H%M%S)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Gruvbox color scheme
declare -A GRUVBOX=(
    [bg]="#282828"
    [bg_soft]="#32302f"
    [bg_hard]="#1d2021"
    [fg]="#ebdbb2"
    [fg_bright]="#fbf1c7"
    [red]="#cc241d"
    [red_light]="#fb4934"
    [green]="#98971a"
    [green_light]="#b8bb26"
    [yellow]="#d79921"
    [yellow_light]="#fabd2f"
    [blue]="#458588"
    [blue_light]="#83a598"
    [purple]="#b16286"
    [purple_light]="#d3869b"
    [aqua]="#689d6a"
    [aqua_light]="#8ec07c"
    [orange]="#d65d0e"
    [orange_light]="#fe8019"
    [gray]="#a89984"
    [gray_dark]="#928374"
)

# Logging
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
is_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Backup existing configurations
backup_configs() {
    log "Creating configuration backup..."
    mkdir -p "$BACKUP_DIR"

    for config in hypr waybar rofi kitty dunst; do
        if [ -d "$CONFIG_DIR/$config" ]; then
            cp -r "$CONFIG_DIR/$config" "$BACKUP_DIR/"
            log "Backed up $config configuration"
        fi
    done

    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$BACKUP_DIR"/* ~/.config/
hyprctl reload 2>/dev/null || echo "Hyprland not running"
echo "Configuration restored from backup"
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    log "Backup created at: $BACKUP_DIR"
}

# Install AUR helper (Paru - current best practice)
install_aur_helper() {
    if command_exists paru; then
        log "Paru already installed"
        return 0
    fi

    if command_exists yay; then
        log "Yay found - using existing AUR helper"
        return 0
    fi

    log "Installing Paru (AUR helper)..."

    # Install dependencies
    sudo pacman -S --needed base-devel git --noconfirm

    # Clone and install paru
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    rm -rf /tmp/paru

    log "Paru installed successfully"
}

# Install packages
install_packages() {
    log "Installing core Hyprland packages..."

    # Core Hyprland packages (official repos)
    local core_packages=(
        "hyprland"
        "xdg-desktop-portal-hyprland"
        "hyprpolkitagent"
        "hyprpaper"
        "hyprlock"
        "hypridle"
        "hyprpicker"
        "qt5-wayland"
        "qt6-wayland"
    )

    # Essential Wayland tools
    local wayland_tools=(
        "waybar"
        "rofi-wayland"
        "kitty"
        "dunst"
        "wl-clipboard"
        "grim"
        "slurp"
        "swappy"
        "brightnessctl"
        "pamixer"
        "pipewire"
        "wireplumber"
        "pipewire-audio"
        "pipewire-pulse"
        "playerctl"
        "pavucontrol"
    )

    # System tools
    local system_tools=(
        "thunar"
        "thunar-archive-plugin"
        "tumbler"
        "gvfs"
        "ffmpegthumbnailer"
        "polkit-gnome"
        "xdg-user-dirs"
        "networkmanager"
        "network-manager-applet"
    )

    # Fonts and theming
    local fonts_theme=(
        "noto-fonts"
        "noto-fonts-emoji"
        "ttf-liberation"
        "ttf-jetbrains-mono-nerd"
        "otf-font-awesome"
        "papirus-icon-theme"
        "qt6ct"
        "nwg-look"
    )

    # Install official packages
    for package in "${core_packages[@]}" "${wayland_tools[@]}" "${system_tools[@]}" "${fonts_theme[@]}"; do
        if ! is_installed "$package"; then
            log "Installing $package..."
            sudo pacman -S "$package" --noconfirm || warn "Failed to install $package"
        else
            log "$package already installed"
        fi
    done

    # AUR packages
    log "Installing AUR packages..."
    local aur_packages=(
        "swww"
        "grimblast-git"
        "hyprshot"
        "cliphist"
        "wl-clip-persist"
    )

    local aur_helper="paru"
    command_exists yay && aur_helper="yay"

    for package in "${aur_packages[@]}"; do
        if ! is_installed "$package"; then
            log "Installing $package from AUR..."
            $aur_helper -S "$package" --noconfirm || warn "Failed to install $package"
        else
            log "$package already installed"
        fi
    done
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."

    mkdir -p "$CONFIG_DIR"/{hypr,waybar,rofi,kitty,dunst}
    mkdir -p "$CONFIG_DIR/hypr"/{configs,scripts,themes}
    mkdir -p "$WALLPAPER_DIR"
    mkdir -p "$HOME/.local/share/rofi/themes"

    log "Directory structure created"
}

# Configure Hyprland
setup_hyprland() {
    log "Setting up Hyprland configuration..."

    # Main Hyprland configuration
    cat > "$CONFIG_DIR/hypr/hyprland.conf" << EOF
# Hyprland Configuration
# Source modular configs
source = ~/.config/hypr/configs/exec.conf
source = ~/.config/hypr/configs/env.conf
source = ~/.config/hypr/configs/general.conf
source = ~/.config/hypr/configs/decoration.conf
source = ~/.config/hypr/configs/animations.conf
source = ~/.config/hypr/configs/input.conf
source = ~/.config/hypr/configs/keybinds.conf
source = ~/.config/hypr/configs/monitors.conf
source = ~/.config/hypr/configs/window_rules.conf

# Gruvbox colors
\$gruvbox_bg = rgb(${GRUVBOX[bg]#*})
\$gruvbox_fg = rgb(${GRUVBOX[fg]#*})
\$gruvbox_red = rgb(${GRUVBOX[red]#*})
\$gruvbox_green = rgb(${GRUVBOX[green]#*})
\$gruvbox_yellow = rgb(${GRUVBOX[yellow]#*})
\$gruvbox_blue = rgb(${GRUVBOX[blue]#*})
\$gruvbox_purple = rgb(${GRUVBOX[purple]#*})
\$gruvbox_aqua = rgb(${GRUVBOX[aqua]#*})
\$gruvbox_orange = rgb(${GRUVBOX[orange]#*})
EOF

    # Environment variables
    cat > "$CONFIG_DIR/hypr/configs/env.conf" << EOF
# Environment variables
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# Qt/GTK theming
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland

# Cursor and scaling
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

# Electron apps
env = ELECTRON_OZONE_PLATFORM_HINT,wayland

# NVIDIA (uncomment if using NVIDIA GPU)
# env = LIBVA_DRIVER_NAME,nvidia
# env = GBM_BACKEND,nvidia-drm
# env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# env = NVD_BACKEND,direct
EOF

    # Startup applications
    cat > "$CONFIG_DIR/hypr/configs/exec.conf" << EOF
# Startup applications
exec-once = hypridle
exec-once = hyprpolkitagent
exec-once = waybar
exec-once = dunst
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = wl-clip-persist --clipboard regular
exec-once = swww init
exec-once = nm-applet
exec-once = thunar --daemon

# Set wallpaper
exec-once = swww img $WALLPAPER_DIR/gruvbox-wallpaper.jpg
EOF

    # General settings
    cat > "$CONFIG_DIR/hypr/configs/general.conf" << EOF
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = \$gruvbox_yellow \$gruvbox_orange 45deg
    col.inactive_border = \$gruvbox_bg
    layout = dwindle
    allow_tearing = false
}

dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    vfr = true
}
EOF

    # Decorations
    cat > "$CONFIG_DIR/hypr/configs/decoration.conf" << EOF
decoration {
    rounding = 8
    active_opacity = 1.0
    inactive_opacity = 0.95

    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
        xray = true
        noise = 0.0117
        contrast = 1.0
        brightness = 1.0
    }

    drop_shadow = true
    shadow_range = 10
    shadow_render_power = 3
    col.shadow = \$gruvbox_bg
    col.shadow_inactive = 0x50000000
}
EOF

    # Animations
    cat > "$CONFIG_DIR/hypr/configs/animations.conf" << EOF
animations {
    enabled = true

    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    bezier = easeOut, 0.25, 0.46, 0.45, 0.94

    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = windowsMove, 1, 6, default
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default, slide
    animation = specialWorkspace, 1, 6, default, slidevert
}
EOF

    # Input configuration
    cat > "$CONFIG_DIR/hypr/configs/input.conf" << EOF
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1

    sensitivity = 0

    touchpad {
        natural_scroll = false
    }
}
EOF

    # Key bindings
    cat > "$CONFIG_DIR/hypr/configs/keybinds.conf" << EOF
# Variables
\$mainMod = SUPER
\$terminal = kitty
\$fileManager = thunar
\$menu = rofi -show drun

# Basic window management
bind = \$mainMod, Q, killactive
bind = \$mainMod, M, exit
bind = \$mainMod, V, togglefloating
bind = \$mainMod, P, pseudo
bind = \$mainMod, J, togglesplit
bind = \$mainMod, F, fullscreen, 1

# Application launching
bind = \$mainMod, RETURN, exec, \$terminal
bind = \$mainMod, E, exec, \$fileManager
bind = \$mainMod, D, exec, \$menu
bind = \$mainMod, C, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy

# Focus movement
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Window movement
bind = \$mainMod SHIFT, left, movewindow, l
bind = \$mainMod SHIFT, right, movewindow, r
bind = \$mainMod SHIFT, up, movewindow, u
bind = \$mainMod SHIFT, down, movewindow, d

# Workspace navigation
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

# Move windows to workspaces
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Special workspace
bind = \$mainMod SHIFT, U, movetoworkspace, special
bind = \$mainMod, U, togglespecialworkspace

# Screenshots
bind = , PRINT, exec, grimblast copysave area
bind = \$mainMod, PRINT, exec, grimblast copysave output
bind = \$mainMod SHIFT, PRINT, exec, grimblast copysave active

# Media controls
binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
binde = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous

# Brightness controls
binde = , XF86MonBrightnessUp, exec, brightnessctl s +5%
binde = , XF86MonBrightnessDown, exec, brightnessctl s 5%-

# Window resizing
bind = \$mainMod, R, submap, resize
submap = resize
binde = , right, resizeactive, 10 0
binde = , left, resizeactive, -10 0
binde = , up, resizeactive, 0 -10
binde = , down, resizeactive, 0 10
bind = , escape, submap, reset
submap = reset

# Mouse bindings
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow
EOF

    # Monitor configuration
    cat > "$CONFIG_DIR/hypr/configs/monitors.conf" << EOF
# Monitor configuration
# See https://wiki.hyprland.org/Configuring/Monitors/
monitor = ,preferred,auto,auto

# Example multi-monitor setup:
# monitor = DP-1,1920x1080@60,0x0,1
# monitor = HDMI-1,1920x1080@60,1920x0,1
EOF

    # Window rules
    cat > "$CONFIG_DIR/hypr/configs/window_rules.conf" << EOF
# Window rules
# Floating windows
windowrule = float, ^(pavucontrol)\$
windowrule = float, ^(blueman-manager)\$
windowrule = float, ^(nm-connection-editor)\$
windowrule = float, ^(file_progress)\$
windowrule = float, ^(confirm)\$
windowrule = float, ^(dialog)\$
windowrule = float, ^(download)\$
windowrule = float, ^(notification)\$
windowrule = float, ^(error)\$
windowrule = float, ^(splash)\$
windowrule = float, ^(confirmreset)\$

# Center floating windows
windowrule = center, ^(pavucontrol|blueman-manager|nm-connection-editor)\$

# Workspace assignments
windowrule = workspace 2, ^(firefox|chromium|brave)\$
windowrule = workspace 3, ^(code|codium)\$
windowrule = workspace 4, ^(thunar|dolphin|nautilus)\$

# Opacity rules
windowrule = opacity 0.9 override 0.9 override, ^(kitty)\$
windowrule = opacity 0.95 override 0.95 override, ^(thunar)\$

# Privacy and security
windowrule = noscreenshare, ^(keepassxc|bitwarden)\$
windowrule = stayfocused, ^(pinentry-)

# No blur for some windows
windowrule = noblur, ^(firefox)\$
windowrule = noblur, ^(chromium)\$
EOF

    log "Hyprland configuration created"
}

# Configure Waybar
setup_waybar() {
    log "Setting up Waybar configuration..."

    # Waybar config
    cat > "$CONFIG_DIR/waybar/config.jsonc" << EOF
{
    "layer": "top",
    "position": "top",
    "height": 34,
    "spacing": 4,
    "reload_style_on_change": true,

    "modules-left": ["hyprland/workspaces", "mpris"],
    "modules-center": ["hyprland/window"],
    "modules-right": ["tray", "network", "wireplumber", "memory", "cpu", "temperature", "battery", "clock"],

    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "",
            "2": "",
            "3": "",
            "4": "",
            "5": "",
            "urgent": "",
            "focused": "",
            "default": ""
        }
    },

    "hyprland/window": {
        "format": "{class}",
        "max-length": 50,
        "rewrite": {
            "(.*) — Mozilla Firefox": "🌎 Firefox",
            "(.*)Mozilla Firefox": "🌎 Firefox",
            "(.*) - Visual Studio Code": "📝 Code",
            "(.*)Visual Studio Code": "📝 Code"
        }
    },

    "tray": {
        "spacing": 10
    },

    "clock": {
        "timezone": "America/New_York",
        "tooltip-format": "<big>{:%Y %B}</big>\\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}"
    },

    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },

    "memory": {
        "format": " {}%"
    },

    "temperature": {
        "critical-threshold": 80,
        "format": "{temperatureC}°C {icon}",
        "format-icons": ["", "", ""]
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-alt": "{time} {icon}",
        "format-icons": ["", "", "", "", ""]
    },

    "network": {
        "format-wifi": " {essid} ({signalStrength}%)",
        "format-ethernet": " {ipaddr}/{cidr}",
        "tooltip-format": " {ifname} via {gwaddr}",
        "format-linked": " {ifname} (No IP)",
        "format-disconnected": "⚠ Disconnected",
        "format-alt": "{ifname}: {ipaddr}/{cidr}",
        "on-click": "nm-connection-editor"
    },

    "wireplumber": {
        "format": " {volume}%",
        "format-muted": " muted",
        "on-click": "pavucontrol",
        "on-scroll-up": "pamixer -i 5",
        "on-scroll-down": "pamixer -d 5"
    },

    "mpris": {
        "format": "{player_icon} {dynamic}",
        "format-paused": "{status_icon} <i>{dynamic}</i>",
        "player-icons": {
            "default": "🎵",
            "mpv": "🎵"
        },
        "status-icons": {
            "paused": "⏸"
        }
    }
}
EOF

    # Waybar stylesheet with Gruvbox theme
    cat > "$CONFIG_DIR/waybar/style.css" << EOF
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono Nerd Font";
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background-color: ${GRUVBOX[bg]};
    border-bottom: 3px solid ${GRUVBOX[bg]};
    color: ${GRUVBOX[fg]};
    transition-property: background-color;
    transition-duration: .5s;
}

#workspaces button {
    padding: 0 8px;
    background-color: transparent;
    color: ${GRUVBOX[fg]};
    border-bottom: 3px solid transparent;
    transition: all 0.3s ease;
}

#workspaces button:hover {
    background-color: ${GRUVBOX[gray_dark]};
    border-bottom: 3px solid ${GRUVBOX[gray_dark]};
}

#workspaces button.active {
    background-color: ${GRUVBOX[yellow]};
    color: ${GRUVBOX[bg]};
    border-bottom: 3px solid ${GRUVBOX[yellow]};
}

#workspaces button.urgent {
    background-color: ${GRUVBOX[red_light]};
    color: ${GRUVBOX[bg]};
    border-bottom: 3px solid ${GRUVBOX[red_light]};
}

#window,
#clock,
#battery,
#cpu,
#memory,
#temperature,
#network,
#wireplumber,
#tray,
#mpris {
    padding: 0 10px;
    color: ${GRUVBOX[fg]};
    background-color: ${GRUVBOX[bg_soft]};
    margin: 3px 2px;
    border-radius: 6px;
}

#battery.charging, #battery.plugged {
    color: ${GRUVBOX[green_light]};
}

#battery.critical:not(.charging) {
    background-color: ${GRUVBOX[red]};
    color: ${GRUVBOX[fg_bright]};
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#network.disconnected {
    color: ${GRUVBOX[red_light]};
}

#wireplumber.muted {
    color: ${GRUVBOX[red_light]};
}

#temperature.critical {
    background-color: ${GRUVBOX[red]};
    color: ${GRUVBOX[fg_bright]};
}

@keyframes blink {
    to {
        background-color: ${GRUVBOX[fg_bright]};
        color: ${GRUVBOX[bg]};
    }
}

#tray > .passive {
    -gtk-icon-effect: dim;
}

#tray > .needs-attention {
    -gtk-icon-effect: highlight;
}
EOF

    log "Waybar configuration created"
}

# Configure Rofi
setup_rofi() {
    log "Setting up Rofi configuration..."

    # Rofi config
    cat > "$CONFIG_DIR/rofi/config.rasi" << EOF
configuration {
    modes: [ combi ];
    combi-modes: [ window, drun, run ];
    display-ssh: "";
    display-run: "";
    display-drun: "";
    display-window: "";
    display-combi: "󰕘";
    show-icons: true;
    icon-theme: "Papirus";
    font: "JetBrains Mono Nerd Font 12";
    location: 0;
    yoffset: 0;
    xoffset: 0;
    fixed-num-lines: true;
    disable-history: false;
    cycle: true;
}

@theme "gruvbox-dark"
EOF

    # Custom Gruvbox theme for Rofi
    cat > "$CONFIG_DIR/rofi/gruvbox-dark.rasi" << EOF
* {
    gruvbox-dark-bg0:          ${GRUVBOX[bg]};
    gruvbox-dark-bg0-soft:     ${GRUVBOX[bg_soft]};
    gruvbox-dark-fg0:          ${GRUVBOX[fg_bright]};
    gruvbox-dark-fg1:          ${GRUVBOX[fg]};
    gruvbox-dark-red-dark:     ${GRUVBOX[red]};
    gruvbox-dark-red-light:    ${GRUVBOX[red_light]};
    gruvbox-dark-yellow-dark:  ${GRUVBOX[yellow]};
    gruvbox-dark-yellow-light: ${GRUVBOX[yellow_light]};
    gruvbox-dark-gray:         ${GRUVBOX[gray]};

    background:                @gruvbox-dark-bg0;
    background-color:          @background;
    foreground:                @gruvbox-dark-fg1;
    border-color:              @gruvbox-dark-gray;
    separatorcolor:            @border-color;
    scrollbar-handle:          @border-color;

    normal-background:         @background;
    normal-foreground:         @foreground;
    alternate-normal-background: @gruvbox-dark-bg0-soft;
    alternate-normal-foreground: @foreground;
    selected-normal-background: @gruvbox-dark-yellow-dark;
    selected-normal-foreground: @gruvbox-dark-bg0;

    active-background:         @gruvbox-dark-yellow-dark;
    active-foreground:         @background;
    alternate-active-background: @active-background;
    alternate-active-foreground: @active-foreground;
    selected-active-background: @gruvbox-dark-yellow-light;
    selected-active-foreground: @active-foreground;

    urgent-background:         @gruvbox-dark-red-dark;
    urgent-foreground:         @background;
    alternate-urgent-background: @urgent-background;
    alternate-urgent-foreground: @urgent-foreground;
    selected-urgent-background: @gruvbox-dark-red-light;
    selected-urgent-foreground: @urgent-foreground;
}

element {
    padding: 1px;
    cursor:  pointer;
    spacing: 5px;
    border:  0;
}

element normal.normal {
    background-color: @normal-background;
    text-color:       @normal-foreground;
}

element normal.urgent {
    background-color: @urgent-background;
    text-color:       @urgent-foreground;
}

element normal.active {
    background-color: @active-background;
    text-color:       @active-foreground;
}

element selected.normal {
    background-color: @selected-normal-background;
    text-color:       @selected-normal-foreground;
}

element selected.urgent {
    background-color: @selected-urgent-background;
    text-color:       @selected-urgent-foreground;
}

element selected.active {
    background-color: @selected-active-background;
    text-color:       @selected-active-foreground;
}

element alternate.normal {
    background-color: @alternate-normal-background;
    text-color:       @alternate-normal-foreground;
}

element alternate.urgent {
    background-color: @alternate-urgent-background;
    text-color:       @alternate-urgent-foreground;
}

element alternate.active {
    background-color: @alternate-active-background;
    text-color:       @alternate-active-foreground;
}

element-text {
    background-color: rgba(0,0,0,0%);
    text-color:       inherit;
    highlight:        inherit;
    cursor:           inherit;
}

element-icon {
    background-color: rgba(0,0,0,0%);
    size:             1.0000em;
    text-color:       inherit;
    cursor:           inherit;
}

window {
    padding:          5;
    background-color: @background;
    border:           1;
    border-radius:    8;
    border-color:     @border-color;
}

mainbox {
    padding: 0;
    border:  0;
}

message {
    padding:      1px;
    border-color: @separatorcolor;
    border:       2px dash 0px 0px;
}

textbox {
    text-color: @foreground;
}

listview {
    padding:      2px 0px 0px;
    scrollbar:    true;
    border-color: @separatorcolor;
    spacing:      2px;
    fixed-height: 0;
    border:       2px dash 0px 0px;
}

scrollbar {
    width:        4px;
    padding:      0;
    handle-width: 8px;
    border:       0;
    handle-color: @normal-foreground;
}

sidebar {
    border-color: @separatorcolor;
    border:       2px dash 0px 0px;
}

button {
    cursor:     pointer;
    spacing:    0;
    text-color: @normal-foreground;
}

button selected {
    background-color: @selected-normal-background;
    text-color:       @selected-normal-foreground;
}

inputbar {
    padding:    1px;
    spacing:    0px;
    text-color: @normal-foreground;
    children:   [ prompt,textbox-prompt-colon,entry,case-indicator ];
}

case-indicator {
    spacing:    0;
    text-color: @normal-foreground;
}

entry {
    text-color:        @normal-foreground;
    cursor:            text;
    spacing:           0;
    placeholder-color: @gruvbox-dark-gray;
}

prompt {
    spacing:    0;
    text-color: @normal-foreground;
}

textbox-prompt-colon {
    margin:     0px 0.3000em 0.0000em 0.0000em;
    expand:     false;
    str:        ":";
    text-color: inherit;
}
EOF

    log "Rofi configuration created"
}

# Configure Kitty terminal
setup_kitty() {
    log "Setting up Kitty configuration..."

    cat > "$CONFIG_DIR/kitty/kitty.conf" << EOF
# Gruvbox Dark theme for Kitty
include current-theme.conf

# Font configuration
font_family      JetBrains Mono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12

# Cursor configuration
cursor_shape block
cursor_blink_interval 1

# Scrollback
scrollback_lines 2000

# Mouse
copy_on_select yes
click_interval -1.0

# Terminal bell
enable_audio_bell no

# Window layout
remember_window_size  yes
initial_window_width  640
initial_window_height 400
window_padding_width 4

# Tab bar
tab_bar_style fade
tab_fade 0.25 0.5 0.75 1

# Advanced
shell_integration enabled
allow_remote_control yes
listen_on unix:/tmp/kitty
EOF

    # Kitty current theme (Gruvbox Dark)
    cat > "$CONFIG_DIR/kitty/current-theme.conf" << EOF
# Gruvbox Dark theme for Kitty
background            ${GRUVBOX[bg]}
foreground            ${GRUVBOX[fg]}
selection_background  ${GRUVBOX[fg]}
selection_foreground  ${GRUVBOX[bg]}
url_color             ${GRUVBOX[yellow]}
cursor                ${GRUVBOX[fg]}

# Black
color0   ${GRUVBOX[bg]}
color8   ${GRUVBOX[gray_dark]}

# Red
color1   ${GRUVBOX[red]}
color9   ${GRUVBOX[red_light]}

# Green
color2   ${GRUVBOX[green]}
color10  ${GRUVBOX[green_light]}

# Yellow
color3   ${GRUVBOX[yellow]}
color11  ${GRUVBOX[yellow_light]}

# Blue
color4   ${GRUVBOX[blue]}
color12  ${GRUVBOX[blue_light]}

# Magenta
color5   ${GRUVBOX[purple]}
color13  ${GRUVBOX[purple_light]}

# Cyan
color6   ${GRUVBOX[aqua]}
color14  ${GRUVBOX[aqua_light]}

# White
color7   ${GRUVBOX[gray]}
color15  ${GRUVBOX[fg_bright]}

# Tab bar colors
active_tab_background   ${GRUVBOX[yellow]}
active_tab_foreground   ${GRUVBOX[bg]}
inactive_tab_background ${GRUVBOX[bg_soft]}
inactive_tab_foreground ${GRUVBOX[gray]}
EOF

    log "Kitty configuration created"
}

# Configure Dunst (notification daemon)
setup_dunst() {
    log "Setting up Dunst configuration..."

    cat > "$CONFIG_DIR/dunst/dunstrc" << EOF
[global]
    font = "JetBrains Mono Nerd Font 10"
    allow_markup = yes
    format = "<b>%s</b>\\n%b"
    sort = yes
    indicate_hidden = yes
    alignment = left
    bounce_freq = 0
    show_age_threshold = 60
    word_wrap = yes
    ignore_newline = no
    stack_duplicates = true
    hide_duplicates_count = false
    geometry = "300x5-30+20"
    shrink = no
    transparency = 10
    idle_threshold = 120
    monitor = 0
    follow = mouse
    sticky_history = yes
    history_length = 20
    show_indicators = yes
    line_height = 0
    separator_height = 2
    padding = 8
    horizontal_padding = 8
    separator_color = frame
    startup_notification = false
    dmenu = rofi -dmenu -p dunst:
    browser = /usr/bin/firefox
    icon_position = left
    max_icon_size = 32
    icon_path = /usr/share/icons/Papirus/16x16/status/:/usr/share/icons/Papirus/16x16/devices/
    frame_width = 2
    frame_color = "${GRUVBOX[blue_light]}"

[shortcuts]
    close = ctrl+space
    close_all = ctrl+shift+space
    history = ctrl+grave
    context = ctrl+shift+period

[urgency_low]
    background = "${GRUVBOX[bg]}"
    foreground = "${GRUVBOX[fg]}"
    timeout = 5
    icon = /usr/share/icons/Papirus/16x16/status/dialog-information.svg

[urgency_normal]
    background = "${GRUVBOX[bg]}"
    foreground = "${GRUVBOX[fg]}"
    timeout = 10
    icon = /usr/share/icons/Papirus/16x16/status/dialog-information.svg

[urgency_critical]
    background = "${GRUVBOX[red]}"
    foreground = "${GRUVBOX[fg_bright]}"
    frame_color = "${GRUVBOX[red_light]}"
    timeout = 0
    icon = /usr/share/icons/Papirus/16x16/status/dialog-error.svg
EOF

    log "Dunst configuration created"
}

# Configure hypridle
setup_hypridle() {
    log "Setting up Hypridle configuration..."

    cat > "$CONFIG_DIR/hypr/hypridle.conf" << EOF
general {
    lock_cmd = pidof hyprlock || hyprlock       # avoid starting multiple hyprlock instances
    before_sleep_cmd = loginctl lock-session    # lock before suspend
    after_sleep_cmd = hyprctl dispatch dpms on  # to avoid having to press a key twice to turn on the display
}

listener {
    timeout = 150                               # 2.5min
    on-timeout = brightnessctl -s set 10        # set monitor backlight to minimum, avoid 0 on OLED monitor
    on-resume = brightnessctl -r                # monitor backlight restore
}

listener {
    timeout = 300                               # 5min
    on-timeout = loginctl lock-session          # lock screen when timeout has passed
}

listener {
    timeout = 330                               # 5.5min
    on-timeout = hyprctl dispatch dpms off      # screen off when timeout has passed
    on-resume = hyprctl dispatch dpms on        # screen on when activity is detected after timeout has fired
}

listener {
    timeout = 1800                              # 30min
    on-timeout = systemctl suspend              # suspend pc
}
EOF

    log "Hypridle configuration created"
}

# Configure hyprlock
setup_hyprlock() {
    log "Setting up Hyprlock configuration..."

    cat > "$CONFIG_DIR/hypr/hyprlock.conf" << EOF
general {
    disable_loading_bar = true
    grace = 300
    hide_cursor = true
    no_fade_in = false
}

background {
    monitor =
    path = $WALLPAPER_DIR/gruvbox-wallpaper.jpg
    blur_passes = 3
    blur_size = 8
}

input-field {
    monitor =
    size = 200, 50
    outline_thickness = 3
    dots_size = 0.33
    dots_spacing = 0.15
    dots_center = false
    dots_rounding = -1
    outer_color = ${GRUVBOX[blue]}
    inner_color = ${GRUVBOX[bg]}
    font_color = ${GRUVBOX[fg]}
    fade_on_empty = true
    fade_timeout = 1000
    placeholder_text = <i>Input Password...</i>
    hide_input = false
    rounding = -1
    check_color = ${GRUVBOX[orange]}
    fail_color = ${GRUVBOX[red]}
    fail_text = <i>\$FAIL <b>(\$ATTEMPTS)</b></i>
    fail_timeout = 2000
    fail_transitions = 300
    capslock_color = -1
    numlock_color = -1
    bothlock_color = -1
    invert_numlock = false
    swap_font_color = false

    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor =
    text = Welcome back, \$USER
    color = ${GRUVBOX[fg]}
    font_size = 25
    font_family = JetBrains Mono Nerd Font

    position = 0, 80
    halign = center
    valign = center
}

label {
    monitor =
    text = \$TIME
    color = ${GRUVBOX[yellow]}
    font_size = 55
    font_family = JetBrains Mono Nerd Font

    position = 0, 150
    halign = center
    valign = center
}
EOF

    log "Hyprlock configuration created"
}

# Download a gruvbox wallpaper
download_wallpaper() {
    log "Setting up default wallpaper..."

    if [ ! -f "$WALLPAPER_DIR/gruvbox-wallpaper.jpg" ]; then
        # Create a simple colored wallpaper if no internet
        if command_exists convert; then
            convert -size 1920x1080 "xc:${GRUVBOX[bg]}" "$WALLPAPER_DIR/gruvbox-wallpaper.jpg"
        else
            # Copy any existing wallpaper or create a placeholder
            touch "$WALLPAPER_DIR/gruvbox-wallpaper.jpg"
        fi
        log "Default wallpaper created"
    else
        log "Wallpaper already exists"
    fi
}

# Enable systemd services
enable_services() {
    log "Enabling systemd services..."

    # Enable NetworkManager
    sudo systemctl enable NetworkManager.service

    # User services
    systemctl --user enable wireplumber.service
    systemctl --user enable pipewire.service
    systemctl --user enable pipewire-pulse.service

    log "Services enabled"
}

# Validation function
validate_installation() {
    log "Validating installation..."

    local required_commands=(
        "hyprland"
        "waybar"
        "rofi"
        "kitty"
        "dunst"
        "grimblast"
        "cliphist"
        "swww"
    )

    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -eq 0 ]; then
        log "✓ All required commands are available"
    else
        warn "Missing commands: ${missing_commands[*]}"
        warn "Some components may not work correctly"
    fi

    # Check configuration files
    local config_files=(
        "$CONFIG_DIR/hypr/hyprland.conf"
        "$CONFIG_DIR/waybar/config.jsonc"
        "$CONFIG_DIR/rofi/config.rasi"
        "$CONFIG_DIR/kitty/kitty.conf"
        "$CONFIG_DIR/dunst/dunstrc"
    )

    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            log "✓ Configuration exists: $(basename "$config")"
        else
            warn "✗ Configuration missing: $(basename "$config")"
        fi
    done
}

# Create desktop entry for Hyprland
create_desktop_entry() {
    log "Creating desktop entry..."

    sudo tee /usr/share/wayland-sessions/hyprland-rice.desktop >/dev/null << EOF
[Desktop Entry]
Name=Hyprland (Rice Setup)
Comment=Dynamic tiling Wayland compositor - Rice Configuration
Exec=Hyprland
Type=Application
EOF

    log "Desktop entry created"
}

# Main installation function
main() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Hyprland Rice Setup Script - 2024/2025            ║${NC}"
    echo -e "${BLUE}║                    Gruvbox Color Scheme                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Do not run this script as root"
    fi

    # Confirmation
    echo -e "${YELLOW}This script will install and configure Hyprland with a complete rice setup.${NC}"
    echo -e "${YELLOW}Existing configurations will be backed up to: $BACKUP_DIR${NC}"
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi

    log "Starting Hyprland rice installation..."

    # Installation steps
    backup_configs
    install_aur_helper
    install_packages
    create_directories
    setup_hyprland
    setup_waybar
    setup_rofi
    setup_kitty
    setup_dunst
    setup_hypridle
    setup_hyprlock
    download_wallpaper
    enable_services
    create_desktop_entry
    validate_installation

    echo
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Installation Complete!                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✓ Hyprland rice setup completed successfully${NC}"
    echo -e "${BLUE}→ Configuration backup: $BACKUP_DIR${NC}"
    echo -e "${BLUE}→ To restore backup: bash $BACKUP_DIR/restore.sh${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. ${BLUE}Log out and select 'Hyprland (Rice Setup)' from your display manager${NC}"
    echo -e "2. ${BLUE}Customize wallpaper: Add images to $WALLPAPER_DIR${NC}"
    echo -e "3. ${BLUE}Configure themes: Run 'qt6ct' and 'nwg-look'${NC}"
    echo -e "4. ${BLUE}Check monitor configuration: Edit ~/.config/hypr/configs/monitors.conf${NC}"
    echo
    echo -e "${GREEN}Key bindings:${NC}"
    echo -e "  ${BLUE}Super + Return${NC}     → Open terminal (Kitty)"
    echo -e "  ${BLUE}Super + D${NC}          → Application launcher (Rofi)"
    echo -e "  ${BLUE}Super + E${NC}          → File manager (Thunar)"
    echo -e "  ${BLUE}Super + C${NC}          → Clipboard history"
    echo -e "  ${BLUE}Print Screen${NC}       → Screenshot area"
    echo -e "  ${BLUE}Super + Q${NC}          → Close window"
    echo -e "  ${BLUE}Super + 1-10${NC}       → Switch workspace"
    echo
    echo -e "${YELLOW}Enjoy your new Hyprland rice setup! 🌾${NC}"
}

# Error handling
set -E
trap 'error "Installation failed at line $LINENO"' ERR

# Run main function
main "$@"
