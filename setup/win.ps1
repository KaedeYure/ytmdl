# Windows YTMDL Setup Script (PowerShell)
# Streamlined version that only asks for consent for specific packages

# Function to output colored messages
function Write-ColorMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host "==> " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "==> " -ForegroundColor Green -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Warning {
    param([string]$Message)
    Write-Host "==> " -ForegroundColor Yellow -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Error {
    param([string]$Message)
    Write-Host "==> " -ForegroundColor Red -NoNewline
    Write-Host $Message -ForegroundColor White
}

# Function to check if a command exists
function Test-CommandExists {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to ask user for confirmation
function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "Y"
    )
    
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Proceed with the installation")
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Skip this installation")
    )
    
    $defaultChoiceIndex = if ($DefaultChoice -eq "Y") { 0 } else { 1 }
    
    $result = $host.UI.PromptForChoice("Confirmation", $Message, $choices, $defaultChoiceIndex)
    
    return ($result -eq 0)
}

# Function to check for winget
function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        Write-Error "Windows Package Manager (winget) is not available."
        Write-Host "Please update your Windows or install the App Installer from the Microsoft Store." -ForegroundColor Yellow
        return $false
    }
}

# Function to safely execute version commands and handle output
function Get-CommandVersion {
    param(
        [string]$Command,
        [string]$VersionArg = "--version"
    )
    
    try {
        $versionOutput = & $Command $VersionArg 2>&1
        if ($versionOutput -is [System.Management.Automation.ErrorRecord]) {
            return "Installed (version check failed)"
        }
        
        if ($versionOutput -is [array]) {
            return $versionOutput[0]
        }
        
        return $versionOutput
    } catch {
        return "Installed (version check failed)"
    }
}

# Function to install a package using winget (no prompt for most packages)
function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$CommandName,
        [string]$VersionCommand,
        [string]$VersionArg = "--version",
        [bool]$AskConsent = $false
    )
    
    if (Test-CommandExists $CommandName) {
        $version = Get-CommandVersion -Command $CommandName -VersionArg $VersionArg
        Write-Success "$DisplayName is already installed: $version"
        return $true
    }
    
    # Only ask for confirmation if AskConsent is true
    if ($AskConsent) {
        if (-not (Get-UserConfirmation "Would you like to install $DisplayName?")) {
            Write-Warning "$DisplayName installation skipped."
            return $false
        }
    } else {
        Write-ColorMessage "Installing $DisplayName..." "Yellow"
    }
    
    Write-Host "This will install for the current user only (no admin required)." -ForegroundColor White
    
    try {
        # Try to install for current user first (no admin required)
        $process = Start-Process -FilePath "winget" -ArgumentList "install --id $PackageId --accept-source-agreements --accept-package-agreements --scope user" -Wait -PassThru -NoNewWindow
        
        # Check if winget installation succeeded
        if ($process.ExitCode -ne 0) {
            Write-Warning "Standard installation failed. Some packages may require admin rights."
            
            if (Get-UserConfirmation "Try to install with admin rights?" "N") {
                Write-ColorMessage "Installing $DisplayName with admin rights..." "Yellow"
                Start-Process powershell -ArgumentList "-Command", "winget install --id $PackageId --accept-source-agreements --accept-package-agreements" -Verb RunAs -Wait
            } else {
                Write-Error "Failed to install $DisplayName!"
                return $false
            }
        }
        
        # Refresh PATH to detect newly installed commands
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Check if command is now available
        if (Test-CommandExists $CommandName) {
            $version = Get-CommandVersion -Command $CommandName -VersionArg $VersionArg
            Write-Success "$DisplayName installed successfully: $version"
            return $true
        } else {
            Write-Error "$DisplayName command not found after installation. You may need to restart your terminal."
            return $false
        }
    } catch {
        Write-Error "Error during installation: $_"
        return $false
    }
}

# Function to setup the repository
function SetupRepository {
    $repoPath = Join-Path $env:USERPROFILE "ytmdl"
    
    if (Test-Path $repoPath) {
        if ((Get-ChildItem -Path $repoPath -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
            Write-ColorMessage "The ytmdl directory already exists and is not empty." "Yellow"
            $options = @(
                [System.Management.Automation.Host.ChoiceDescription]::new("&Update", "Update the existing repository")
                [System.Management.Automation.Host.ChoiceDescription]::new("&Overwrite", "Remove and create fresh repository")
                [System.Management.Automation.Host.ChoiceDescription]::new("&Skip", "Skip repository operations")
            )
            
            $choice = $host.UI.PromptForChoice("Repository Action", "What would you like to do with the existing repository?", $options, 0)
            
            switch ($choice) {
                0 { # Update
                    Write-ColorMessage "Updating repository..." "Yellow"
                    try {
                        Push-Location $repoPath
                        git pull
                        Pop-Location
                        Write-Success "Repository updated successfully!"
                    } catch {
                        Write-Error "Failed to update repository: $_"
                        Pop-Location
                        return $false
                    }
                }
                1 { # Overwrite
                    Write-ColorMessage "Creating fresh ytmdl directory..." "Yellow"
                    try {
                        Remove-Item -Path $repoPath -Recurse -Force
                        New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
                        Write-ColorMessage "Cloning ytmdl repository..." "Yellow"
                        git clone https://github.com/KaedeYure/ytmdl.git $repoPath
                        Write-Success "Repository cloned successfully!"
                    } catch {
                        Write-Error "Failed to clone repository: $_"
                        return $false
                    }
                }
                2 { # Skip
                    Write-ColorMessage "Skipping repository setup." "Yellow"
                }
            }
        } else {
            # Directory exists but is empty
            Write-ColorMessage "Cloning ytmdl repository into existing directory..." "Yellow"
            try {
                git clone https://github.com/KaedeYure/ytmdl.git $repoPath
                Write-Success "Repository cloned successfully!"
            } catch {
                Write-Error "Failed to clone repository: $_"
                return $false
            }
        }
    } else {
        Write-ColorMessage "Creating ytmdl directory..." "Yellow"
        try {
            New-Item -Path $repoPath -ItemType Directory -Force | Out-Null
            Write-ColorMessage "Cloning ytmdl repository..." "Yellow"
            git clone https://github.com/KaedeYure/ytmdl.git $repoPath
            Write-Success "Repository cloned successfully!"
        } catch {
            Write-Error "Failed to clone repository: $_"
            return $false
        }
    }
    
    return $true
}

# Function to install npm dependencies
function Install-NpmDependencies {
    $repoPath = Join-Path $env:USERPROFILE "ytmdl"
    $packageJsonPath = Join-Path $repoPath "package.json"
    
    if (Test-Path $packageJsonPath) {
        Write-ColorMessage "Installing Node.js dependencies..." "Yellow"
        try {
            Push-Location $repoPath
            npm install
            
            # Always install sharp for image processing
            Write-ColorMessage "Installing sharp image processing library..." "Yellow"
            npm install sharp
            Write-Success "Sharp installed successfully!"
            
            # Run npm setup script
            Write-ColorMessage "Running setup script..." "Yellow"
            if (Get-Content $packageJsonPath | Select-String -Pattern '"setup"') {
                npm run setup
                Write-Success "Setup script completed successfully!"
            } else {
                Write-Warning "No setup script found in package.json"
            }
            
            Pop-Location
            Write-Success "Dependencies installed successfully!"
            return $true
        } catch {
            Write-Error "Failed to install dependencies or run setup: $_"
            Pop-Location
            return $false
        }
    } else {
        Write-Warning "No package.json found, skipping dependency installation."
    }
    
    return $true
}

# Function to update PATH environment
function Update-PathEnvironment {
    param(
        [string]$PathToAdd,
        [string]$DisplayName
    )
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    if ($null -ne $currentPath -and $currentPath -like "*$PathToAdd*") {
        Write-Success "$DisplayName is already in your PATH."
        return $true
    }
    
    Write-ColorMessage "Adding $DisplayName to your PATH..." "Yellow"
    try {
        $newPath = if ($null -eq $currentPath) { $PathToAdd } else { "$currentPath;$PathToAdd" }
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        $env:PATH = "$env:PATH;$PathToAdd"
        Write-Success "$DisplayName added to your PATH successfully!"
    } catch {
        Write-Error "Failed to update PATH: $_"
        return $false
    }
    
    return $true
}

# Function to check Python installation status and pip
function CheckPythonAndPip {
    $pythonInstalled = Test-CommandExists "python"
    $pipInstalled = Test-CommandExists "pip"
    
    if ($pythonInstalled) {
        $pythonVersion = Get-CommandVersion -Command "python" -VersionArg "--version"
        Write-Success "Python is installed: $pythonVersion"
        
        if ($pipInstalled) {
            $pipVersion = Get-CommandVersion -Command "pip" -VersionArg "--version"
            Write-Success "pip is installed: $pipVersion"
        } else {
            Write-Warning "Python is installed but pip was not found."
            if (Get-UserConfirmation "Would you like to install pip?") {
                try {
                    python -m ensurepip --upgrade
                    Write-Success "pip installed successfully!"
                } catch {
                    Write-Error "Failed to install pip: $_"
                }
            } else {
                Write-Warning "pip installation skipped."
            }
        }
        return $true
    }
    return $false
}

# Main script execution
function Main {
    Clear-Host
    Write-Host "`n====== Windows YTMDL Setup ======`n" -ForegroundColor Green
    Write-ColorMessage "This script will set up your Windows environment for YTMDL."
    Write-Host "You'll only be prompted for Python, pip and ffmpeg installations." -ForegroundColor Yellow
    
    # Check for winget
    if (-not (Test-Winget)) {
        return
    }
    
    # Install Git (no prompt)
    $gitInstalled = Install-WingetPackage "Git.Git" "Git" "git" "git" "--version" $false
    
    # Install Node.js (no prompt)
    $nodeInstalled = Install-WingetPackage "OpenJS.NodeJS.LTS" "Node.js" "node" "node" "--version" $false
    
    # Check if npm is installed after installing Node.js
    if (Test-CommandExists "npm") {
        $npmVersion = Get-CommandVersion -Command "npm" -VersionArg "--version"
        Write-Success "npm is installed: $npmVersion"
    } else {
        Write-Warning "Node.js is installed but npm was not found. This is unusual."
    }
    
    # Install Python 3 (with prompt)
    $pythonInstalled = Install-WingetPackage "Python.Python.3.11" "Python 3" "python" "python" "--version" $true
    
    # Check Python and pip installation
    if ($pythonInstalled) {
        CheckPythonAndPip
    }
    
    # Install ffmpeg (with prompt)
    $ffmpegInstalled = Install-WingetPackage "Gyan.FFmpeg" "ffmpeg" "ffmpeg" "ffmpeg" "-version" $true
    
    # Add executables to PATH if necessary (no prompt)
    if ($ffmpegInstalled -and (Test-CommandExists "ffmpeg")) {
        $ffmpegPath = (Get-Command ffmpeg).Source | Split-Path -Parent
        Update-PathEnvironment $ffmpegPath "ffmpeg directory"
    }
    
    # Repository setup only if Git is installed (no prompt)
    if ($gitInstalled) {
        SetupRepository
    } else {
        Write-Warning "Repository setup skipped because Git is not installed."
    }
    
    # Install npm dependencies only if Node.js is installed (no prompt)
    if ($nodeInstalled) {
        Install-NpmDependencies
    } else {
        Write-Warning "Dependency installation skipped because Node.js is not installed."
    }
    
    # Print summary
    Write-Host "`n" -NoNewline
    Write-Success "Setup process completed!"
    Write-Host "`nSummary:" -ForegroundColor Green
    
    $repoPath = Join-Path $env:USERPROFILE "ytmdl"
    
    # More reliable version detection
    if (Test-CommandExists "git") {
        $gitVersion = Get-CommandVersion -Command "git" -VersionArg "--version"
        Write-Host "- Git: $gitVersion"
    } else {
        Write-Host "- Git: Not installed"
    }
    
    if (Test-CommandExists "node") {
        $nodeVersion = Get-CommandVersion -Command "node" -VersionArg "--version"
        Write-Host "- Node.js: $nodeVersion"
    } else {
        Write-Host "- Node.js: Not installed"
    }
    
    if (Test-CommandExists "npm") {
        $npmVersion = Get-CommandVersion -Command "npm" -VersionArg "--version"
        Write-Host "- npm: $npmVersion"
    } else {
        Write-Host "- npm: Not installed"
    }
    
    if (Test-CommandExists "python") {
        $pythonVersion = Get-CommandVersion -Command "python" -VersionArg "--version"
        Write-Host "- Python: $pythonVersion"
    } else {
        Write-Host "- Python: Not installed"
    }
    
    if (Test-CommandExists "pip") {
        $pipVersion = Get-CommandVersion -Command "pip" -VersionArg "--version"
        Write-Host "- pip: $pipVersion"
    } else {
        Write-Host "- pip: Not installed"
    }
    
    if (Test-CommandExists "ffmpeg") {
        $ffmpegVersion = Get-CommandVersion -Command "ffmpeg" -VersionArg "-version"
        if ($ffmpegVersion -match "ffmpeg version") {
            Write-Host "- ffmpeg: $ffmpegVersion"
        } else {
            Write-Host "- ffmpeg: Installed"
        }
    } else {
        Write-Host "- ffmpeg: Not installed"
    }
    
    Write-Host "- Repository location: $repoPath"
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Navigate to the ytmdl directory: cd $repoPath"
    Write-Host "2. Run the application: node index.js"
    Write-Host "`nNote: If you open a new terminal window, some paths may need to be refreshed." -ForegroundColor Yellow
}

# Run the main function
Main

# Keep the window open if run directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}