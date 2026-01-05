#!/bin/bash

# arch-ssh-setup.sh
# Setup script for SSH access on fresh Arch Linux installation
# Run this AFTER base installation and BEFORE first reboot

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Check if we're in chroot environment
if [ ! -f /etc/arch-release ]; then
    print_error "This script must be run inside the Arch chroot environment"
    exit 1
fi

print_status "Starting SSH setup for Arch Linux..."

# 1. Install OpenSSH
print_status "Installing OpenSSH..."
pacman -Sy --noconfirm openssh

# 2. Enable SSH daemon
print_status "Enabling SSH daemon..."
systemctl enable sshd

# 3. Configure SSH (basic security settings)
print_status "Configuring SSH..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup original config
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

# Basic security settings
cat >> "$SSH_CONFIG" << EOF

# Custom settings added by arch-ssh-setup.sh
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# 4. Set root password (required for SSH login)
print_warning "Setting root password for SSH access"
passwd root

# 5. Create a regular user (optional but recommended)
while true; do
    read -p "Create a regular user? (y/n): " create_user
    case $create_user in
        [Yy]* )
            read -p "Enter username: " username
            useradd -m -G wheel -s /bin/bash "$username"
            passwd "$username"
            print_status "User '$username' created with sudo access"
            break
            ;;
        [Nn]* ) break;;
        * ) echo "Please answer y or n";;
    esac
done

# 6. Configure sudo for wheel group (if user created)
if id -u "$username" >/dev/null 2>&1; then
    if [ -f /etc/sudoers ]; then
        # Uncomment wheel group sudo access
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        print_status "Sudo access enabled for wheel group"
    fi
fi

# 7. Start SSH service (for immediate access if needed before reboot)
print_status "Starting SSH service..."
systemctl start sshd

# 8. Show network information
print_status "Network information:"
ip -4 addr show | grep -v "127.0.0.1" | grep "inet" | awk '{print $2}' | cut -d'/' -f1

# 9. Final instructions
print_status "SSH setup complete!"
echo
echo "Next steps:"
echo "1. Exit chroot and reboot your system"
echo "2. Connect via SSH using: ssh root@<your-ip-address>"
echo "3. For added security, consider:"
echo "   - Disabling root login after creating regular user"
echo "   - Setting up key-based authentication"
echo "   - Configuring a firewall (ufw/iptables)"
echo
print_warning "Remember to change default passwords and secure your system!"

exit 0
