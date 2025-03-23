#!/data/data/com.termux/files/usr/bin/bash
# Simple Termux setup script for ytmdl

# Check if running in Termux
if [ ! -d "/data/data/com.termux/files/usr" ]; then
    echo "This script must be run in Termux!"
    exit 1
fi

# Setup storage access
termux-setup-storage

# Update packages
apt update
apt upgrade -y

# Install essential packages
apt install -y coreutils nano wget curl proot git nodejs npm python python-pip ffmpeg

# Setup repository
if [ -d ~/ytmdl ]; then
    rm -rf ~/ytmdl
fi

mkdir -p ~/ytmdl
cd ~/ytmdl

# Clone repository
git clone https://github.com/KaedeYure/ytmdl.git .

# Install dependencies if package.json exists
if [ -f "package.json" ]; then
    npm install
    npm install --cpu=wasm32 sharp
fi

# Print summary
echo ""
echo "Setup completed!"
echo ""
echo "Summary:"
echo "- Termux storage access setup"
echo "- Git: $(git --version)"
echo "- Node.js: $(node --version)"
echo "- npm: $(npm --version)"
echo "- Python 3: $(python3 --version)"
echo "- pip3: $(pip3 --version)"
echo "- ffmpeg: $(ffmpeg -version | head -n 1)"
echo "- Repository location: $HOME/ytmdl"
echo ""
echo "Next steps:"
echo "1. Navigate to the ytmdl directory: cd ~/ytmdl"
echo "2. Run the application: node index.js"