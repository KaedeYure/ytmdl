#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');
const https = require('https');
const { createWriteStream, existsSync, mkdirSync, writeFileSync } = require('fs');
const { promisify } = require('util');
const readline = require('readline');

const execAsync = promisify(exec);

// Platform-specific yt-dlp download URLs
const YTDLP_RELEASES = {
  win32: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
  linux: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
  darwin: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos',
  android: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp'
};

// Required npm packages (Sharp will be handled separately for Android)
const NPM_PACKAGES = [
  'express', 'cors', 'node-id3', 'multer', 'uuid', 
  '@distube/ytpl', 'socket.io', 'archiver',
  'open', 'chalk', 'os'
];

const FFMPEG_STATIC_PACKAGE = 'ffmpeg-static';

// Function to detect if running in Termux
const isRunningOnTermux = () => {
  // Check for Termux-specific environment variable
  if (process.env.TERMUX_VERSION) {
    return true;
  }
  
  // Check for Termux-specific path prefix
  if (process.env.PREFIX && process.env.PREFIX.includes('com.termux')) {
    return true;
  }
  
  // Check if we can access a Termux-specific directory
  try {
    // This path exists only on Termux installations
    const stats = fs.statSync('/data/data/com.termux/files/usr');
    return stats.isDirectory();
  } catch (e) {
    // Path doesn't exist, so we're not on Termux
    return false;
  }
};

// Function to download files with progress reporting
const download = async (url, destPath) => {
  console.log(`Downloading from ${url}...`);
  
  try {
    const tempPath = `${destPath}.download`;
    
    const downloadWithRedirects = async (currentUrl, redirectCount = 0) => {
      if (redirectCount > 5) throw new Error('Too many redirects');
      
      return new Promise((resolve, reject) => {
        const urlObj = new URL(currentUrl);
        const httpModule = urlObj.protocol === 'https:' ? https : require('http');
        
        const request = httpModule.get(currentUrl, response => {
          if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
            console.log(`Following redirect to: ${response.headers.location}`);
            resolve(downloadWithRedirects(response.headers.location, redirectCount + 1));
            return;
          }
          
          if (response.statusCode !== 200) {
            reject(new Error(`Failed to download: ${response.statusCode}`));
            return;
          }
          
          const file = createWriteStream(tempPath);
          const totalSize = parseInt(response.headers['content-length'] || '0', 10);
          let downloaded = 0;
          let lastPercentage = 0;
          
          response.on('data', chunk => {
            downloaded += chunk.length;
            if (totalSize > 0) {
              const percentage = Math.floor((downloaded / totalSize) * 100);
              
              if (percentage > lastPercentage) {
                process.stdout.write(`\rDownloading... ${percentage}%`);
                lastPercentage = percentage;
              }
            } else {
              process.stdout.write(`\rDownloading... ${(downloaded / 1024 / 1024).toFixed(2)} MB`);
            }
          });
          
          response.pipe(file);
          
          file.on('finish', () => {
            file.close();
            try {
              if (fs.existsSync(destPath)) fs.unlinkSync(destPath);
              fs.renameSync(tempPath, destPath);
              process.stdout.write('\rDownload complete!                  \n');
              resolve(destPath);
            } catch (fsError) {
              reject(fsError);
            }
          });
          
          file.on('error', err => {
            if (fs.existsSync(tempPath)) {
              try { fs.unlinkSync(tempPath); } catch (e) {}
            }
            reject(err);
          });
        });
        
        request.on('error', err => {
          if (fs.existsSync(tempPath)) {
            try { fs.unlinkSync(tempPath); } catch (e) {}
          }
          reject(err);
        });
        
        request.setTimeout(60000, () => {
          request.destroy();
          reject(new Error('Download timed out after 60 seconds'));
        });
      });
    };
    
    return await downloadWithRedirects(url);
  } catch (error) {
    console.error('Download error:', error.message);
    throw error;
  }
};

// Make file executable (for non-Windows platforms)
const makeExecutable = async (filePath) => {
  if (os.platform() !== 'win32') {
    await execAsync(`chmod +x "${filePath}"`);
    console.log(`Made ${filePath} executable`);
  }
};

// Check if a command is available in the PATH
const checkCommand = async (command) => {
  try {
    await execAsync(`${command} --version`);
    return true;
  } catch (error) {
    return false;
  }
};

// Install required npm packages
const installNpmPackages = async (isTermux) => {
  console.log('Installing npm packages...');
  
  try {
    const cmd = os.platform() === 'win32' 
      ? `npm.cmd install --save ${NPM_PACKAGES.join(' ')}` 
      : `npm install --save ${NPM_PACKAGES.join(' ')}`;
    
    console.log(`Running: ${cmd}`);
    
    const { stdout, stderr } = await execAsync(cmd, {
      maxBuffer: 1024 * 1024 * 10
    });
    
    if (stdout) console.log(stdout);
    if (stderr) console.error(stderr);
    
    // Install Sharp separately with special flags for Termux/Android
    if (isTermux) {
      console.log('Installing proper Sharp for Termux...');
      const os = require('os');
      const arch = os.arch();
      
      let sharpCmd;
      if (arch === 'arm') {
        sharpCmd = 'npm install sharp-linux-arm';
      } else if (arch === 'arm64') {
        sharpCmd = 'npm install sharp-linux-arm64';
      } else {
        sharpCmd = 'npm install sharp'
      }
      console.log(`Running: ${sharpCmd}`);
      
      const { stdout: sharpStdout, stderr: sharpStderr } = await execAsync(sharpCmd, {
        maxBuffer: 1024 * 1024 * 10
      });
      
      if (sharpStdout) console.log(sharpStdout);
      if (sharpStderr) console.error(sharpStderr);
    } else {
      // Install Sharp normally for other platforms
      console.log('Installing Sharp...');
      const sharpCmd = os.platform() === 'win32' 
        ? 'npm.cmd install --save sharp' 
        : 'npm install --save sharp';
      
      console.log(`Running: ${sharpCmd}`);
      
      const { stdout: sharpStdout, stderr: sharpStderr } = await execAsync(sharpCmd, {
        maxBuffer: 1024 * 1024 * 10
      });
      
      if (sharpStdout) console.log(sharpStdout);
      if (sharpStderr) console.error(sharpStderr);
    }
    
    console.log('Successfully installed npm packages');
    return true;
  } catch (error) {
    console.error('Failed to install npm packages:', error.message);
    throw error;
  }
};

// Create a global command for ytmdl
const createGlobalCommand = async (platform) => {
  console.log('Creating global ytmdl command...');
  
  try {
    // Get the current package directory
    const packageDir = path.resolve(__dirname);
    
    // Create the bin script content
    let binScriptContent;
    let binScriptPath;
    let binScriptName;
    
    if (platform === 'win32') {
      // Windows JS file for global command
      binScriptName = 'ytmdl.js';
      binScriptPath = path.join(packageDir, binScriptName);
      binScriptContent = `#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

// Get the YTMDL installation directory
const ytmdlDir = path.resolve('${packageDir.replace(/\\/g, '\\\\')}');
// Change to the YTMDL directory
process.chdir(ytmdlDir);

// Parse arguments
const args = process.argv.slice(2);
const command = args.length > 0 ? args[0] : 'start';
const scriptArgs = args.length > 1 ? args.slice(1) : [];

// Run the appropriate npm script
const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const child = spawn(npmCmd, ['run', command, ...scriptArgs], { 
  stdio: 'inherit',
  shell: true 
});

child.on('exit', (code) => {
  process.exit(code);
});
`;
    } else {
      // Unix shell script for global command
      binScriptName = 'ytmdl';
      binScriptPath = path.join(packageDir, binScriptName);
      binScriptContent = `#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

// Get the YTMDL installation directory
const ytmdlDir = path.resolve('${packageDir}');
// Change to the YTMDL directory
process.chdir(ytmdlDir);

// Parse arguments
const args = process.argv.slice(2);
const command = args.length > 0 ? args[0] : 'start';
const scriptArgs = args.length > 1 ? args.slice(1) : [];

// Run the appropriate npm script
const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const child = spawn(npmCmd, ['run', command, ...scriptArgs], { 
  stdio: 'inherit',
  shell: true 
});

child.on('exit', (code) => {
  process.exit(code);
});
`;
    }
    
    // Write the bin script
    fs.writeFileSync(binScriptPath, binScriptContent);
    if (platform !== 'win32') {
      await makeExecutable(binScriptPath);
    }
    
    // Update package.json to include the bin entry
    const packageJsonPath = path.join(packageDir, 'package.json');
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    
    // Add or update the bin field in package.json
    packageJson.bin = {
      ytmdl: binScriptName
    };
    
    // Write back the updated package.json
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));
    
    // Install the package globally to create the global command
    console.log('Installing ytmdl command globally...');
    
    const installGlobalCmd = platform === 'win32' 
      ? 'npm.cmd install -g .' 
      : 'npm install -g .';
    
    const { stdout, stderr } = await execAsync(installGlobalCmd, {
      cwd: packageDir,
      maxBuffer: 1024 * 1024 * 10
    });
    
    if (stdout) console.log(stdout);
    if (stderr) console.error(stderr);
    
    console.log('Global ytmdl command created successfully!');
    return true;
  } catch (error) {
    console.error('Failed to create global command:', error.message);
    console.log('The application will still work, but you need to use "npm run" commands from the installation directory.');
    return false;
  }
};

// Main installation function
const install = async () => {
  try {
    console.log('Starting YouTube Downloader installation...');
    
    // Create bin directory if it doesn't exist
    const binDir = path.join(__dirname, 'bin');
    if (!existsSync(binDir)) {
      mkdirSync(binDir, { recursive: true });
    }
    
    // Detect platform and check for Termux
    const termuxDetected = isRunningOnTermux();
    const platform = termuxDetected ? 'android' : os.platform();
    
    console.log(`Detected platform: ${platform}${termuxDetected ? ' (Termux)' : ''}`);
    
    // Install npm packages
    await installNpmPackages(termuxDetected);
    
    // Check and install yt-dlp if needed
    let ytdlpExists = false;
    const ytdlpCheck = await checkCommand(platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp');
    if (!ytdlpCheck) {
      const ytdlpPath = path.join(
        binDir,
        platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp'
      );
      if (existsSync(ytdlpPath)) {
        console.log(`yt-dlp found in bin directory: ${ytdlpPath}`);
        ytdlpExists = true;
      } else {
        ytdlpExists = false;
      }
    };
    
    if (ytdlpExists) {
      console.log('yt-dlp is already installed');
    } else {
      console.log('Installing yt-dlp...');
      const ytdlpUrl = YTDLP_RELEASES[platform];
      
      if (!ytdlpUrl) {
        throw new Error(`Unsupported platform: ${platform}`);
      }
      
      const ytdlpPath = path.join(
        binDir, 
        platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp'
      );
      
      await download(ytdlpUrl, ytdlpPath);
      await makeExecutable(ytdlpPath);
      
      console.log(`yt-dlp installed at: ${ytdlpPath}`);
    }
    
    // Check and install ffmpeg if needed
    let ffmpegExists = await checkCommand(platform === 'win32' ? 'ffmpeg.exe' : 'ffmpeg');

    if (!ffmpegExists) {
      try {
        const ffmpegStatic = require('ffmpeg-static');
        if (ffmpegStatic && existsSync(ffmpegStatic)) {
          console.log(`ffmpeg found via ffmpeg-static at: ${ffmpegStatic}`);
          ffmpegExists = true;
        } else if (platform === 'win32') {
          const ffmpegPath = path.join(__dirname, 'node_modules', 'ffmpeg-static', 'ffmpeg.exe');
          if (existsSync(ffmpegPath)) {
            console.log(`ffmpeg found at: ${ffmpegPath}`);
            ffmpegExists = true;
          }
        }
      } catch (error) {
        console.log('ffmpeg-static not found, will attempt installation');
      }
    }
    
    if (ffmpegExists) {
      console.log('ffmpeg is already installed and available in PATH');
    } else if (termuxDetected) {
      console.log("ffmpeg should already be installed. Skipping installation...");
    } else {
      console.log('ffmpeg not found in PATH. Installing ffmpeg-static...');
      
      const ffmpegCmd = os.platform() === 'win32'
        ? `npm.cmd install --save ${FFMPEG_STATIC_PACKAGE}`
        : `npm install --save ${FFMPEG_STATIC_PACKAGE}`;
      
      console.log(`Running: ${ffmpegCmd}`);
      
      try {
        const { stdout, stderr } = await execAsync(ffmpegCmd, {
          maxBuffer: 1024 * 1024 * 10
        });
        
        if (stdout) console.log(stdout);
        if (stderr) console.error(stderr);
        
        console.log('Successfully installed ffmpeg-static');
      } catch (ffmpegError) {
        console.error('Failed to install ffmpeg-static:', ffmpegError.message);
        throw ffmpegError;
      }
    }
    
    // Create global command for ytmdl
    const globalCmdCreated = await createGlobalCommand(platform);
    
    console.log('\nInstallation completed successfully!');
    if (globalCmdCreated) {
      console.log('You can now run the application from anywhere with these commands:');
      console.log('  ytmdl              - Start the application');
      console.log('  ytmdl <script>     - Run a specific script (e.g., ytmdl update)');
    } else {
      console.log('You can run the application from the installation directory with:');
      console.log('  npm start          - Start the application');
      console.log('  npm run <script>   - Run a specific script');
    }
  } catch (error) {
    console.error('Installation failed:', error);
    process.exit(1);
  }
};

// Run the installer
install();