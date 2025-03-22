@echo off
setlocal enabledelayedexpansion

:: Set colors for console output
set "BLUE=[94m"
set "GREEN=[92m"
set "RED=[91m"
set "WHITE=[97m"
set "RESET=[0m"

:: Print colorful messages
:print_message
echo %BLUE%==^>%RESET% %WHITE%%~1%RESET%
goto :eof

:print_success
echo %GREEN%==^>%RESET% %WHITE%%~1%RESET%
goto :eof

:print_error
echo %RED%==^>%RESET% %WHITE%%~1%RESET%
goto :eof

:: Main installation function
:main
cls
echo ========================================
echo     YouTube Music Downloader Setup
echo     Windows Installation Script
echo ========================================
echo.

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "This script should be run as administrator."
    echo Right-click the script and select 'Run as administrator'.
    pause
    exit /b 1
)

:: Create temporary directory for downloads
if not exist "%TEMP%\ytmdl_setup" mkdir "%TEMP%\ytmdl_setup"

:: Check if Node.js is installed
call :print_message "Checking for Node.js..."
node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_message "Node.js not found. Installing Node.js..."
    call :install_nodejs
) else (
    call :print_success "Node.js is already installed: "
    node --version
)

:: Check if Git is installed
call :print_message "Checking for Git..."
git --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_message "Git not found. Installing Git..."
    call :install_git
) else (
    call :print_success "Git is already installed: "
    git --version
)

:: Check if Python is installed
call :print_message "Checking for Python..."
python --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_message "Python not found. Installing Python..."
    call :install_python
) else (
    call :print_success "Python is already installed: "
    python --version
)

:: Check if FFmpeg is installed
call :print_message "Checking for FFmpeg..."
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_message "FFmpeg not found. Installing FFmpeg..."
    call :install_ffmpeg
) else (
    call :print_success "FFmpeg is already installed."
)

:: Create ytmdl directory and clone repository
call :print_message "Setting up ytmdl..."
if exist "%USERPROFILE%\ytmdl" (
    call :print_message "The ytmdl directory already exists."
    set /p overwrite="Do you want to overwrite it? (y/n): "
    if /i "!overwrite!" neq "y" (
        call :print_message "Skipping repository clone."
    ) else (
        rmdir /s /q "%USERPROFILE%\ytmdl"
        call :clone_repository
    )
) else (
    call :clone_repository
)

:: Create startup shortcut
call :create_shortcut

:: Print summary
echo.
call :print_success "Setup completed successfully!"
echo.
echo Summary:
echo - Node.js installed
echo - Git installed
echo - Python installed
echo - FFmpeg installed
echo - Repository cloned to: %USERPROFILE%\ytmdl
echo - Shortcut created on desktop
echo.
echo You can start ytmdl by double-clicking the desktop shortcut
echo or running the ytmdl.bat file in %USERPROFILE%\ytmdl
echo.
pause
exit /b 0

:: Function to install Node.js
:install_nodejs
call :print_message "Downloading Node.js installer..."
powershell -Command "& {Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.12.1/node-v20.12.1-x64.msi' -OutFile '%TEMP%\ytmdl_setup\node_installer.msi'}"
if %errorlevel% neq 0 (
    call :print_error "Failed to download Node.js installer."
    exit /b 1
)

call :print_message "Installing Node.js..."
start /wait msiexec /i "%TEMP%\ytmdl_setup\node_installer.msi" /qn
if %errorlevel% neq 0 (
    call :print_error "Failed to install Node.js."
    exit /b 1
)

:: Refresh environment variables
call :refresh_env

:: Verify installation
node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "Node.js installation failed or PATH was not updated."
    call :print_message "Please restart your computer and try again."
    exit /b 1
) else (
    call :print_success "Node.js installed successfully: "
    node --version
)
goto :eof

:: Function to install Git
:install_git
call :print_message "Downloading Git installer..."
powershell -Command "& {Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile '%TEMP%\ytmdl_setup\git_installer.exe'}"
if %errorlevel% neq 0 (
    call :print_error "Failed to download Git installer."
    exit /b 1
)

call :print_message "Installing Git..."
start /wait "" "%TEMP%\ytmdl_setup\git_installer.exe" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
if %errorlevel% neq 0 (
    call :print_error "Failed to install Git."
    exit /b 1
)

:: Refresh environment variables
call :refresh_env

:: Verify installation
git --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "Git installation failed or PATH was not updated."
    call :print_message "Please restart your computer and try again."
    exit /b 1
) else (
    call :print_success "Git installed successfully: "
    git --version
)
goto :eof

:: Function to install Python
:install_python
call :print_message "Downloading Python installer..."
powershell -Command "& {Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe' -OutFile '%TEMP%\ytmdl_setup\python_installer.exe'}"
if %errorlevel% neq 0 (
    call :print_error "Failed to download Python installer."
    exit /b 1
)

call :print_message "Installing Python..."
start /wait "" "%TEMP%\ytmdl_setup\python_installer.exe" /quiet InstallAllUsers=1 PrependPath=1
if %errorlevel% neq 0 (
    call :print_error "Failed to install Python."
    exit /b 1
)

:: Refresh environment variables
call :refresh_env

:: Verify installation
python --version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "Python installation failed or PATH was not updated."
    call :print_message "Please restart your computer and try again."
    exit /b 1
) else (
    call :print_success "Python installed successfully: "
    python --version
)
goto :eof

:: Function to install FFmpeg
:install_ffmpeg
call :print_message "Downloading FFmpeg..."
powershell -Command "& {Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '%TEMP%\ytmdl_setup\ffmpeg.zip'}"
if %errorlevel% neq 0 (
    call :print_error "Failed to download FFmpeg."
    exit /b 1
)

call :print_message "Extracting FFmpeg..."
powershell -Command "& {Expand-Archive -Path '%TEMP%\ytmdl_setup\ffmpeg.zip' -DestinationPath '%TEMP%\ytmdl_setup\ffmpeg' -Force}"
if %errorlevel% neq 0 (
    call :print_error "Failed to extract FFmpeg."
    exit /b 1
)

:: Create FFmpeg directory and move files
if not exist "%ProgramFiles%\FFmpeg" mkdir "%ProgramFiles%\FFmpeg"
xcopy /E /Y "%TEMP%\ytmdl_setup\ffmpeg\ffmpeg-master-latest-win64-gpl\bin\*" "%ProgramFiles%\FFmpeg\"

:: Add FFmpeg to PATH
call :print_message "Adding FFmpeg to PATH..."
setx PATH "%PATH%;%ProgramFiles%\FFmpeg" /M

:: Refresh environment variables
call :refresh_env

:: Verify installation
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "FFmpeg installation failed or PATH was not updated."
    call :print_message "Please restart your computer and try again."
    exit /b 1
) else (
    call :print_success "FFmpeg installed successfully."
)
goto :eof

:: Function to clone repository
:clone_repository
call :print_message "Creating ytmdl directory in user profile..."
mkdir "%USERPROFILE%\ytmdl"
cd /d "%USERPROFILE%\ytmdl"

call :print_message "Cloning ytmdl repository..."
git clone https://github.com/KaedeYure/ytmdl.git .
if %errorlevel% neq 0 (
    call :print_error "Failed to clone the repository."
    exit /b 1
) else (
    call :print_success "Repository cloned successfully."
)

:: Install dependencies
if exist "package.json" (
    call :print_message "Installing Node.js dependencies..."
    call npm install
    if %errorlevel% neq 0 (
        call :print_error "Failed to install dependencies."
        exit /b 1
    ) else (
        call :print_success "Dependencies installed successfully."
    )
) else (
    call :print_message "No package.json found, skipping dependency installation."
)

:: Create batch file
call :print_message "Creating startup script..."
echo @echo off > ytmdl.bat
echo cd /d "%%~dp0" >> ytmdl.bat
echo if "%%1"=="" ( >> ytmdl.bat
echo   npm start >> ytmdl.bat
echo ) else ( >> ytmdl.bat
echo   npm run %%* >> ytmdl.bat
echo ) >> ytmdl.bat

call :print_success "Startup script created."
goto :eof

:: Function to create desktop shortcut
:create_shortcut
call :print_message "Creating desktop shortcut..."
powershell -Command "& {$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut([System.IO.Path]::Combine($env:USERPROFILE, 'Desktop', 'YouTube Music Downloader.lnk')); $Shortcut.TargetPath = [System.IO.Path]::Combine($env:USERPROFILE, 'ytmdl', 'ytmdl.bat'); $Shortcut.WorkingDirectory = [System.IO.Path]::Combine($env:USERPROFILE, 'ytmdl'); $Shortcut.Description = 'YouTube Music Downloader'; $Shortcut.Save()}"
if %errorlevel% neq 0 (
    call :print_error "Failed to create desktop shortcut."
) else (
    call :print_success "Desktop shortcut created."
)
goto :eof

:: Function to refresh environment variables
:refresh_env
call :print_message "Refreshing environment variables..."
for /f "tokens=2*" %%a in ('reg query HKLM\SYSTEM\CurrentControlSet\Control\Session" "Manager\Environment /v Path') do set syspath=%%b
for /f "tokens=2*" %%a in ('reg query HKCU\Environment /v Path') do set userpath=%%b
set PATH=%syspath%;%userpath%
goto :eof

:: Start the installation
call :main