#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { exec, spawn } = require('child_process');
const os = require('os');
const readline = require('readline');

const HOME_DIR = os.homedir();
const INSTALL_DIR = path.join(HOME_DIR, 'ytmdl');
const PLATFORM = os.platform();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function execCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(stdout);
    });
  });
}

function removeDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) return;
  
  try {
    fs.readdirSync(dirPath).forEach((file) => {
      const curPath = path.join(dirPath, file);
      fs.lstatSync(curPath).isDirectory() 
        ? removeDirectory(curPath) 
        : fs.unlinkSync(curPath);
    });
    fs.rmdirSync(dirPath);
  } catch (err) {
    console.error(`Error removing directory ${dirPath}: ${err.message}`);
  }
}

async function removeSymlinks() {
  try {
    if (PLATFORM === 'win32') {
      const { stdout: currentPath } = await execCommand('reg query HKCU\\Environment /v PATH');
      const match = currentPath.match(/REG_[^\s]+\s+([^\r\n]+)/);
      
      if (match && match[1]) {
        const paths = match[1].split(';').filter(p => !p.includes('\\ytmdl'));
        const newPath = paths.join(';');
        await execCommand(`reg add HKCU\\Environment /v PATH /t REG_EXPAND_SZ /d "${newPath}" /f`);
      }
      
      const batchPath = path.join(INSTALL_DIR, 'ytmdl.bat');
      if (fs.existsSync(batchPath)) fs.unlinkSync(batchPath);
      
    } else if (PLATFORM === 'darwin' || PLATFORM === 'linux') {
      const binPath = path.join(HOME_DIR, '.local', 'bin', 'ytmdl');
      if (fs.existsSync(binPath)) fs.unlinkSync(binPath);
      
      const configFiles = [
        path.join(HOME_DIR, '.bashrc'),
        path.join(HOME_DIR, '.bash_profile'),
        path.join(HOME_DIR, '.zshrc'),
        path.join(HOME_DIR, '.profile')
      ];
      
      for (const configFile of configFiles) {
        if (fs.existsSync(configFile)) {
          let content = fs.readFileSync(configFile, 'utf8');
          const newContent = content.replace(/export PATH=.*\.local\/bin.*\n/g, '');
          
          if (content !== newContent) {
            fs.writeFileSync(configFile, newContent, 'utf8');
          }
        }
      }
      
    } else if (PLATFORM.includes('android')) {
      const termuxBinPath = path.join('/data/data/com.termux/files/usr/bin', 'ytmdl');
      if (fs.existsSync(termuxBinPath)) fs.unlinkSync(termuxBinPath);
    }
  } catch (error) {
    console.error('Error removing symlinks:', error.message);
  }
}

async function selfDelete() {
  const selfPath = process.argv[1];
  
  if (PLATFORM === 'win32') {
    const tempBat = path.join(os.tmpdir(), `cleanup_ytmdl_${Date.now()}.bat`);
    const batContent = `
@echo off
timeout /t 1 /nobreak > nul
del "${selfPath.replace(/\//g, '\\')}"
del "%~f0"
    `;
    
    fs.writeFileSync(tempBat, batContent);
    spawn('cmd.exe', ['/c', tempBat], { detached: true, stdio: 'ignore' }).unref();
  } else {
    const tempSh = path.join(os.tmpdir(), `cleanup_ytmdl_${Date.now()}.sh`);
    const shContent = `
#!/bin/bash
sleep 1
rm "${selfPath}"
rm "$0"
    `;
    
    fs.writeFileSync(tempSh, shContent);
    fs.chmodSync(tempSh, 0o755);
    spawn('/bin/bash', [tempSh], { detached: true, stdio: 'ignore' }).unref();
  }
}

async function uninstall() {
  console.log('=== YouTube Music Downloader (ytmdl) Uninstaller ===\n');
  
  rl.question('Are you sure you want to uninstall ytmdl? (y/n) ', async (answer) => {
    if (answer.toLowerCase() !== 'y') {
      console.log('Uninstallation cancelled.');
      rl.close();
      return;
    }
    
    console.log('\nStarting uninstallation process...');
    
    try {
      console.log('Removing symlinks and PATH entries...');
      await removeSymlinks();
      
      console.log(`Removing installation directory: ${INSTALL_DIR}`);
      removeDirectory(INSTALL_DIR);
      
      console.log('\nUninstallation completed successfully!');
      console.log('Cleaning up...');
      
      await selfDelete();
      rl.close();
      
      setTimeout(() => process.exit(0), 200);
    } catch (error) {
      console.error('Error during uninstallation:', error.message);
      rl.close();
    }
  });
}

uninstall();