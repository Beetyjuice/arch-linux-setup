#!/bin/bash

# Arch Linux User-Friendly Setup Script
# This script sets up a fresh Arch Linux installation for daily usage
# Author: Generated for Arch Linux setup
# Version: 1.0

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root"
   exit 1
fi

# Check if running on Arch Linux
if ! command -v pacman &> /dev/null; then
    error "This script is designed for Arch Linux (pacman not found)"
    exit 1
fi

log "🚀 Starting Arch Linux User-Friendly Setup"

# ============================================================================
# STEP 1: Update System
# ============================================================================
log "📦 Step 1: Updating system packages"
sudo pacman -Syu --noconfirm

# ============================================================================
# STEP 2: Install Essential Base Packages
# ============================================================================
log "🔧 Step 2: Installing essential base packages"

# Essential system packages
ESSENTIAL_PACKAGES=(
    "base-devel"
    "git"
    "wget"
    "curl"
    "unzip"
    "zip"
    "p7zip"
    "htop"
    "neofetch"
    "tree"
    "nano"
    "vim"
)

sudo pacman -S --needed --noconfirm "${ESSENTIAL_PACKAGES[@]}"

# ============================================================================
# STEP 3: Graphics and Display Server
# ============================================================================
log "🖥️  Step 3: Setting up graphics and display server"

# Detect GPU
if lspci | grep -E "NVIDIA|GeForce" > /dev/null; then
    GPU_TYPE="nvidia"
    info "NVIDIA GPU detected"
elif lspci | grep -E "AMD|Radeon" > /dev/null; then
    GPU_TYPE="amd"
    info "AMD GPU detected"
else
    GPU_TYPE="intel"
    info "Intel/Generic GPU detected"
fi

# Install Xorg
sudo pacman -S --needed --noconfirm xorg-server xorg-xinit xorg-xrandr

# Install graphics drivers
case $GPU_TYPE in
    "nvidia")
        sudo pacman -S --needed --noconfirm nvidia nvidia-utils
        ;;
    "amd")
        sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa
        ;;
    *)
        sudo pacman -S --needed --noconfirm xf86-video-intel mesa
        ;;
esac

# ============================================================================
# STEP 4: Desktop Environment Selection
# ============================================================================
log "🏠 Step 4: Desktop Environment Setup"

echo "Select your preferred Desktop Environment:"
echo "1) GNOME (Beginner-friendly, modern)"
echo "2) KDE Plasma (Feature-rich, customizable)"
echo "3) XFCE (Lightweight, traditional)"
echo "4) i3 (Tiling window manager, advanced)"
echo "5) Skip (I'll install manually later)"

read -p "Enter your choice [1-5]: " DE_CHOICE

case $DE_CHOICE in
    1)
        log "Installing GNOME Desktop Environment"
        sudo pacman -S --needed --noconfirm gnome gnome-extra gdm
        sudo systemctl enable gdm
        DESKTOP_ENV="gnome"
        ;;
    2)
        log "Installing KDE Plasma Desktop Environment"
        sudo pacman -S --needed --noconfirm plasma kde-applications sddm
        sudo systemctl enable sddm
        DESKTOP_ENV="kde"
        ;;
    3)
        log "Installing XFCE Desktop Environment"
        sudo pacman -S --needed --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        sudo systemctl enable lightdm
        DESKTOP_ENV="xfce"
        ;;
    4)
        log "Installing i3 Window Manager"
        sudo pacman -S --needed --noconfirm i3-wm i3status i3lock dmenu feh
        DESKTOP_ENV="i3"
        info "i3 requires manual configuration. Check ~/.config/i3/config after reboot"
        ;;
    5)
        warning "Skipping desktop environment installation"
        DESKTOP_ENV="none"
        ;;
    *)
        warning "Invalid choice. Defaulting to GNOME"
        sudo pacman -S --needed --noconfirm gnome gnome-extra gdm
        sudo systemctl enable gdm
        DESKTOP_ENV="gnome"
        ;;
esac

# ============================================================================
# STEP 5: Audio System
# ============================================================================
log "🔊 Step 5: Setting up audio system"

# Install PipeWire (modern audio system)
sudo pacman -S --needed --noconfirm pipewire pipewire-pulse pipewire-jack wireplumber alsa-utils

# Enable PipeWire services for user
systemctl --user enable --now pipewire pipewire-pulse wireplumber

# ============================================================================
# STEP 6: Network Management
# ============================================================================
log "🌐 Step 6: Setting up network management"

sudo pacman -S --needed --noconfirm networkmanager network-manager-applet
sudo systemctl enable NetworkManager

# ============================================================================
# STEP 7: Essential Applications
# ============================================================================
log "📱 Step 7: Installing essential applications"

ESSENTIAL_APPS=(
    "firefox"
    "thunderbird"
    "libreoffice-fresh"
    "gimp"
    "vlc"
    "code"  # VS Code
    "discord"
    "steam"
    "obs-studio"
)

# Ask user which applications to install
echo "Select essential applications to install:"
for i in "${!ESSENTIAL_APPS[@]}"; do
    echo "$((i+1))) ${ESSENTIAL_APPS[i]}"
done
echo "$((${#ESSENTIAL_APPS[@]}+1))) Install all"
echo "$((${#ESSENTIAL_APPS[@]}+2))) Skip application installation"

read -p "Enter your choices (comma-separated numbers, e.g., 1,3,5): " APP_CHOICES

if [[ $APP_CHOICES == "$((${#ESSENTIAL_APPS[@]}+1))" ]]; then
    # Install all applications
    for app in "${ESSENTIAL_APPS[@]}"; do
        if pacman -Ss "^$app$" &>/dev/null; then
            sudo pacman -S --needed --noconfirm "$app" || warning "Failed to install $app"
        else
            warning "$app not found in official repositories"
        fi
    done
elif [[ $APP_CHOICES != "$((${#ESSENTIAL_APPS[@]}+2))" ]]; then
    # Install selected applications
    IFS=',' read -ra SELECTED <<< "$APP_CHOICES"
    for choice in "${SELECTED[@]}"; do
        choice=$(echo "$choice" | tr -d ' ')
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#ESSENTIAL_APPS[@]}" ]; then
            app="${ESSENTIAL_APPS[$((choice-1))]}"
            if pacman -Ss "^$app$" &>/dev/null; then
                sudo pacman -S --needed --noconfirm "$app" || warning "Failed to install $app"
            else
                warning "$app not found in official repositories"
            fi
        fi
    done
fi

# ============================================================================
# STEP 8: Fonts and Media Codecs
# ============================================================================
log "🔤 Step 8: Installing fonts and media codecs"

FONTS_AND_MEDIA=(
    "noto-fonts"
    "noto-fonts-emoji"
    "ttf-dejavu"
    "ttf-liberation"
    "ttf-roboto"
    "gst-plugins-base"
    "gst-plugins-good"
    "gst-plugins-bad"
    "gst-plugins-ugly"
    "gst-libav"
)

sudo pacman -S --needed --noconfirm "${FONTS_AND_MEDIA[@]}"

# ============================================================================
# STEP 9: AUR Helper Installation
# ============================================================================
log "📦 Step 9: Installing AUR helper (yay)"

if ! command -v yay &> /dev/null; then
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    log "yay AUR helper installed successfully"
else
    info "yay is already installed"
fi

# ============================================================================
# STEP 10: GitHub and Development Tools Setup
# ============================================================================
log "👨‍💻 Step 10: Setting up development tools and GitHub"

# Install development tools
DEV_TOOLS=(
    "docker"
    "docker-compose"
    "nodejs"
    "npm"
    "python"
    "python-pip"
    "jq"
    "github-cli"
)

sudo pacman -S --needed --noconfirm "${DEV_TOOLS[@]}"

# Enable Docker service
sudo systemctl enable docker
sudo usermod -aG docker "$USER"

# GitHub CLI setup
read -p "Do you want to set up GitHub CLI? (y/N): " SETUP_GITHUB
if [[ $SETUP_GITHUB =~ ^[Yy]$ ]]; then
    info "Setting up GitHub CLI"
    echo "After reboot, run: gh auth login"

    # Git configuration
    read -p "Enter your Git username: " GIT_USERNAME
    read -p "Enter your Git email: " GIT_EMAIL

    if [[ -n "$GIT_USERNAME" && -n "$GIT_EMAIL" ]]; then
        git config --global user.name "$GIT_USERNAME"
        git config --global user.email "$GIT_EMAIL"
        git config --global init.defaultBranch main
        log "Git configuration completed"
    fi
fi

# ============================================================================
# STEP 11: Additional System Configuration
# ============================================================================
log "⚙️  Step 11: Additional system configuration"

# Enable some useful services
sudo systemctl enable fstrim.timer  # SSD optimization

# Install Bluetooth support
read -p "Do you need Bluetooth support? (y/N): " BLUETOOTH_SUPPORT
if [[ $BLUETOOTH_SUPPORT =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm bluez bluez-utils
    sudo systemctl enable bluetooth
fi

# Install printer support
read -p "Do you need printer support? (y/N): " PRINTER_SUPPORT
if [[ $PRINTER_SUPPORT =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm cups system-config-printer
    sudo systemctl enable cups
fi

# ============================================================================
# STEP 12: Firewall Setup
# ============================================================================
log "🔥 Step 12: Setting up firewall"

sudo pacman -S --needed --noconfirm ufw
sudo ufw enable
sudo systemctl enable ufw

# ============================================================================
# STEP 13: Shell Enhancement (Oh My Zsh)
# ============================================================================
log "🐚 Step 13: Setting up enhanced shell (zsh + Oh My Zsh)"

read -p "Do you want to install Zsh with Oh My Zsh? (y/N): " INSTALL_ZSH
if [[ $INSTALL_ZSH =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed --noconfirm zsh

    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

        # Install popular plugins
        git clone https://github.com/zsh-users/zsh-autosuggestions "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null || true
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true

        # Update .zshrc with plugins
        sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

        # Change default shell
        chsh -s $(which zsh)
        log "Zsh and Oh My Zsh installed successfully"
    else
        info "Oh My Zsh is already installed"
    fi
fi

# ============================================================================
# FINAL STEP: Cleanup and Summary
# ============================================================================
log "🧹 Final Step: Cleanup and summary"

# Clean package cache
sudo pacman -Sc --noconfirm

# Create a summary file
SUMMARY_FILE="$HOME/arch_setup_summary.txt"
cat > "$SUMMARY_FILE" << EOF
# Arch Linux Setup Summary - $(date)

## Installed Components:
- Desktop Environment: $DESKTOP_ENV
- Graphics Driver: $GPU_TYPE
- Audio System: PipeWire
- AUR Helper: yay
- Network Manager: NetworkManager

## Next Steps:
1. Reboot your system: sudo reboot
2. If you installed GitHub CLI, authenticate: gh auth login
3. If you installed Docker, log out and back in to use without sudo
4. Configure your desktop environment settings
5. Install additional AUR packages as needed: yay -S <package>

## Useful Commands:
- Update system: sudo pacman -Syu
- Install AUR packages: yay -S <package>
- Check system info: neofetch
- Monitor system: htop

## Configuration Files:
- Desktop Environment configs: ~/.config/
- Shell config: ~/.bashrc or ~/.zshrc
- Git config: ~/.gitconfig

Enjoy your new Arch Linux setup! 🎉
EOF

log "✅ Arch Linux setup completed successfully!"
info "📄 Summary saved to: $SUMMARY_FILE"
echo
info "🔄 Please reboot your system to complete the setup: sudo reboot"
echo
warning "⚠️  Important: If you installed Docker, you need to log out and back in to use it without sudo"

# Display final summary
echo
echo "=================================="
echo "        SETUP COMPLETE! 🎉        "
echo "=================================="
echo "Desktop Environment: $DESKTOP_ENV"
echo "Graphics: $GPU_TYPE driver"
echo "Summary file: $SUMMARY_FILE"
echo "=================================="
