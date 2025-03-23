# YTMDL Installation Guide

This repository contains YouTube Music Downloader (YTMDL), a tool for downloading music from YouTube. Below you'll find installation instructions for different operating systems.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation Scripts](#installation-scripts)
  - [Windows Installation](#windows-installation)
  - [Linux Installation](#linux-installation)
  - [Termux Installation (Android)](#termux-installation-android)
- [Manual Installation](#manual-installation)
- [Troubleshooting](#troubleshooting)

## Quick Start

Choose the appropriate installation method for your operating system:

### For Windows users:

```batch
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/win.ps1' -OutFile 'setup-ytmdl.ps1'; & './setup-ytmdl.ps1'"
```

Then right-click on `setup-ytmdl.bat` and select "Run as administrator".

### For Linux users:

```bash
curl -o setup-ytmdl.sh https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/linux.sh
chmod +x setup-ytmdl.sh
sudo ./setup-ytmdl.sh
```

### For Termux users (Android):

```bash
curl -o setup-ytmdl.sh https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/termux.sh
chmod +x setup-ytmdl.sh
./setup-ytmdl.sh
```

## Installation Scripts

This repository includes three installation scripts:

1. `setup/win.bat` - For Windows users
2. `setup/linux.sh` - For Linux users (supports multiple distributions)
3. `setup/termux.sh` - For Termux users on Android

### Windows Installation

The Windows installation script will:

- Check for and install dependencies:
  - Node.js
  - Git
  - Python
  - FFmpeg
- Clone the repository
- Install required Node.js packages
- Create a desktop shortcut

**Requirements:**
- Administrator privileges
- Internet connection

**To install on Windows:**

1. Download the Windows setup script:
   ```batch
   curl -o setup-ytmdl.bat https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/win.bat
   ```

2. Right-click on `setup-ytmdl.bat` and select "Run as administrator".

3. Follow the on-screen instructions.

After installation, you can start YTMDL by:
- Using the desktop shortcut
- Running `ytmdl.bat` in the installation folder

### Linux Installation

The Linux installation script supports multiple distributions (Debian/Ubuntu, Fedora, Arch Linux, openSUSE) by detecting and using the appropriate package manager.

**Requirements:**
- Root privileges (sudo)
- Internet connection

**To install on Linux:**

1. Download the Linux setup script:
   ```bash
   curl -o setup-ytmdl.sh https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/linux.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x setup-ytmdl.sh
   ```

3. Run with sudo:
   ```bash
   sudo ./setup-ytmdl.sh
   ```

4. Follow the on-screen instructions.

After installation, you can run YTMDL by:
- Using the command `ytmdl` in terminal
- Running the executable in the installation folder: `~/ytmdl/ytmdl`
- Using the desktop shortcut in your applications menu

### Termux Installation (Android)

The Termux installation script is specifically designed for running on Android devices with Termux.

**Requirements:**
- Termux app installed
- Internet connection
- Storage permission for Termux (granted during installation)

**To install on Termux:**

1. Download the Termux setup script:
   ```bash
   curl -o setup-ytmdl.sh https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/termux.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x setup-ytmdl.sh
   ```

3. Run the script:
   ```bash
   ./setup-ytmdl.sh
   ```

4. Follow the on-screen instructions.

After installation, you can run YTMDL by navigating to the installation folder and running:
```bash
cd ~/ytmdl
./ytmdl
```

## Manual Installation

If the automatic scripts don't work for you, you can install the dependencies manually.

### Dependencies:

- Node.js (v14+)
- npm
- Git
- Python 3
- FFmpeg
- yt-dlp

### Manual steps:

1. Install the dependencies using your system's package manager
2. Clone the repository:
   ```bash
   git clone https://github.com/KaedeYure/ytmdl.git
   cd ytmdl
   ```
3. Install Node.js dependencies:
   ```bash
   npm install
   ```
   
   For Termux users, install the sharp package with WASM support:
   ```bash
   npm install --cpu=wasm32 sharp
   ```
   
4. Start the application:
   ```bash
   npm start
   ```

## Troubleshooting

### Common issues:

#### "Command not found" errors
Ensure that the installation directories are in your PATH environment variable.

#### Permission issues on Linux/Termux
Make sure you've given executable permissions to the scripts:
```bash
chmod +x setup-ytmdl.sh
chmod +x ~/ytmdl/ytmdl
```

#### Windows installation fails to download dependencies
Try running the command prompt as administrator and run the installation manually:
```batch
cd %USERPROFILE%\ytmdl
npm install
```

#### ffmpeg not working on Termux
If you encounter issues with ffmpeg on Termux, try reinstalling it:
```bash
pkg install -y ffmpeg
```

### Getting help:

If you encounter any issues with the installation, please:

1. Check the [Issues](https://github.com/KaedeYure/ytmdl/issues) page to see if your problem has been reported.
2. Open a new issue if your problem is not already reported.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.