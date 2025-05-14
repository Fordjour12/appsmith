#!/bin/bash
set -e

# Create directory for Bridge project
echo "Creating Bridge project directory..."
mkdir -p bridge
cd bridge

# Initialize package.json
echo "Initializing package.json..."
cat > package.json << 'EOL'
{
  "name": "appsmith-bridge",
  "version": "1.0.0",
  "description": "WebSocket/gRPC Bridge for IDE and CLI Integration",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint --ext .ts src/",
    "test": "vitest run",
    "proto:generate": "protoc --plugin=./node_modules/.bin/protoc-gen-ts_proto --ts_proto_out=./src/proto/ ./proto/*.proto"
  },
  "keywords": ["websocket", "grpc", "bridge", "typescript"],
  "author": "",
  "license": "MIT"
}
EOL

# Install dependencies
echo "Installing dependencies..."
npm install @grpc/grpc-js @grpc/proto-loader ws dotenv @hono/node-server hono nice-grpc zod @types/ws

# Install dev dependencies
echo "Installing development dependencies..."
npm install --save-dev typescript tsx @types/node eslint vitest ts-proto

# Create TypeScript configuration
echo "Creating TypeScript configuration..."
cat > tsconfig.json << 'EOL'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "strict": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOL

# Create project structure
echo "Creating project structure..."
mkdir -p src/websocket src/grpc src/proto proto src/handlers src/utils

# Create protobuf definition
echo "Creating protobuf definition..."
cat > proto/bridge.proto << 'EOL'
syntax = "proto3";

package bridge;

service BridgeService {
  rpc Connect (ConnectRequest) returns (ConnectResponse);
  rpc SendCommand (CommandRequest) returns (CommandResponse);
  rpc StreamEvents (StreamRequest) returns (stream EventResponse);
}

message ConnectRequest {
  string clientId = 1;
  string clientType = 2; // IDE or CLI
}

message ConnectResponse {
  string sessionId = 1;
  string status = 2;
}

message CommandRequest {
  string sessionId = 1;
  string command = 2;
  map<string, string> parameters = 3;
}

message CommandResponse {
  string status = 1;
  string result = 2;
  string error = 3;
}

message StreamRequest {
  string sessionId = 1;
  repeated string eventTypes = 2;
}

message EventResponse {
  string eventType = 1;
  string payload = 2;
  string timestamp = 3;
}
EOL

# Create main application file
echo "Creating main application file..."
cat > src/index.ts << 'EOL'
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { logger } from 'hono/logger'
import { startWebSocketServer } from './websocket/server'
import { startGrpcServer } from './grpc/server'
import dotenv from 'dotenv'

dotenv.config()

// Initialize the Hono app for HTTP endpoints
const app = new Hono()

// Middleware
app.use('*', logger())

// Health check endpoint
app.get('/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  })
})

// Start servers
const httpPort = parseInt(process.env.HTTP_PORT || '9000', 10)
const wsPort = parseInt(process.env.WS_PORT || '9001', 10)
const grpcPort = parseInt(process.env.GRPC_PORT || '9002', 10)

// Start WebSocket server
startWebSocketServer(wsPort)

// Start gRPC server
startGrpcServer(grpcPort)

// Start HTTP server
serve({
  fetch: app.fetch,
  port: httpPort
})

console.log(`HTTP server running on port ${httpPort}`)
console.log(`WebSocket server running on port ${wsPort}`)
console.log(`gRPC server running on port ${grpcPort}`)
EOL

# Create WebSocket server
echo "Creating WebSocket server..."
cat > src/websocket/server.ts << 'EOL'
import { WebSocketServer, WebSocket } from 'ws'
import { handleWebSocketConnection } from '../handlers/websocket'

export function startWebSocketServer(port: number) {
  const wss = new WebSocketServer({ port })

  wss.on('connection', (ws: WebSocket) => {
    handleWebSocketConnection(ws)
  })

  wss.on('error', (error: Error) => {
    console.error('WebSocket server error:', error)
  })

  console.log(`WebSocket server is running on port ${port}`)

  return wss
}
EOL

# Create gRPC server
echo "Creating gRPC server..."
cat > src/grpc/server.ts << 'EOL'
import { createServer } from 'nice-grpc'
import { BridgeServiceDefinition } from '../proto/bridge'
import { handleGrpcImplementation } from '../handlers/grpc'

export function startGrpcServer(port: number) {
  const server = createServer()

  server.add(BridgeServiceDefinition, handleGrpcImplementation())

  server.listen(`0.0.0.0:${port}`)
  console.log(`gRPC server is running on port ${port}`)

  return server
}
EOL

# Create WebSocket handler
echo "Creating WebSocket handler..."
cat > src/handlers/websocket.ts << 'EOL'
import { WebSocket } from 'ws'
import { handleCommand } from '../utils/command-handler'

export function handleWebSocketConnection(ws: WebSocket) {
  console.log('New WebSocket connection established')

  ws.on('message', async (message: string) => {
    try {
      const data = JSON.parse(message)
      const result = await handleCommand(data)
      ws.send(JSON.stringify(result))
    } catch (error) {
      ws.send(JSON.stringify({
        error: error.message || 'Failed to process message'
      }))
    }
  })

  ws.on('close', () => {
    console.log('WebSocket connection closed')
  })

  ws.on('error', (error) => {
    console.error('WebSocket error:', error)
  })
}
EOL

# Create gRPC handler
echo "Creating gRPC handler..."
cat > src/handlers/grpc.ts << 'EOL'
import { BridgeServiceImplementation } from '../proto/bridge'
import { handleCommand } from '../utils/command-handler'
import { v4 as uuidv4 } from 'uuid'

export function handleGrpcImplementation(): BridgeServiceImplementation {
  return {
    async connect(request) {
      const sessionId = uuidv4()
      return {
        sessionId,
        status: 'connected'
      }
    },

    async sendCommand(request) {
      try {
        const result = await handleCommand({
          sessionId: request.sessionId,
          command: request.command,
          parameters: request.parameters
        })

        return {
          status: 'success',
          result: JSON.stringify(result),
          error: ''
        }
      } catch (error) {
        return {
          status: 'error',
          result: '',
          error: error.message || 'Command execution failed'
        }
      }
    },

    async *streamEvents(request) {
      const { sessionId, eventTypes } = request

      // Set up event listeners based on eventTypes
      for (const eventType of eventTypes) {
        // Implement event streaming logic here
        yield {
          eventType,
          payload: JSON.stringify({ message: 'Event data' }),
          timestamp: new Date().toISOString()
        }
      }
    }
  }
}
EOL

# Create command handler utility
echo "Creating command handler utility..."
cat > src/utils/command-handler.ts << 'EOL'
interface CommandRequest {
  sessionId: string
  command: string
  parameters: Record<string, string>
}

export async function handleCommand(request: CommandRequest) {
  const { command, parameters } = request

  switch (command) {
    case 'ping':
      return { pong: true, timestamp: new Date().toISOString() }

    case 'validate':
      // Implement validation logic
      return { valid: true, message: 'Validation successful' }

    case 'execute':
      // Implement command execution logic
      return { executed: true, result: 'Command executed successfully' }

    default:
      throw new Error(`Unknown command: ${command}`)
  }
}
EOL

# Setup Docker ignore file
echo "Creating .dockerignore..."
cat > .dockerignore << 'EOL'
node_modules
dist
.git
.env
npm-debug.log
yarn-debug.log
yarn-error.log
EOL

# Setup .env file
echo "Creating .env file..."
cat > .env << 'EOL'
# Development environment
HTTP_PORT=9000
WS_PORT=9001
GRPC_PORT=9002
API_URL=http://localhost:8000
EOL

echo "Bridge project setup complete!"