const chalk = require('chalk').default;
const https = require('https');
const fs = require('fs');
const semver = require('semver');
const { promisify } = require('util');
const { exec: execCallback } = require('child_process');

const exec = promisify(execCallback);

const repo = 'KaedeYure/ytmdl';
const repoUrl = `https://github.com/${repo}.git`;
const githubApiOptions = {
    hostname: 'api.github.com',
    port: 443,
    path: `/repos/${repo}/contents/package.json`,
    method: 'GET',
    headers: { 'User-Agent': 'node.js' }
};

async function update(periodic = false) {
    try {
        const localPackage = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        const remotePackage = await fetchRemotePackage();
        
        const versionComparison = semver.compare(localPackage.version, remotePackage.version);
        
        if (versionComparison < 0) {
            console.log(chalk.green(`A new version is available: ${remotePackage.version}`));
            console.log(chalk.blue('Trying to auto update...'));
            
            try {
                await updateFromRemote();
                console.log(chalk.green('Successfully updated to the latest version.'));
                // Exit process after update to allow new version to take effect
                process.exit(0);
            } catch (updateError) {
                console.error(chalk.red(`Update failed: ${updateError.message}`));
            }
        } else if (!periodic) {
            if (versionComparison > 0) {
                console.log(chalk.red(`The version you are using (${localPackage.version}) is either modified or newer than the remote version.`));
                console.log(chalk.yellow('Please use the latest version available on GitHub.'));
            } else {
                console.log(chalk.green('You are using the latest version.'));
            }
        }
        
        if (remotePackage.message) {
            console.log(remotePackage.message);
        }

        return Promise.resolve(); // Explicitly resolve when complete
    } catch (error) {
        console.error(chalk.red(`Error checking for updates: ${error.message}`));
        return Promise.reject(error); // Explicitly reject on error
    }
}

function fetchRemotePackage() {
    return new Promise((resolve, reject) => {
        const req = https.get(githubApiOptions, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                reject(new Error(`Redirected to ${res.headers.location}`));
                return;
            }
            
            if (res.statusCode !== 200) {
                reject(new Error(`API request failed with status code ${res.statusCode}`));
                return;
            }
            
            const chunks = [];
            res.on('data', (chunk) => chunks.push(chunk));
            res.on('end', () => {
                try {
                    const data = Buffer.concat(chunks).toString();
                    const parsedData = JSON.parse(data);
                    const content = JSON.parse(Buffer.from(parsedData.content, 'base64').toString('utf8'));
                    resolve(content);
                } catch (error) {
                    reject(new Error(`Failed to parse remote package.json: ${error.message}`));
                }
            });
        });
        
        req.on('error', (error) => reject(new Error(`Network error: ${error.message}`)));
        req.on('timeout', () => {
            req.destroy();
            reject(new Error('Request timed out'));
        });
        
        req.setTimeout(10000);
    });
}

async function updateFromRemote() {
    await ensureGitInstalled();
    await initializeGitRepo();
    await setRemoteAndPull();
    return Promise.resolve(); // Explicitly resolve when complete
}

async function ensureGitInstalled() {
    try {
        await exec('git --version');
    } catch (error) {
        throw new Error('Git is not installed or not in the PATH. Please install Git to enable automatic updates.');
    }
}

async function initializeGitRepo() {
    try {
        await exec('git rev-parse --is-inside-work-tree');
    } catch (error) {
        console.log(chalk.blue('Initializing git repository...'));
        try {
            await exec('git init');
            console.log(chalk.green('Git repository initialized.'));
        } catch (initError) {
            throw new Error(`Failed to initialize git repository: ${initError.message}`);
        }
    }
}

async function setRemoteAndPull() {
    try {
        const { stdout } = await exec('git remote');
        
        const hasOrigin = stdout.includes('origin');
        const remoteCommand = hasOrigin
            ? `git remote set-url origin ${repoUrl}`
            : `git remote add origin ${repoUrl}`;
            
        await exec(remoteCommand);
        
        await exec('git fetch origin main && git reset --hard FETCH_HEAD');
        console.log(chalk.green('Successfully pulled the latest updates from the repository.'));
    } catch (error) {
        throw new Error(`Git operation failed: ${error.message}`);
    }
}

const updates = {
    update: update
}

module.exports = updates;