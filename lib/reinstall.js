#!/usr/bin/env node

const { spawn, execSync } = require('child_process');
const os = require('os');

// Detect platform
const platform = os.platform();
const isTermux = () => {
  try {
    // Check for Termux-specific paths
    return require('fs').existsSync('/data/data/com.termux/files/usr');
  } catch (e) {
    return false;
  }
};

console.log(`Detected platform: ${platform}`);

// Run appropriate installer based on platform
try {
  if (platform === 'win32') {
    console.log('Running Windows installer...');
    execSync(
      'powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; iwr -useb https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/win.ps1 | iex"',
      { stdio: 'inherit' }
    );
  } else if (isTermux()) {
    console.log('Running Termux installer...');
    const child = spawn('bash', ['-c', 'curl -sSL https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/termux.sh | bash'], 
      { stdio: 'inherit', shell: true });
    
    child.on('exit', code => process.exit(code));
  } else {
    console.log('Running Linux/macOS installer...');
    const child = spawn('bash', ['-c', 'curl -sSL https://raw.githubusercontent.com/KaedeYure/ytmdl/main/setup/linux.sh | bash'], 
      { stdio: 'inherit', shell: true });
    
    child.on('exit', code => process.exit(code));
  }
} catch (error) {
  console.error('Installation failed:', error.message);
  process.exit(1);
}