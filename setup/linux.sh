#!/bin/bash

# Set colors for console output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print colorful messages
print_message() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}==>${NC} $1"
}

# Function to detect the package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt install -y"
        PKG_UPDATE="apt update && apt upgrade -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf update -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum update -y"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Syu --noconfirm"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper update -y"
    else
        print_error "No supported package manager found (apt, dnf, yum, pacman, zypper)"
        exit 1
    fi
    print_success "Detected package manager: $PKG_MANAGER"
}

# Check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
}

# Function to install necessary packages
install_dependencies() {
    print_message "Updating package lists..."
    eval "$PKG_UPDATE"

    print_message "Installing dependencies..."
    case $PKG_MANAGER in
        apt)
            $PKG_INSTALL git nodejs npm python3 python3-pip ffmpeg curl
            ;;
        dnf|yum)
            $PKG_INSTALL git nodejs npm python3 python3-pip ffmpeg curl
            ;;
        pacman)
            $PKG_INSTALL git nodejs npm python python-pip ffmpeg curl
            ;;
        zypper)
            $PKG_INSTALL git nodejs npm python3 python3-pip ffmpeg curl
            ;;
    esac

    if [ $? -ne 0 ]; then
        print_error "Failed to install dependencies"
        exit 1
    else
        print_success "Dependencies installed successfully"
    fi
}

# Function to check for Node.js
check_nodejs() {
    print_message "Checking for Node.js..."
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js is already installed: $NODE_VERSION"
    else
        print_message "Installing Node.js..."
        if [ "$PKG_MANAGER" == "apt" ]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            $PKG_INSTALL nodejs
        else
            eval "$PKG_INSTALL nodejs npm"
        fi
        
        if command -v node &> /dev/null; then
            NODE_VERSION=$(node --version)
            print_success "Node.js installed successfully: $NODE_VERSION"
        else
            print_error "Failed to install Node.js"
            exit 1
        fi
    fi
}

# Function to check for Git
check_git() {
    print_message "Checking for Git..."
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version)
        print_success "Git is already installed: $GIT_VERSION"
    else
        print_message "Installing Git..."
        eval "$PKG_INSTALL git"
        
        if command -v git &> /dev/null; then
            GIT_VERSION=$(git --version)
            print_success "Git installed successfully: $GIT_VERSION"
        else
            print_error "Failed to install Git"
            exit 1
        fi
    fi
}

# Function to check for Python
check_python() {
    print_message "Checking for Python 3..."
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        print_success "Python 3 is already installed: $PYTHON_VERSION"
    else
        print_message "Installing Python 3..."
        case $PKG_MANAGER in
            apt|dnf|yum|zypper)
                eval "$PKG_INSTALL python3 python3-pip"
                ;;
            pacman)
                eval "$PKG_INSTALL python python-pip"
                ;;
        esac
        
        if command -v python3 &> /dev/null; then
            PYTHON_VERSION=$(python3 --version)
            print_success "Python 3 installed successfully: $PYTHON_VERSION"
        else
            print_error "Failed to install Python 3"
            exit 1
        fi
    fi
}

# Function to check for FFmpeg
check_ffmpeg() {
    print_message "Checking for FFmpeg..."
    if command -v ffmpeg &> /dev/null; then
        FFMPEG_VERSION=$(ffmpeg -version | head -n 1)
        print_success "FFmpeg is already installed: $FFMPEG_VERSION"
    else
        print_message "Installing FFmpeg..."
        eval "$PKG_INSTALL ffmpeg"
        
        if command -v ffmpeg &> /dev/null; then
            FFMPEG_VERSION=$(ffmpeg -version | head -n 1)
            print_success "FFmpeg installed successfully: $FFMPEG_VERSION"
        else
            print_error "Failed to install FFmpeg"
            exit 1
        fi
    fi
}

# Function to create ytmdl directory and clone repository
setup_repository() {
    print_message "Setting up ytmdl..."
    
    # Get the user who executed sudo
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        USER_HOME=$HOME
    fi
    
    YTMDL_DIR="$USER_HOME/ytmdl"
    
    if [ -d "$YTMDL_DIR" ]; then
        print_message "The ytmdl directory already exists."
        read -p "Do you want to overwrite it? (y/n): " OVERWRITE
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            print_message "Skipping repository clone."
            return
        else
            print_message "Removing existing directory..."
            rm -rf "$YTMDL_DIR"
        fi
    fi
    
    print_message "Creating ytmdl directory in $USER_HOME..."
    mkdir -p "$YTMDL_DIR"
    
    # Make sure the directory is owned by the actual user, not root
    if [ -n "$SUDO_USER" ]; then
        chown -R $SUDO_USER:$(id -gn $SUDO_USER) "$YTMDL_DIR"
    fi
    
    print_message "Cloning ytmdl repository..."
    # Use the actual user to clone the repository
    if [ -n "$SUDO_USER" ]; then
        su - $SUDO_USER -c "cd $YTMDL_DIR && git clone https://github.com/KaedeYure/ytmdl.git ."
    else
        cd "$YTMDL_DIR" && git clone https://github.com/KaedeYure/ytmdl.git .
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to clone the repository"
        exit 1
    else
        print_success "Repository cloned successfully to $YTMDL_DIR"
    fi
    
    # Install dependencies
    if [ -f "$YTMDL_DIR/package.json" ]; then
        print_message "Installing Node.js dependencies..."
        if [ -n "$SUDO_USER" ]; then
            su - $SUDO_USER -c "cd $YTMDL_DIR && npm install"
        else
            cd "$YTMDL_DIR" && npm install
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Failed to install dependencies"
            exit 1
        else
            print_success "Dependencies installed successfully"
        fi
    else
        print_message "No package.json found, skipping dependency installation."
    fi
    
    # Create startup script
    SCRIPT_CONTENT="#!/bin/bash
cd \$(dirname \"\$0\")
if [ -z \"\$1\" ]; then
  npm start
else
  npm run \"\$@\"
fi"
    
    echo "$SCRIPT_CONTENT" > "$YTMDL_DIR/ytmdl"
    chmod +x "$YTMDL_DIR/ytmdl"
    
    # Create desktop shortcut
    DESKTOP_FILE="[Desktop Entry]
Name=YouTube Music Downloader
Comment=Download music from YouTube
Exec=$YTMDL_DIR/ytmdl
Icon=multimedia-player
Terminal=false
Type=Application
Categories=Audio;Video;Network;"
    
    if [ -n "$SUDO_USER" ]; then
        DESKTOP_DIR="$(eval echo ~$SUDO_USER)/.local/share/applications"
        mkdir -p "$DESKTOP_DIR"
        echo "$DESKTOP_FILE" > "$DESKTOP_DIR/ytmdl.desktop"
        chown $SUDO_USER:$(id -gn $SUDO_USER) "$DESKTOP_DIR/ytmdl.desktop"
    else
        DESKTOP_DIR="$HOME/.local/share/applications"
        mkdir -p "$DESKTOP_DIR"
        echo "$DESKTOP_FILE" > "$DESKTOP_DIR/ytmdl.desktop"
    fi
    
    print_success "Desktop shortcut created"
    
    # Set correct permissions for ytmdl directory
    if [ -n "$SUDO_USER" ]; then
        chown -R $SUDO_USER:$(id -gn $SUDO_USER) "$YTMDL_DIR"
    fi
}

# Create symbolic link to make ytmdl available system-wide
create_symlink() {
    # Get the user who executed sudo
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        USER_HOME=$HOME
    fi
    
    YTMDL_DIR="$USER_HOME/ytmdl"
    
    print_message "Creating symbolic link..."
    ln -sf "$YTMDL_DIR/ytmdl" /usr/local/bin/ytmdl
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create symbolic link"
    else
        print_success "Symbolic link created, ytmdl is now available system-wide"
    fi
}

# Main function
main() {
    clear
    echo "======================================================="
    echo "     YouTube Music Downloader Setup - Linux Version    "
    echo "======================================================="
    echo ""
    
    check_root
    detect_package_manager
    check_git
    check_nodejs
    check_python
    check_ffmpeg
    setup_repository
    create_symlink
    
    echo ""
    print_success "Setup completed successfully!"
    echo ""
    echo "Summary:"
    echo "- Git installed: $(git --version)"
    echo "- Node.js installed: $(node --version)"
    echo "- npm installed: $(npm --version)"
    echo "- Python 3 installed: $(python3 --version)"
    echo "- FFmpeg installed: $(ffmpeg -version | head -n 1)"
    
    # Get the user who executed sudo
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(eval echo ~$SUDO_USER)
    else
        USER_HOME=$HOME
    fi
    
    echo "- Repository cloned to: $USER_HOME/ytmdl"
    echo ""
    echo "You can now run the application in the following ways:"
    echo "1. Using the system-wide command: ytmdl"
    echo "2. From the installation directory: $USER_HOME/ytmdl/ytmdl"
    echo "3. Through the desktop shortcut in your applications menu"
    echo ""
}

# Run the main function
main