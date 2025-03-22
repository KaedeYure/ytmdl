@echo off
echo Starting YouTube Music Downloader setup...

:: Check if winget is available
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo Winget is not available on this system.
    echo Please install the App Installer from the Microsoft Store.
    echo Or update to Windows 10 1809 or later.
    pause
    exit /b 1
)

:: Check for Node.js
echo Checking for Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Node.js...
    winget install -e --id OpenJS.NodeJS
    
    :: Refresh environment variables
    echo Refreshing environment variables...
    call refreshenv.cmd
    if %errorlevel% neq 0 (
        echo Refreshing environment variables failed. Please restart your terminal after installation.
    )
) else (
    echo Node.js is already installed.
    node --version
)

:: Check for Git
echo Checking for Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Git...
    winget install -e --id Git.Git
    
    :: Refresh environment variables
    echo Refreshing environment variables...
    call refreshenv.cmd
    if %errorlevel% neq 0 (
        echo Refreshing environment variables failed. Please restart your terminal after installation.
    )
) else (
    echo Git is already installed.
    git --version
)

:: Check for Python
echo Checking for Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Python...
    winget install -e --id Python.Python.3.11
    
    :: Refresh environment variables
    echo Refreshing environment variables...
    call refreshenv.cmd
    if %errorlevel% neq 0 (
        echo Refreshing environment variables failed. Please restart your terminal after installation.
    )
) else (
    echo Python is already installed.
    python --version
)

:: Check for FFmpeg
echo Checking for FFmpeg...
where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing FFmpeg...
    winget install -e --id Gyan.FFmpeg
    
    :: Refresh environment variables
    echo Refreshing environment variables...
    call refreshenv.cmd
    if %errorlevel% neq 0 (
        echo Refreshing environment variables failed. Please restart your terminal after installation.
    )
) else (
    echo FFmpeg is already installed.
)

:: Create ytmdl directory and clone repository
echo Setting up ytmdl...
if exist "%USERPROFILE%\ytmdl" (
    echo The ytmdl directory already exists.
    set /p overwrite="Do you want to overwrite it? (y/n): "
    if /i "%overwrite%" neq "y" (
        echo Skipping repository clone.
        goto create_shortcut
    )
    echo Removing existing directory...
    rmdir /s /q "%USERPROFILE%\ytmdl"
)

echo Creating ytmdl directory in your home folder...
mkdir "%USERPROFILE%\ytmdl"
cd /d "%USERPROFILE%\ytmdl"

echo Cloning ytmdl repository...
git clone https://github.com/KaedeYure/ytmdl.git .

if %errorlevel% neq 0 (
    echo Failed to clone the repository.
    exit /b 1
) else (
    echo Repository cloned successfully.
)

:: Install dependencies
if exist "package.json" (
    echo Installing Node.js dependencies...
    call npm install
    
    if %errorlevel% neq 0 (
        echo Failed to install dependencies.
        exit /b 1
    ) else (
        echo Dependencies installed successfully.
    )
) else (
    echo No package.json found, skipping dependency installation.
)

:: Create batch file
echo Creating startup script...
echo @echo off > ytmdl.bat
echo cd /d "%%~dp0" >> ytmdl.bat
echo if "%%1"=="" ( >> ytmdl.bat
echo   npm start >> ytmdl.bat
echo ) else ( >> ytmdl.bat
echo   npm run %%* >> ytmdl.bat
echo ) >> ytmdl.bat

echo Startup script created.

:create_shortcut
:: Create desktop shortcut without requiring admin rights
echo Creating desktop shortcut...
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\CreateShortcut.vbs"
echo sLinkFile = oWS.SpecialFolders("Desktop") ^& "\YouTube Music Downloader.lnk" >> "%TEMP%\CreateShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\CreateShortcut.vbs"
echo oLink.TargetPath = "%USERPROFILE%\ytmdl\ytmdl.bat" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.WorkingDirectory = "%USERPROFILE%\ytmdl" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.Description = "YouTube Music Downloader" >> "%TEMP%\CreateShortcut.vbs"
echo oLink.Save >> "%TEMP%\CreateShortcut.vbs"
cscript /nologo "%TEMP%\CreateShortcut.vbs"
del "%TEMP%\CreateShortcut.vbs"

echo.
echo Setup completed successfully!
echo.
echo Summary:
echo - Repository location: %USERPROFILE%\ytmdl
echo.
echo You can start ytmdl by:
echo - Double-clicking the desktop shortcut
echo - Running the ytmdl.bat file in %USERPROFILE%\ytmdl
echo.
pause