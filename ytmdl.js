#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

// Get the YTMDL installation directory
const ytmdlDir = path.resolve('D:\\Project\\YTMDL');
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
