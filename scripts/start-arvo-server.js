#!/usr/bin/env node

/**
 * Start Arvo OS Server
 *
 * This script starts the Arvo OS server and waits for it to be ready
 * before returning control to the caller.
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const chalk = require('chalk');
const ora = require('ora');

// Configuration
const JULIA_SERVER_PATH = path.join(__dirname, '..', 'julia', 'server', 'julia_server.jl');
const JULIA_SERVER_PORT = process.env.JULIA_SERVER_PORT || 8052;
const JULIA_SERVER_HOST = process.env.JULIA_SERVER_HOST || 'localhost';
const HEALTH_CHECK_URL = process.env.JULIA_SERVER_URL || `http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}/health`;
const MAX_STARTUP_TIME = 60000; // 60 seconds
const HEALTH_CHECK_INTERVAL = 1000; // 1 second

function findJuliaExecutable() {
  const platform = process.platform;
  const possiblePaths = [];

  if (platform === 'win32') {
    possiblePaths.push(
      'C:\\Program Files\\Julia\\bin\\julia.exe',
      'C:\\Program Files (x86)\\Julia\\bin\\julia.exe'
    );
  } else if (platform === 'darwin') {
    possiblePaths.push(
      '/Applications/Julia-1.9.app/Contents/Resources/julia/bin/julia',
      '/usr/local/bin/julia',
      '/opt/homebrew/bin/julia'
    );
  } else {
    possiblePaths.push(
      '/usr/bin/julia',
      '/usr/local/bin/julia'
    );
  }

  try {
    const { execSync } = require('child_process');
    const juliaPath = execSync('which julia', { encoding: 'utf8' }).trim();
    if (juliaPath) {
      return juliaPath;
    }
  } catch (error) {}

  for (const juliaPath of possiblePaths) {
    if (fs.existsSync(juliaPath)) {
      return juliaPath;
    }
  }

  return 'julia';
}

async function checkServerHealth() {
  try {
    console.log(`Checking Arvo OS server health at ${HEALTH_CHECK_URL}...`);
    const response = await fetch(HEALTH_CHECK_URL, { timeout: 5000 });
    if (response.ok) {
      const data = await response.json();
      const isHealthy = data.status === 'healthy';
      console.log(`Arvo OS server health check: ${isHealthy ? 'healthy' : 'unhealthy'}`);
      return isHealthy;
    }
    console.log('Arvo OS server health check failed: server responded with an error');
    return false;
  } catch (error) {
    console.log(`Arvo OS server health check failed: ${error.message}`);
    return false;
  }
}

async function startJuliaServer() {
  const spinner = ora('Starting Arvo OS server...').start();

  const serverRunning = await checkServerHealth();
  if (serverRunning) {
    spinner.succeed('Arvo OS server is already running');
    return true;
  }

  const juliaPath = findJuliaExecutable();
  spinner.text = `Starting Arvo OS server using ${juliaPath}...`;

  if (!fs.existsSync(JULIA_SERVER_PATH)) {
    spinner.fail(`Server script not found at ${JULIA_SERVER_PATH}`);
    return false;
  }

  const juliaDir = path.dirname(JULIA_SERVER_PATH);
  if (!fs.existsSync(juliaDir)) {
    spinner.fail(`Julia directory not found at ${juliaDir}`);
    return false;
  }

  const projectFile = path.join(juliaDir, 'Project.toml');
  if (!fs.exists(projectFile)) {
    spinner.warn(`Project.toml not found at ${projectFile}. Server may not start correctly.`);
  }

  let serverProcess;
  try {
    const env = { ...process.env };
    env.JULIA_PROJECT = juliaDir;
    env.JULIA_LOAD_PATH = `${juliaDir}:${env.JULIA_LOAD_PATH || ''}`;

    serverProcess = spawn(juliaPath, [JULIA_SERVER_PATH], {
      cwd: juliaDir,
      stdio: 'pipe',
      env: env
    });
  } catch (spawnError) {
    spinner.fail(`Failed to start Arvo OS server: ${spawnError.message}`);
    return false;
  }

  let serverOutput = '';
  serverProcess.stdout.on('data', (data) => {
    const output = data.toString();
    serverOutput += output;
    spinner.text = `Server output: ${output.trim()}`;
  });

  let serverErrors = '';
  serverProcess.stderr.on('data', (data) => {
    const error = data.toString();
    serverErrors += error;
    spinner.text = `Server error: ${error.trim()}`;
  });

  serverProcess.on('error', (error) => {
    spinner.fail(`Server process error: ${error.message}`);
  });

  const startTime = Date.now();
  let lastCheckTime = 0;
  let checkCount = 0;
  const maxChecks = 30;

  while (Date.now() - startTime < MAX_STARTUP_TIME) {
    if (Date.now() - lastCheckTime >= HEALTH_CHECK_INTERVAL) {
      lastCheckTime = Date.now();
      checkCount++;

      spinner.text = `Checking server health (attempt ${checkCount}/${maxChecks})...`;
      const healthy = await checkServerHealth();

      if (healthy) {
        spinner.succeed('Arvo OS server is running and healthy');
        return true;
      }

      if (checkCount >= maxChecks / 2 && checkCount < maxChecks) {
        spinner.warn('Server not responding yet. Still waiting...');
      } else if (checkCount >= maxChecks) {
        spinner.fail('Maximum health check attempts reached');
        break;
      }
    }

    if (serverProcess.exitCode !== null) {
      spinner.fail(`Server process exited with code ${serverProcess.exitCode}`);
      console.log('Server output:', serverOutput);
      console.log('Server errors:', serverErrors);
      return false;
    }

    await new Promise(resolve => setTimeout(resolve, 100));
  }

  spinner.fail('Timeout waiting for Arvo OS server to be ready');
  console.log('Server output:', serverOutput);
  console.log('Server errors:', serverErrors);

  try {
    if (serverProcess.exitCode === null) {
      serverProcess.kill();
      spinner.text = 'Killed server process due to timeout';
    }
  } catch (error) {
    spinner.text = `Error killing server process: ${error.message}`;
  }

  return false;
}

if (require.main === module) {
  startJuliaServer()
    .then(success => {
      if (!success) {
        console.error(chalk.red('Failed to start Arvo OS server'));
        process.exit(1);
      }
    })
    .catch(error => {
      console.error(chalk.red(`Error starting Arvo OS server: ${error.message}`));
      process.exit(1);
    });
}

module.exports = { startJuliaServer, checkServerHealth };
