#!/usr/bin/env node

const { spawn, execSync } = require('child_process');
const os = require('os');
const fs = require('fs');

// Detect platform
const platform = os.platform();
const isTermux = fs.existsSync('/data/data/com.termux/files/usr');

console.log(`Detected platform: ${platform} (Termux: ${isTermux})`);

// Run appropriate installer based on platform
try {
  if (platform === 'win32') {
    console.log('Running Windows installer...');
    execSync(
      'powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; iwr -useb https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/win.ps1 | iex"',
      { stdio: 'inherit' }
    );
  } else if (isTermux) {
    console.log('Running Termux installer...');
    // Use execSync instead of spawn for consistency
    execSync('curl -sSL https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/termux.sh | bash', 
      { stdio: 'inherit' });
  } else {
    console.log('Running Linux/macOS installer...');
    execSync('curl -sSL https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/linux.sh | bash', 
      { stdio: 'inherit' });
  }
} catch (error) {
  console.error('Installation failed:', error.message);
  process.exit(1);
}