#!/bin/bash
set -e

# ASCII art banner
echo "
╔═══════════════════════════════════════════╗
║             Appsmith Setup                ║
║     Multi-Service Development Platform    ║
╚═══════════════════════════════════════════╝
"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
echo "Checking dependencies..."

REQUIRED_COMMANDS=(
    "node"
    "npm"
    "docker"
    "docker-compose"
    "git"
)

MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command_exists "$cmd"; then
        MISSING_COMMANDS+=("$cmd")
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    echo "Error: The following required commands are missing:"
    printf '%s\n' "${MISSING_COMMANDS[@]}"
    echo "Please install them and try again."
    exit 1
fi

# Create project structure
echo "Creating project structure..."

# Make scripts executable
chmod +x scripts/*.sh

# Create .env file
echo "Creating root .env file..."
cat > .env << 'EOL'
# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=appsmith
DATABASE_URL=postgresql://postgres:postgres@db:5432/appsmith

# JWT Configuration
JWT_SECRET=your_jwt_secret_here

# AI Service Configuration
AI_API_KEY=your_openai_api_key_here

# Redis Configuration
REDIS_URL=redis://redis:6379

# Ports Configuration
WEB_PORT=3000
API_PORT=8000
WORKER_PORT=8080
BRIDGE_HTTP_PORT=9000
BRIDGE_WS_PORT=9001
BRIDGE_GRPC_PORT=9002

# CORS Configuration
CORS_ORIGIN=http://localhost:3000
EOL

# Initialize services
echo "Initializing services..."

# Setup Web (Next.js + shadcn)
echo "Setting up Web service..."
mkdir -p services/web
cd services/web
../../scripts/setup-web.sh
cd ../..

# Setup API (Hono)
echo "Setting up API service..."
mkdir -p services/api
cd services/api
../../scripts/setup-api.sh
cd ../..

# Setup Worker
echo "Setting up Worker service..."
mkdir -p services/worker
cd services/worker
../../scripts/setup-worker.sh
cd ../..

# Setup Bridge
echo "Setting up Bridge service..."
mkdir -p services/bridge
cd services/bridge
../../scripts/setup-bridge.sh
cd ../..

# Initialize git repository if not already initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    
    # Create .gitignore
    cat > .gitignore << 'EOL'
# Dependencies
node_modules/
.pnp/
.pnp.js

# Testing
coverage/

# Production
build/
dist/
.next/
out/

# Environment
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOL

    git add .
    git commit -m "Initial commit"
fi

# Build Docker images
echo "Building Docker images..."
docker-compose build

echo "
╔═══════════════════════════════════════════╗
║             Setup Complete!               ║
╚═══════════════════════════════════════════╝

To start the development environment:
1. Update the .env file with your configuration
2. Run: docker-compose up

Services will be available at:
- Web: http://localhost:3000
- API: http://localhost:8000
- Worker: http://localhost:8080
- Bridge HTTP: http://localhost:9000
- Bridge WebSocket: ws://localhost:9001
- Bridge gRPC: localhost:9002

Happy coding! 🚀
"