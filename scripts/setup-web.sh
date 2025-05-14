#!/bin/bash
set -e

# Create Next.js project with TypeScript
echo "Creating Next.js project with TypeScript..."
npx create-next-app@latest web --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
cd web

# Add shadcn UI
echo "Setting up shadcn UI..."
npx shadcn-ui@latest init --yes

# Configure shadcn components
echo "Installing shadcn components..."
npx shadcn-ui@latest add button
npx shadcn-ui@latest add card
npx shadcn-ui@latest add form
npx shadcn-ui@latest add input
npx shadcn-ui@latest add dialog
npx shadcn-ui@latest add dropdown-menu
npx shadcn-ui@latest add select
npx shadcn-ui@latest add sheet
npx shadcn-ui@latest add tabs
npx shadcn-ui@latest add sooner

# Add additional dependencies
echo "Installing additional dependencies..."
npm install axios swr react-hook-form zod @hookform/resolvers next-auth

# Create health check API route
echo "Creating health check API route..."
mkdir -p src/app/api/health
cat > src/app/api/health/route.ts << 'EOL'
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
}
EOL

# Setup .env file
echo "Creating .env files..."
cat > .env.local << 'EOL'
# Development environment variables
NEXT_PUBLIC_API_URL=http://localhost:8000
EOL

cat > .env.production << 'EOL'
# Production environment variables
NEXT_PUBLIC_API_URL=http://api:8000
EOL

# Setup Docker ignore file
echo "Creating .dockerignore..."
cat > .dockerignore << 'EOL'
node_modules
.next
.git
.env.local
.env.development
npm-debug.log
yarn-debug.log
yarn-error.log
EOL

echo "Next.js with shadcn project setup complete!"
