#!/bin/bash
# Linux YTMDL Setup Script
# This script sets up your Linux environment for YTMDL

# Terminal colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
RESET="\033[0m"

# Print colorful messages
print_message() {
    echo -e "${BLUE}==>${RESET} ${WHITE}$1${RESET}"
}

print_success() {
    echo -e "${GREEN}==>${RESET} ${WHITE}$1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}==>${RESET} ${WHITE}$1${RESET}"
}

print_error() {
    echo -e "${RED}==>${RESET} ${WHITE}$1${RESET}"
}

# Detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt install -y"
        PKG_UPDATE="apt update"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum check-update"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
    else
        print_error "No supported package manager found."
        print_error "This script supports apt, dnf, yum, pacman, and zypper."
        exit 1
    fi
    print_success "Detected package manager: $PKG_MANAGER"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install a package if not already installed
install_package() {
    local package_name="$1"
    local package_cmd="$2"
    local version_cmd="$3"
    
    if command_exists "$package_cmd"; then
        if [ -z "$version_cmd" ]; then
            print_success "$package_name is already installed"
        else
            version=$($version_cmd)
            print_success "$package_name is already installed: $version"
        fi
        return 0
    else
        if [ "$package_name" = "Python 3" ] || [ "$package_name" = "ffmpeg" ] || [ "$package_name" = "pip" ]; then
            read -p "Would you like to install $package_name? (y/n) [y]: " install_choice
            install_choice=${install_choice:-y}
            if [[ $install_choice != "y" && $install_choice != "Y" ]]; then
                print_warning "$package_name installation skipped."
                return 1
            fi
        fi

        print_message "Installing $package_name..."
        
        # Special case for pip
        if [ "$package_name" = "pip" ]; then
            if [ "$PKG_MANAGER" = "apt" ]; then
                sudo $PKG_INSTALL python3-pip
            elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
                sudo $PKG_INSTALL python3-pip
            elif [ "$PKG_MANAGER" = "pacman" ]; then
                sudo $PKG_INSTALL python-pip
            elif [ "$PKG_MANAGER" = "zypper" ]; then
                sudo $PKG_INSTALL python3-pip
            else
                # Fallback to installing pip using get-pip.py
                print_message "Using alternative method to install pip..."
                curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
                python3 get-pip.py --user
                rm get-pip.py
            fi
        else
            sudo $PKG_INSTALL $package_name
        fi
        
        if [ $? -ne 0 ]; then
            print_error "$package_name installation failed!"
            return 1
        fi
        
        if command_exists "$package_cmd"; then
            if [ -z "$version_cmd" ]; then
                print_success "$package_name installed successfully"
            else
                version=$($version_cmd)
                print_success "$package_name installed successfully: $version"
            fi
            return 0
        else
            print_error "$package_name installation verification failed!"
            return 1
        fi
    fi
}

# Function to clone or update repository
setup_repository() {
    local repo_path="$HOME/ytmdl"
    
    if [ -d "$repo_path" ] && [ "$(ls -A "$repo_path" 2>/dev/null)" ]; then
        print_message "The ~/ytmdl directory already exists and is not empty."
        echo "  [1] Update the existing repository"
        echo "  [2] Overwrite with a fresh clone"
        echo "  [3] Skip repository operations"
        read -p "Choose an option [1]: " repo_choice
        repo_choice=${repo_choice:-1}
        
        case "$repo_choice" in
            1)
                print_message "Updating repository..."
                cd "$repo_path"
                git pull
                ;;
            2)
                print_message "Creating fresh ytmdl directory..."
                rm -rf "$repo_path"
                mkdir -p "$repo_path"
                cd "$repo_path"
                print_message "Cloning ytmdl repository..."
                git clone https://github.com/KaedeYure/ytmdl.git .
                ;;
            3)
                print_message "Skipping repository operations."
                cd "$repo_path"
                ;;
            *)
                print_message "Invalid option. Updating repository..."
                cd "$repo_path"
                git pull
                ;;
        esac
    else
        print_message "Creating ytmdl directory..."
        mkdir -p "$repo_path"
        cd "$repo_path"
        print_message "Cloning ytmdl repository..."
        git clone https://github.com/KaedeYure/ytmdl.git .
    fi
    
    # Check if operation was successful
    if [ $? -ne 0 ]; then
        print_error "Repository operation failed!"
        return 1
    else
        print_success "Repository setup completed successfully!"
    fi
    return 0
}

# Install npm dependencies
install_dependencies() {
    local repo_path="$HOME/ytmdl"
    
    if [ -f "$repo_path/package.json" ]; then
        print_message "Installing Node.js dependencies..."
        cd "$repo_path"
        npm install
        
        if [ $? -ne 0 ]; then
            print_error "Failed to install dependencies!"
            return 1
        fi
        
        # Install sharp
        print_message "Installing sharp image processing library..."
        npm install sharp
        
        if [ $? -ne 0 ]; then
            print_error "Failed to install sharp!"
            return 1
        fi
        
        # Run npm setup script if it exists
        if grep -q '"setup"' package.json; then
            print_message "Running setup script..."
            npm run setup
            
            if [ $? -ne 0 ]; then
                print_error "Setup script failed!"
                return 1
            fi
            
            print_success "Setup script completed successfully!"
        else
            print_warning "No setup script found in package.json"
        fi
        
        print_success "Dependencies installed successfully!"
    else
        print_warning "No package.json found, skipping dependency installation."
    fi
    
    return 0
}

# Main setup process
main() {
    # Welcome message
    echo -e "\n${GREEN}====== Linux YTMDL Setup ======${RESET}\n"
    print_message "This script will set up your Linux environment for YTMDL."
    print_message "You'll only be prompted for Python, pip and ffmpeg installations."
    
    # Detect package manager
    detect_package_manager
    
    # Update package lists
    print_message "Updating package lists..."
    sudo $PKG_UPDATE
    
    # Install required packages
    install_package "git" "git" "git --version"
    git_installed=$?
    
    install_package "nodejs" "node" "node --version"
    node_installed=$?
    
    # Check npm installation after node
    if command_exists npm; then
        npm_version=$(npm --version)
        print_success "npm is installed: $npm_version"
        npm_installed=0
    else
        print_warning "Node.js is installed but npm was not found. This is unusual."
        install_package "npm" "npm" "npm --version"
        npm_installed=$?
    fi
    
    # Install Python 3 (with confirmation)
    if [ "$PKG_MANAGER" = "apt" ]; then
        install_package "python3" "python3" "python3 --version"
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        install_package "python" "python3" "python3 --version"
    else
        install_package "python3" "python3" "python3 --version"
    fi
    python_installed=$?
    
    # Check for pip and install if needed (with confirmation)
    if command_exists pip3; then
        pip_version=$(pip3 --version)
        print_success "pip is installed: $pip_version"
    elif command_exists pip; then
        pip_version=$(pip --version)
        print_success "pip is installed: $pip_version"
    else
        print_warning "Python is installed but pip was not found."
        install_package "pip" "pip3" "pip3 --version"
    fi
    
    # Install ffmpeg (with confirmation)
    install_package "ffmpeg" "ffmpeg" "ffmpeg -version | head -n 1"
    ffmpeg_installed=$?
    
    # Repository setup only if Git is installed
    if [ $git_installed -eq 0 ]; then
        setup_repository
    else
        print_warning "Repository setup skipped because Git is not installed."
    fi
    
    # Install dependencies only if Node.js and npm are installed
    if [ $node_installed -eq 0 ] && [ $npm_installed -eq 0 ]; then
        install_dependencies
    else
        print_warning "Dependency installation skipped because Node.js or npm is not installed."
    fi
    
    # Print summary
    echo ""
    print_success "Setup completed successfully!"
    echo ""
    echo -e "${GREEN}Summary:${RESET}"
    
    if command_exists git; then
        echo "- Git: $(git --version)"
    else
        echo "- Git: Not installed"
    fi
    
    if command_exists node; then
        echo "- Node.js: $(node --version)"
    else
        echo "- Node.js: Not installed"
    fi
    
    if command_exists npm; then
        echo "- npm: $(npm --version)"
    else
        echo "- npm: Not installed"
    fi
    
    if command_exists python3; then
        echo "- Python: $(python3 --version)"
    else
        echo "- Python: Not installed"
    fi
    
    if command_exists pip3; then
        echo "- pip: $(pip3 --version)"
    elif command_exists pip; then
        echo "- pip: $(pip --version)"
    else
        echo "- pip: Not installed"
    fi
    
    if command_exists ffmpeg; then
        echo "- ffmpeg: $(ffmpeg -version | head -n 1)"
    else
        echo "- ffmpeg: Not installed"
    fi
    
    echo "- Repository location: $HOME/ytmdl"
    
    echo ""
    echo -e "${BLUE}Next steps:${RESET}"
    echo "1. Navigate to the ytmdl directory: cd ~/ytmdl"
    echo "2. Run the application: node index.js"
    echo ""
}

# Run the main function
main