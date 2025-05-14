# Appsmith Multi-Service Platform

A production-grade microservices architecture for building and deploying scalable applications.

## System Architecture

The platform consists of five main services:

1. **Web Server** (Next.js + shadcn)
   - Frontend application with SSR capabilities
   - Modern UI components with shadcn
   - Type-safe development with TypeScript

2. **API Server** (Hono)
   - High-performance backend API
   - Efficient routing and middleware system
   - Built-in authentication and authorization
   - PostgreSQL integration for data persistence

3. **Database Server** (PostgreSQL)
   - Robust data storage with ACID compliance
   - Full-text search capabilities
   - Efficient indexing and query optimization
   - Data validation and integrity constraints

4. **Worker Server**
   - Asynchronous job processing
   - AI/ML task execution
   - Diagram generation
   - Document processing
   - Redis-backed job queue

5. **MCP Bridge Server**
   - WebSocket real-time communication
   - gRPC support for efficient IDE integration
   - CLI tool connectivity
   - Event streaming capabilities

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js (v18 or later)
- npm or yarn
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd appsmith
```

2. Set up environment variables:
```bash
cp .env.example .env
```
Edit `.env` with your configuration.

3. Run the setup script:
```bash
chmod +x setup.sh
./setup.sh
```

4. Start the development environment:
```bash
docker-compose up
```

### Service Endpoints

- Web UI: http://localhost:3000
- API: http://localhost:8000
- Worker: http://localhost:8080
- Bridge HTTP: http://localhost:9000
- Bridge WebSocket: ws://localhost:9001
- Bridge gRPC: localhost:9002

## Development

### Project Structure

```
appsmith/
├── services/
│   ├── web/          # Next.js frontend
│   ├── api/          # Hono backend
│   ├── worker/       # Job processing service
│   ├── bridge/       # IDE/CLI integration
│   └── db/           # Database migrations and seeds
├── deploy/           # Deployment configurations
├── scripts/          # Setup and utility scripts
└── docker-compose.yml
```

### Adding New Features

1. Backend (API):
   - Add routes in `services/api/src/routes/`
   - Create controllers in `services/api/src/controllers/`
   - Add services in `services/api/src/services/`

2. Frontend (Web):
   - Add pages in `services/web/src/app/`
   - Create components in `services/web/src/components/`
   - Add API integrations in `services/web/src/lib/api/`

3. Worker Tasks:
   - Add job processors in `services/worker/src/jobs/processors/`
   - Create new queue definitions in `services/worker/src/jobs/queues.ts`

4. Bridge Extensions:
   - Add WebSocket handlers in `services/bridge/src/handlers/websocket.ts`
   - Extend gRPC services in `services/bridge/proto/bridge.proto`

### Database Migrations

```bash
cd services/api
npm run migrate:create
npm run migrate:up
```

## Production Deployment

1. Build production images:
```bash
docker-compose -f docker-compose.prod.yml build
```

2. Deploy to your infrastructure:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Health Checks

Each service exposes a health check endpoint:

- Web: `GET /api/health`
- API: `GET /health`
- Worker: `GET /health`
- Bridge: `GET /health`

## Monitoring

The platform includes:

- Health check endpoints for each service
- Docker container metrics
- PostgreSQL query monitoring
- Redis queue monitoring
- Worker job statistics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

MIT License - see [LICENSE.md](LICENSE.md) for details

## Support

For support, please:

1. Check the documentation
2. Create an issue
3. Contact the maintainers

## Security

Please report security issues privately to the maintainers.