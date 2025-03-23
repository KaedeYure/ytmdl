#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
WHITE="\033[1;37m"
RESET="\033[0m"

# Print colorful messages
function print_message() {
    echo -e "${BLUE}==>${RESET} ${WHITE}$1${RESET}"
}

function print_success() {
    echo -e "${GREEN}==>${RESET} ${WHITE}$1${RESET}"
}

function print_error() {
    echo -e "${RED}==>${RESET} ${WHITE}$1${RESET}"
}

# Make sure we're running in Termux
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    print_error "This script must be run in Termux!"
    exit 1
fi

# Initial setup
print_message "Performing initial Termux setup..."
termux-setup-storage

# Update and upgrade packages without asking
print_message "Updating package lists and upgrading packages..."
apt update -y && apt upgrade -y

# Install essential tools
print_message "Installing essential packages..."
apt install -y coreutils nano wget curl proot

# Check and install Git
if command -v git &> /dev/null; then
    print_success "Git is already installed: $(git --version)"
else
    print_message "Installing Git..."
    apt install -y git
    
    # Check git installation
    if ! command -v git &> /dev/null; then
        print_error "Git installation failed!"
        exit 1
    else
        print_success "Git installed successfully: $(git --version)"
    fi
fi

# Check and install Node.js
if command -v node &> /dev/null; then
    print_success "Node.js is already installed: $(node --version)"
else
    print_message "Installing Node.js..."
    apt install -y nodejs
    
    # Check Node.js installation
    if ! command -v node &> /dev/null; then
        print_error "Node.js installation failed!"
        exit 1
    else
        print_success "Node.js installed successfully: $(node --version)"
    fi
fi

# Check and install npm
if command -v npm &> /dev/null; then
    print_success "npm is already installed: $(npm --version)"
else
    print_message "Installing npm..."
    apt install -y npm
    
    # Check npm installation
    if ! command -v npm &> /dev/null; then
        print_error "npm installation failed!"
        exit 1
    else
        print_success "npm installed successfully: $(npm --version)"
    fi
fi

# Check and install Python 3
if command -v python3 &> /dev/null; then
    print_success "Python 3 is already installed: $(python3 --version)"
else
    print_message "Installing Python 3..."
    apt install -y python
    
    # Check Python 3 installation
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 installation failed!"
        exit 1
    else
        print_success "Python 3 installed successfully: $(python3 --version)"
    fi
fi

# Check and install pip for Python 3
if command -v pip3 &> /dev/null; then
    print_success "pip3 is already installed: $(pip3 --version)"
else
    print_message "Installing pip for Python 3..."
    apt install -y python-pip
    
    # Check pip3 installation
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 installation failed!"
        exit 1
    else
        print_success "pip3 installed successfully: $(pip3 --version)"
    fi
fi

# Check and install ffmpeg
if command -v ffmpeg &> /dev/null; then
    print_success "ffmpeg is already installed: $(ffmpeg -version | head -n 1)"
else
    print_message "Installing ffmpeg..."
    apt install -y ffmpeg
    
    # Check ffmpeg installation
    if ! command -v ffmpeg &> /dev/null; then
        print_error "ffmpeg installation failed!"
        exit 1
    else
        print_success "ffmpeg installed successfully: $(ffmpeg -version | head -n 1)"
    fi
fi

# Check if ytmdl directory already exists
if [ -d ~/ytmdl ] && [ "$(ls -A ~/ytmdl)" ]; then
    print_message "The ~/ytmdl directory already exists and is not empty."
    print_message "Creating fresh ytmdl directory in home folder..."
    rm -rf ~/ytmdl
    mkdir -p ~/ytmdl
    cd ~/ytmdl
    
    print_message "Cloning ytmdl repository..."
    git clone https://github.com/KaedeYure/ytmdl.git .
else
    print_message "Creating ytmdl directory in home folder..."
    mkdir -p ~/ytmdl
    cd ~/ytmdl
    
    print_message "Cloning ytmdl repository..."
    git clone https://github.com/KaedeYure/ytmdl.git .
fi

# Check if clone was successful
if [ $? -ne 0 ]; then
    print_error "Failed to clone the repository!"
    exit 1
else
    print_success "Repository cloned successfully!"
fi

# Install dependencies if package.json exists
if [ -f "package.json" ]; then
    print_message "Installing Node.js dependencies..."
    npm install
    
    # Install sharp with WASM support for Android
    print_message "Installing sharp with WASM support for Termux..."
    npm install --cpu=wasm32 sharp
    
    if [ $? -ne 0 ]; then
        print_error "Failed to install dependencies!"
        exit 1
    else
        print_success "Dependencies installed successfully!"
    fi
else
    print_message "No package.json found, skipping dependency installation."
fi

# Print summary
echo ""
print_success "Setup completed successfully!"
echo ""
echo -e "${GREEN}Summary:${RESET}"
echo "- Termux storage access setup"
echo "- Git installed: $(git --version)"
echo "- Node.js installed: $(node --version)"
echo "- npm installed: $(npm --version)"
echo "- Python 3 installed: $(python3 --version)"
echo "- pip3 installed: $(pip3 --version)"
echo "- ffmpeg installed: $(ffmpeg -version | head -n 1)"
echo "- Repository location: $HOME/ytmdl"