#!/data/data/com.termux/files/usr/bin/bash

# Terminal colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
WHITE="\033[1;37m"
RESET="\033[0m"

# Print colorful messages
print_message() {
    echo -e "${BLUE}==>${RESET} ${WHITE}$1${RESET}"
}

print_success() {
    echo -e "${GREEN}==>${RESET} ${WHITE}$1${RESET}"
}

print_error() {
    echo -e "${RED}==>${RESET} ${WHITE}$1${RESET}"
}

# Check if script is running in Termux
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    print_error "This script must be run in Termux!"
    exit 1
fi

# Function to install a package if not already installed
install_package() {
    local package_name="$1"
    local package_cmd="$2"
    local version_cmd="$3"
    
    if command -v "$package_cmd" &> /dev/null; then
        print_success "$package_name is already installed: $($version_cmd)"
    else
        print_message "Installing $package_name..."
        apt install -y "$package_name"
        
        if ! command -v "$package_cmd" &> /dev/null; then
            print_error "$package_name installation failed!"
            return 1
        else
            print_success "$package_name installed successfully: $($version_cmd)"
        fi
    fi
    return 0
}

# Function to clone or update repository
setup_repository() {
    if [ -d ~/ytmdl ] && [ "$(ls -A ~/ytmdl)" ]; then
        print_message "The ~/ytmdl directory already exists and is not empty."
        read -p "Do you want to update it (u), overwrite it (o), or skip (s)? [u/o/s]: " repo_action
        
        case "$repo_action" in
            u|U)
                print_message "Updating repository..."
                cd ~/ytmdl
                git pull
                ;;
            o|O)
                print_message "Creating fresh ytmdl directory..."
                rm -rf ~/ytmdl
                mkdir -p ~/ytmdl
                cd ~/ytmdl
                print_message "Cloning ytmdl repository..."
                git clone https://github.com/KaedeYure/ytmdl.git .
                ;;
            *)
                print_message "Skipping repository setup."
                cd ~/ytmdl
                ;;
        esac
    else
        print_message "Creating ytmdl directory..."
        mkdir -p ~/ytmdl
        cd ~/ytmdl
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

# Main setup process
main() {
    # Welcome message
    echo -e "\n${GREEN}====== Termux YTMDL Setup ======${RESET}\n"
    print_message "This script will set up your Termux environment for YTMDL."
    
    # Initial setup - storage access
    print_message "Setting up Termux storage access..."
    termux-setup-storage
    
    apt update -y && apt upgrade -y
    
    # Install essential packages
    print_message "Installing essential packages..."
    apt install -y coreutils nano wget curl proot
    
    # Install required packages using our function
    install_package "git" "git" "git --version" || exit 1
    install_package "nodejs" "node" "node --version" || exit 1
    install_package "npm" "npm" "npm --version" || exit 1
    install_package "python3" "python3" "python3 --version" || exit 1
    install_package "ffmpeg" "ffmpeg" "ffmpeg -version | head -n 1" || exit 1
    
    # Repository setup
    setup_repository || exit 1
    
    # Install dependencies if package.json exists
    if [ -f "package.json" ]; then
        print_message "Installing Node.js dependencies..."
        npm run setup
        
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
    echo "- ffmpeg installed: $(ffmpeg -version | head -n 1)"
    echo "- Repository location: $HOME/ytmdl"
    echo ""
    echo -e "${BLUE}Next steps:${RESET}"
    echo "Run the app using ytmdl"
}

# Run the main function
main