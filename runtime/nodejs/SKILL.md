# Node.js — JavaScript Runtime Environment

> Install Node.js via NVM, manage packages with npm/yarn/pnpm, run production apps with PM2, and configure server-side JavaScript environments.

## Safety Rules

- Never run `npm install` as root — use NVM for user-space Node installs.
- Pin Node versions in `.nvmrc` for project consistency.
- Use `npm ci` (not `npm install`) in CI/CD for reproducible builds.
- Always set `NODE_ENV=production` in production to disable dev features and improve performance.
- Audit dependencies regularly: `npm audit` / `yarn audit`.

## Quick Reference

```bash
# Check versions
node --version
npm --version

# Run a script
node app.js

# Install dependencies
npm install

# Start PM2 managed process
pm2 start app.js --name my-app

# PM2 status
pm2 status

# Tail logs
pm2 logs my-app
```

## Installation via NVM

### Install NVM

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Reload shell
source ~/.bashrc   # or ~/.zshrc

# Verify
nvm --version
```

### Install Node.js versions

```bash
# Install latest LTS
nvm install --lts

# Install specific version
nvm install 22
nvm install 20.11.0

# List installed versions
nvm ls

# List available remote versions
nvm ls-remote --lts | tail -20

# Switch versions
nvm use 22
nvm use 20

# Set default version
nvm alias default 22

# Use version from .nvmrc
echo "22" > .nvmrc
nvm use    # Reads .nvmrc

# Uninstall a version
nvm uninstall 18
```

### System-wide install (alternative — no NVM)

```bash
# NodeSource (Debian/Ubuntu)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# RHEL/Rocky
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs
```

## Package Managers

### npm

```bash
# Initialize a project
npm init -y

# Install dependencies
npm install                         # From package.json
npm install express                 # Add a dependency
npm install -D typescript           # Dev dependency
npm install -g pm2                  # Global install

# Clean install (CI/production)
npm ci

# Update packages
npm update
npm outdated                        # Show outdated packages

# Run scripts (from package.json)
npm run build
npm run start
npm test

# Security audit
npm audit
npm audit fix

# Cache management
npm cache clean --force
npm cache verify

# List global packages
npm list -g --depth=0
```

### yarn (v1 classic)

```bash
# Install yarn
npm install -g yarn

# Install dependencies
yarn install
yarn install --frozen-lockfile      # CI mode

# Add packages
yarn add express
yarn add -D typescript

# Run scripts
yarn build
yarn start

# Upgrade
yarn upgrade-interactive
```

### pnpm

```bash
# Install pnpm
npm install -g pnpm
# Or via corepack
corepack enable && corepack prepare pnpm@latest --activate

# Install dependencies
pnpm install
pnpm install --frozen-lockfile      # CI mode

# Add packages
pnpm add express
pnpm add -D typescript

# Run scripts
pnpm run build
pnpm start

# Disk space savings
pnpm store status
pnpm store prune
```

## PM2 — Production Process Manager

### Installation

```bash
npm install -g pm2
```

### Basic usage

```bash
# Start an application
pm2 start app.js --name my-app
pm2 start npm --name my-app -- start              # npm start
pm2 start "yarn start" --name my-app              # yarn start
pm2 start app.js -i max --name my-app             # Cluster mode (all CPUs)
pm2 start app.js -i 4 --name my-app               # 4 instances

# Manage processes
pm2 status                    # List all processes
pm2 restart my-app
pm2 reload my-app             # Zero-downtime reload (cluster mode)
pm2 stop my-app
pm2 delete my-app

# Logs
pm2 logs                      # All process logs
pm2 logs my-app               # Specific app
pm2 logs my-app --lines 100   # Last 100 lines
pm2 flush                     # Clear all logs

# Monitoring
pm2 monit                     # Terminal dashboard
pm2 show my-app               # Detailed info

# Environment variables
pm2 start app.js --name my-app --env production \
  --node-args="--max-old-space-size=4096"
```

### PM2 ecosystem file (`ecosystem.config.js`)

```javascript
module.exports = {
  apps: [{
    name: 'my-app',
    script: './dist/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 8080
    },
    max_memory_restart: '1G',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    merge_logs: true,
    autorestart: true,
    watch: false,
    max_restarts: 10,
    restart_delay: 5000
  }]
};
```

```bash
# Start with ecosystem file
pm2 start ecosystem.config.js
pm2 start ecosystem.config.js --env production

# Reload with ecosystem
pm2 reload ecosystem.config.js
```

### PM2 startup (persist across reboots)

```bash
# Generate startup script
pm2 startup
# Run the command it outputs (e.g., sudo env PATH=... pm2 startup systemd -u myuser --hp /home/myuser)

# Save current process list
pm2 save

# Resurrect saved processes (automatic after startup)
pm2 resurrect

# Remove startup hook
pm2 unstartup
```

### PM2 log rotation

```bash
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
```

## Environment Setup

### .env files

```bash
# Install dotenv
npm install dotenv

# In app entry point
# require('dotenv').config()

# Or use --require flag
node --require dotenv/config app.js

# With PM2
pm2 start app.js --name my-app --node-args="--require dotenv/config"
```

### NODE_ENV and common variables

```bash
# Set for production
export NODE_ENV=production
export PORT=3000

# Run with inline env
NODE_ENV=production PORT=3000 node app.js

# Cross-platform (use cross-env)
npx cross-env NODE_ENV=production node app.js
```

## Common Patterns

### Systemd service (without PM2)

```ini
# /etc/systemd/system/my-node-app.service
[Unit]
Description=My Node.js App
After=network.target

[Service]
Type=simple
User=nodeapp
WorkingDirectory=/opt/my-app
ExecStart=/home/nodeapp/.nvm/versions/node/v22.21.1/bin/node dist/server.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now my-node-app
sudo journalctl -u my-node-app -f
```

### Health check endpoint

```javascript
// Add to any Express app
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});
```

### Build + deploy pattern

```bash
# Build TypeScript project
npm ci
npm run build

# Start production
NODE_ENV=production pm2 start ecosystem.config.js --env production
pm2 save
```

## Troubleshooting

```bash
# NVM not found after install
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Permission errors with global installs
# Solution: use NVM (don't sudo npm)
nvm use --lts

# EACCES errors
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH

# Port already in use
lsof -i :3000
kill -9 $(lsof -t -i :3000)

# Memory issues
node --max-old-space-size=4096 app.js

# Debug crashes
node --inspect app.js
# Open chrome://inspect in Chrome

# PM2 not starting on boot
pm2 startup
pm2 save

# Clear PM2 state
pm2 kill
pm2 start ecosystem.config.js
```
