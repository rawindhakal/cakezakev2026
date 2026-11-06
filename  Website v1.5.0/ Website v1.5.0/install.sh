#!/bin/bash

set -e

# Function to display status messages
status_message() {
    echo "==== $1 ===="
}

# Install NVM (only if not already installed)
if [ ! -d "$HOME/.nvm" ]; then
  status_message "Installing NVM"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js
status_message "Installing Node.js"
nvm install 20
nvm use 20

# Verify Node.js installation
node -v

if ! pm2 -v ; then
  # Install PM2 globally
  status_message "Installing PM2"
  npm install -g pm2
fi

# Function to find an available port
find_available_port() {
    for port in $(seq 8003 9001); do
        if ! sudo lsof -i :$port > /dev/null 2>&1; then
            echo $port
            return 0
        fi
    done
    echo "No available ports found between 8003 and 9001" >&2
    return 1
}

# Ensure .env is configured before build (NEXT_PUBLIC_ vars are inlined at build time)
status_message "Checking .env configuration"
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
  fi
  echo "No .env found. Created one from .env.example — fill in NEXT_PUBLIC_API_URL, NEXT_PUBLIC_BASE_URL, NEXT_PUBLIC_MAP_API, NEXT_PUBLIC_FIREBASE_* etc, then re-run this script." >&2
  exit 1
fi

if grep -q "your-firebase-api-key\|your-project-id" public/firebase-messaging-sw.js 2>/dev/null; then
  echo "WARNING: public/firebase-messaging-sw.js still has placeholder Firebase keys — background push notifications will fail until it matches .env." >&2
fi

# Find an available port
status_message "Finding an available port"
PORT=$(find_available_port)
if [ $? -ne 0 ]; then
    exit 1
fi
echo "Found available port: $PORT"

# Update .htaccess file
status_message "Updating .htaccess file"
sed -i "s/http:\/\/127\.0\.0\.1:[0-9]*\//http:\/\/127.0.0.1:$PORT\//g" .htaccess

# Update package.json file
status_message "Updating package.json file"
sed -i "s/NODE_PORT=[0-9]*/NODE_PORT=$PORT/" package.json

# Install project dependencies
status_message "Installing project dependencies"
npm install --loglevel verbose

# Build the project
status_message "Building the project"
npm run build

# Start the project with PM2
status_message "Starting the project with PM2"
pm2 start npm --name "eCommerce" -- start

# Save PM2 process list so it survives reboot
pm2 save

# Display PM2 processes
status_message "Displaying PM2 processes"
pm2 ls

status_message "Installation and deployment complete!"
