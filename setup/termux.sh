#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
WHITE="\033[1;37m"
RESET="\033[0m"

# Print colorful messages functions
print_message() {
    echo -e "${BLUE}==>${RESET} ${WHITE}$1${RESET}"
}

print_success() {
    echo -e "${GREEN}==>${RESET} ${WHITE}$1${RESET}"
}

print_error() {
    echo -e "${RED}==>${RESET} ${WHITE}$1${RESET}"
}

# Check if running in Termux
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    print_error "This script must be run in Termux!"
    exit 1
fi

# Banner
echo -e "\n${GREEN}====== Termux YTMDL Setup ======${RESET}\n"
print_message "This script will set up your Termux environment for YTMDL."

# Setup storage access
print_message "Setting up Termux storage access..."
termux-setup-storage || {
    print_error "Failed to set up Termux storage access."
    exit 1
}

# Update packages
print_message "Updating package lists and upgrading packages..."
apt update && apt upgrade -y || {
    print_error "Failed to update packages."
    exit 1
}

# Install essential packages
print_message "Installing essential packages..."
apt install -y coreutils nano wget curl proot || {
    print_error "Failed to install essential packages."
    exit 1
}

# Install git
print_message "Installing git..."
apt install -y git || {
    print_error "Failed to install git."
    exit 1
}

# Verify git installation
if command -v git &> /dev/null; then
    print_success "Git installed successfully: $(git --version)"
else
    print_error "Git installation failed!"
    exit 1
fi

# Install Node.js
print_message "Installing Node.js..."
apt install -y nodejs || {
    print_error "Failed to install Node.js."
    exit 1
}

# Verify Node.js installation
if command -v node &> /dev/null; then
    print_success "Node.js installed successfully: $(node --version)"
else
    print_error "Node.js installation failed!"
    exit 1
fi

# Install npm
print_message "Installing npm..."
apt install -y npm || {
    print_error "Failed to install npm."
    exit 1
}

# Verify npm installation
if command -v npm &> /dev/null; then
    print_success "npm installed successfully: $(npm --version)"
else
    print_error "npm installation failed!"
    exit 1
fi

# Install Python 3
print_message "Installing Python 3..."
apt install -y python3 || {
    print_error "Failed to install Python 3."
    exit 1
}

# Verify Python 3 installation
if command -v python3 &> /dev/null; then
    print_success "Python 3 installed successfully: $(python3 --version)"
else
    print_error "Python 3 installation failed!"
    exit 1
fi

# Install pip
print_message "Installing pip for Python 3..."
apt install -y python-pip || {
    print_error "Failed to install pip."
    exit 1
}

# Verify pip installation
if command -v pip3 &> /dev/null; then
    print_success "pip3 installed successfully: $(pip3 --version)"
else
    print_error "pip3 installation failed!"
    exit 1
fi

# Install ffmpeg
print_message "Installing ffmpeg..."
apt install -y ffmpeg || {
    print_error "Failed to install ffmpeg."
    exit 1
}

# Verify ffmpeg installation
if command -v ffmpeg &> /dev/null; then
    print_success "ffmpeg installed successfully: $(ffmpeg -version | head -n 1)"
else
    print_error "ffmpeg installation failed!"
    exit 1
fi

# Set up ytmdl directory
print_message "Setting up ytmdl directory..."
if [ -d ~/ytmdl ]; then
    print_message "Removing existing ytmdl directory..."
    rm -rf ~/ytmdl || {
        print_error "Failed to remove existing ytmdl directory."
        exit 1
    }
fi

# Create ytmdl directory
print_message "Creating ytmdl directory..."
mkdir -p ~/ytmdl || {
    print_error "Failed to create ytmdl directory."
    exit 1
}

# Change to ytmdl directory
cd ~/ytmdl || {
    print_error "Failed to change to ytmdl directory."
    exit 1
}

# Clone repository
print_message "Cloning ytmdl repository..."
git clone https://github.com/KaedeYure/ytmdl.git . || {
    print_error "Failed to clone repository."
    exit 1
}
print_success "Repository cloned successfully!"

# Install Node.js dependencies if package.json exists
if [ -f "package.json" ]; then
    print_message "Installing Node.js dependencies..."
    npm install || {
        print_error "Failed to install Node.js dependencies."
        exit 1
    }
    
    # Install sharp with WASM support
    print_message "Installing sharp with WASM support..."
    npm install --cpu=wasm32 sharp || {
        print_error "Failed to install sharp with WASM support."
        exit 1
    }
    print_success "Node.js dependencies installed successfully!"
else
    print_message "No package.json found, skipping dependency installation."
fi

# Print summary
echo ""
print_success "Setup completed successfully!"
echo ""
echo -e "${GREEN}Summary:${RESET}"
echo "- Termux storage access: Set up"
echo "- Git: $(git --version)"
echo "- Node.js: $(node --version)"
echo "- npm: $(npm --version)"
echo "- Python 3: $(python3 --version)"
echo "- pip3: $(pip3 --version)"
echo "- ffmpeg: $(ffmpeg -version | head -n 1)"
echo "- Repository: $HOME/ytmdl"
echo ""
echo -e "${BLUE}Next steps:${RESET}"
echo "1. Navigate to the ytmdl directory: cd ~/ytmdl"
echo "2. Run the application: node index.js"
echo ""