#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');
const https = require('https');
const { createWriteStream, existsSync, mkdirSync } = require('fs');
const { promisify } = require('util');
const readline = require('readline');
const { update } = require('./updater');

const execAsync = promisify(exec);

// Platform-specific yt-dlp download URLs
const YTDLP_RELEASES = {
  win32: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
  linux: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
  darwin: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos',
  android: 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp'
};

// Required npm packages
const NPM_PACKAGES = [
  'express', 'cors', 'node-id3', 'multer', 'uuid', 
  '@distube/ytpl', 'socket.io', 'archiver', 'sharp',
  'open', 'chalk'
];

const FFMPEG_STATIC_PACKAGE = 'ffmpeg-static';

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
const installNpmPackages = async () => {
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
    
    console.log('Successfully installed npm packages');
    return true;
  } catch (error) {
    console.error('Failed to install npm packages:', error.message);
    throw error;
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
    
    // Detect platform
    const platform = os.platform() === 'linux' && process.env.TERMUX_VERSION 
      ? 'android' 
      : os.platform();
    
    console.log(`Detected platform: ${platform}`);
    
    // Install npm packages
    await installNpmPackages();
    
    // Check and install yt-dlp if needed
    const ytdlpExists = await checkCommand(platform === 'win32' ? 'yt-dlp.exe' : 'yt-dlp');
    
    if (ytdlpExists) {
      console.log('yt-dlp is already installed and available in PATH');
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
    const ffmpegExists = await checkCommand(platform === 'win32' ? 'ffmpeg.exe' : 'ffmpeg');
    
    if (ffmpegExists) {
      console.log('ffmpeg is already installed and available in PATH');
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
    
    // Create platform-specific command shortcut
    if (platform === 'win32') {
      // Windows batch file
      const batchPath = path.join(__dirname, 'ytmdl.bat');
      const batchContent = `@echo off
cd /d "%~dp0"
if "%1"=="" (
  npm start
) else (
  npm run %*
)`;
      fs.writeFileSync(batchPath, batchContent);
      console.log(`Created command shortcut: ${batchPath}`);
    } else {
      // Unix shell script
      const shellPath = path.join(__dirname, 'ytmdl');
      const shellContent = `#!/bin/bash
cd "$(dirname "$0")"
if [ -z "$1" ]; then
  npm start
else
  npm run "$@"
fi`;
      fs.writeFileSync(shellPath, shellContent);
      await makeExecutable(shellPath);
      console.log(`Created command shortcut: ${shellPath}`);
    }
    
    console.log('\nInstallation completed successfully!');
    console.log(`You can now run the application with: ${platform === 'win32' ? 'ytmdl.bat' : './ytmdl'}`);
    
  } catch (error) {
    console.error('Installation failed:', error);
    process.exit(1);
  }
};

// Run the installer
install();
update();