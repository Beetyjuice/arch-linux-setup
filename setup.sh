#!/bin/bash

# Arch Linux Tiling Window Manager Setup Script
# This script sets up i3 window manager, Polybar status bar, and LightDM display manager
# Run this script as a regular user (not root)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as regular user."
   exit 1
fi

print_section "Starting Arch Linux Tiling Setup"

# Update system first
print_status "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install essential packages
print_section "Installing Core Packages"
print_status "Installing window manager and essential tools..."

# Core tiling setup packages
CORE_PACKAGES=(
    "i3-wm"              # The i3 window manager
    "i3status"           # Basic status bar (backup)
    "i3lock"             # Screen locking utility
    "dmenu"              # Application launcher
    "polybar"            # Advanced status bar
    "lightdm"            # Display manager (login screen)
    "lightdm-gtk-greeter" # GTK greeter for LightDM
    "xorg-server"        # X11 display server
    "xorg-xinit"         # X11 initialization
    "xorg-xrandr"        # Display configuration
    "xorg-xbacklight"    # Backlight control
    "picom"              # Compositor for transparency and effects
    "feh"                # Wallpaper setter
    "rofi"               # Modern application launcher (alternative to dmenu)
    "alacritty"          # Modern terminal emulator
    "thunar"             # File manager
    "firefox"            # Web browser
    "pulseaudio"         # Audio system
    "pulseaudio-alsa"    # ALSA compatibility
    "pavucontrol"        # Audio control GUI
    "network-manager-applet" # Network management
    "blueman"            # Bluetooth management
    "ttf-dejavu"         # Font package
    "ttf-font-awesome"   # Icon fonts for Polybar
)

for package in "${CORE_PACKAGES[@]}"; do
    print_status "Installing $package..."
    sudo pacman -S --noconfirm --needed "$package"
done

# Create necessary directories
print_section "Creating Configuration Directories"
mkdir -p ~/.config/i3
mkdir -p ~/.config/polybar
mkdir -p ~/.config/rofi
mkdir -p ~/.config/alacritty
mkdir -p ~/Pictures/Wallpapers

# Configure i3 window manager
print_section "Configuring i3 Window Manager"
print_status "Creating i3 configuration..."

cat > ~/.config/i3/config << 'EOF'
# i3 config file (v4)
# Please see https://i3wm.org/docs/userguide.html for a complete reference!

set $mod Mod4

# Font for window titles
font pango:DejaVu Sans Mono 8

# Use Mouse+$mod to drag floating windows
floating_modifier $mod

# Start a terminal
bindsym $mod+Return exec alacritty

# Kill focused window
bindsym $mod+Shift+q kill

# Start rofi (application launcher)
bindsym $mod+d exec --no-startup-id rofi -show drun

# Change focus
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Alternatively, you can use the cursor keys:
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# Move focused window
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# Alternatively, you can use the cursor keys:
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Split in horizontal orientation
bindsym $mod+h split h

# Split in vertical orientation
bindsym $mod+v split v

# Enter fullscreen mode for the focused container
bindsym $mod+f fullscreen toggle

# Change container layout (stacked, tabbed, toggle split)
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# Toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# Change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# Focus the parent container
bindsym $mod+a focus parent

# Define names for default workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# Switch to workspace
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

# Move focused container to workspace
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Reload the configuration file
bindsym $mod+Shift+c reload

# Restart i3 inplace (preserves your layout/session)
bindsym $mod+Shift+r restart

# Exit i3 (logs you out of your X session)
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'"

# Lock screen
bindsym $mod+Shift+x exec i3lock -c 000000

# Resize window mode
mode "resize" {
        bindsym j resize shrink width 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize shrink height 10 px or 10 ppt
        bindsym semicolon resize grow width 10 px or 10 ppt

        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt

        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
}

bindsym $mod+r mode "resize"

# Audio controls
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10%
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle

# Brightness controls
bindsym XF86MonBrightnessUp exec xbacklight -inc 20
bindsym XF86MonBrightnessDown exec xbacklight -dec 20

# Window appearance
for_window [class="^.*"] border pixel 2
gaps inner 5
gaps outer 5

# Colors
set $bg-color            #2f343f
set $inactive-bg-color   #2f343f
set $text-color          #f3f4f5
set $inactive-text-color #676E7D
set $urgent-bg-color     #E53935

# Window colors
client.focused          $bg-color           $bg-color          $text-color          #00ff00
client.unfocused        $inactive-bg-color $inactive-bg-color $inactive-text-color #00ff00
client.focused_inactive $inactive-bg-color $inactive-bg-color $inactive-text-color #00ff00
client.urgent           $urgent-bg-color    $urgent-bg-color   $text-color          #00ff00

# Hide i3bar (we'll use Polybar instead)
bar {
    mode invisible
}

# Startup applications
exec --no-startup-id picom -b
exec --no-startup-id nm-applet
exec --no-startup-id blueman-applet
exec --no-startup-id feh --bg-scale ~/Pictures/Wallpapers/wallpaper.jpg
exec_always --no-startup-id ~/.config/polybar/launch.sh
EOF

# Configure Polybar
print_section "Configuring Polybar Status Bar"
print_status "Creating Polybar configuration..."

cat > ~/.config/polybar/config.ini << 'EOF'
[colors]
background = #282A2E
background-alt = #373B41
foreground = #C5C8C6
primary = #F0C674
secondary = #8ABEB7
alert = #A54242
disabled = #707880

[bar/main]
width = 100%
height = 24pt
radius = 0

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 3pt

border-size = 0pt
border-color = #00000000

padding-left = 0
padding-right = 1

module-margin = 1

separator = |
separator-foreground = ${colors.disabled}

font-0 = monospace;2
font-1 = FontAwesome:size=10;2

modules-left = xworkspaces xwindow
modules-right = filesystem pulseaudio xkeyboard memory cpu wlan eth battery date

cursor-click = pointer
cursor-scroll = ns-resize

enable-ipc = true

[module/xworkspaces]
type = internal/xworkspaces

label-active = %name%
label-active-background = ${colors.background-alt}
label-active-underline= ${colors.primary}
label-active-padding = 1

label-occupied = %name%
label-occupied-padding = 1

label-urgent = %name%
label-urgent-background = ${colors.alert}
label-urgent-padding = 1

label-empty = %name%
label-empty-foreground = ${colors.disabled}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:60:...%

[module/filesystem]
type = internal/fs
interval = 25

mount-0 = /

label-mounted = %{F#F0C674}%mountpoint%%{F-} %percentage_used%%

label-unmounted = %mountpoint% not mounted
label-unmounted-foreground = ${colors.disabled}

[module/pulseaudio]
type = internal/pulseaudio

format-volume-prefix = "VOL "
format-volume-prefix-foreground = ${colors.primary}
format-volume = <label-volume>

label-volume = %percentage%%

label-muted = muted
label-muted-foreground = ${colors.disabled}

[module/xkeyboard]
type = internal/xkeyboard
blacklist-0 = num lock

label-layout = %layout%
label-layout-foreground = ${colors.primary}

label-indicator-padding = 2
label-indicator-margin = 1
label-indicator-foreground = ${colors.background}
label-indicator-background = ${colors.secondary}

[module/memory]
type = internal/memory
interval = 2
format-prefix = "RAM "
format-prefix-foreground = ${colors.primary}
label = %percentage_used:2%%

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "CPU "
format-prefix-foreground = ${colors.primary}
label = %percentage:2%%

[network-base]
type = internal/network
interval = 5
format-connected = <label-connected>
format-disconnected = <label-disconnected>
label-disconnected = %{F#F0C674}%ifname%%{F#707880} disconnected

[module/wlan]
inherit = network-base
interface-type = wireless
label-connected = %{F#F0C674}%ifname%%{F-} %essid% %local_ip%

[module/eth]
inherit = network-base
interface-type = wired
label-connected = %{F#F0C674}%ifname%%{F-} %local_ip%

[module/battery]
type = internal/battery
battery = BAT0
adapter = ADP1
full-at = 98

format-charging = <animation-charging> <label-charging>
label-charging = %percentage%%

format-discharging = <ramp-capacity> <label-discharging>
label-discharging = %percentage%%

format-full-prefix = " "
format-full-prefix-foreground = ${colors.primary}

ramp-capacity-0 =
ramp-capacity-1 =
ramp-capacity-2 =
ramp-capacity-foreground = ${colors.foreground-alt}

animation-charging-0 =
animation-charging-1 =
animation-charging-2 =
animation-charging-foreground = ${colors.foreground-alt}
animation-charging-framerate = 750

[module/date]
type = internal/date
interval = 1

date = %H:%M
date-alt = %Y-%m-%d %H:%M:%S

label = %date%
label-foreground = ${colors.primary}

[settings]
screenchange-reload = true
pseudo-transparency = true
EOF

# Create Polybar launch script
print_status "Creating Polybar launch script..."
cat > ~/.config/polybar/launch.sh << 'EOF'
#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch polybar
echo "---" | tee -a /tmp/polybar.log
polybar main 2>&1 | tee -a /tmp/polybar.log & disown

echo "Polybar launched..."
EOF

chmod +x ~/.config/polybar/launch.sh

# Configure Rofi
print_section "Configuring Rofi Application Launcher"
print_status "Creating Rofi configuration..."

cat > ~/.config/rofi/config.rasi << 'EOF'
configuration{
    modi: "run,drun,window";
    icon-theme: "Oranchelo";
    show-icons: true;
    terminal: "alacritty";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "   Apps ";
    display-run: "   Run ";
    display-window: " 﩯  Window";
    display-Network: " 󰤨  Network";
    sidebar-mode: true;
}

@theme "gruvbox-dark"
EOF

# Configure Alacritty terminal
print_section "Configuring Alacritty Terminal"
print_status "Creating Alacritty configuration..."

cat > ~/.config/alacritty/alacritty.yml << 'EOF'
window:
  opacity: 0.9
  padding:
    x: 10
    y: 10

font:
  normal:
    family: DejaVu Sans Mono
    style: Regular
  bold:
    family: DejaVu Sans Mono
    style: Bold
  italic:
    family: DejaVu Sans Mono
    style: Italic
  size: 11.0

colors:
  primary:
    background: '#282828'
    foreground: '#ebdbb2'
  normal:
    black:   '#282828'
    red:     '#cc241d'
    green:   '#98971a'
    yellow:  '#d79921'
    blue:    '#458588'
    magenta: '#b16286'
    cyan:    '#689d6a'
    white:   '#a89984'
  bright:
    black:   '#928374'
    red:     '#fb4934'
    green:   '#b8bb26'
    yellow:  '#fabd2f'
    blue:    '#83a598'
    magenta: '#d3869b'
    cyan:    '#8ec07c'
    white:   '#ebdbb2'
EOF

# Download a sample wallpaper
print_section "Setting Up Wallpaper"
print_status "Downloading sample wallpaper..."

# Create a simple gradient wallpaper if we can't download one
if command -v convert >/dev/null 2>&1; then
    convert -size 1920x1080 gradient:#2e3440-#3b4252 ~/Pictures/Wallpapers/wallpaper.jpg
else
    # Create a solid color image as fallback
    echo "Creating fallback wallpaper..."
    mkdir -p ~/Pictures/Wallpapers
    # We'll use feh to set a solid color later
    touch ~/Pictures/Wallpapers/wallpaper.jpg
fi

# Configure LightDM
print_section "Configuring LightDM Display Manager"
print_status "Setting up LightDM configuration..."

sudo tee /etc/lightdm/lightdm.conf > /dev/null << 'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=i3
autologin-guest=false
autologin-user-timeout=0
EOF

# Enable LightDM service
print_status "Enabling LightDM service..."
sudo systemctl enable lightdm.service

# Enable NetworkManager
print_status "Enabling NetworkManager..."
sudo systemctl enable NetworkManager.service

# Create .xinitrc for manual X start (alternative to display manager)
print_section "Creating .xinitrc"
print_status "Setting up .xinitrc for manual X session start..."

cat > ~/.xinitrc << 'EOF'
#!/bin/sh

# Start PulseAudio
pulseaudio --start --log-target=syslog

# Start i3 window manager
exec i3
EOF

chmod +x ~/.xinitrc

# Create desktop session file for i3
print_status "Creating i3 desktop session file..."
sudo tee /usr/share/xsessions/i3.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=i3
TryExec=i3
Type=Application
X-LightDM-DesktopName=i3
DesktopNames=i3
Keywords=tiling;wm;windowmanager;window;manager;
EOF

print_section "Setup Complete!"
print_status "Your tiling window manager setup is now ready!"

echo -e "\n${GREEN}What's been installed and configured:${NC}"
echo "• i3 Window Manager - Keyboard-driven tiling window manager"
echo "• Polybar - Modern status bar showing system information"
echo "• LightDM - Graphical login manager"
echo "• Rofi - Application launcher (press Super+D)"
echo "• Alacritty - Modern terminal emulator"
echo "• Basic desktop utilities and themes"

echo -e "\n${YELLOW}Important Key Bindings:${NC}"
echo "• Super+Return - Open terminal"
echo "• Super+D - Open application launcher (Rofi)"
echo "• Super+Shift+Q - Close window"
echo "• Super+Number - Switch to workspace"
echo "• Super+Shift+Number - Move window to workspace"
echo "• Super+H/V - Split horizontal/vertical"
echo "• Super+F - Fullscreen toggle"
echo "• Super+Shift+X - Lock screen"
echo "• Super+Shift+R - Restart i3"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "1. Reboot your system: sudo reboot"
echo "2. Select 'i3' at the login screen"
echo "3. Customize your setup by editing ~/.config/i3/config"
echo "4. Customize Polybar by editing ~/.config/polybar/config.ini"
echo "5. Add your own wallpapers to ~/Pictures/Wallpapers/"

echo -e "\n${GREEN}Optional: To start X manually instead of using LightDM:${NC}"
echo "• Disable LightDM: sudo systemctl disable lightdm"
echo "• Start X from TTY: startx"

print_warning "Please reboot to start using your new desktop environment!"
EOF
