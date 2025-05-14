#!/bin/bash
set -e

# Create directory for Worker project
echo "Creating Worker project directory..."
mkdir -p worker
cd worker

# Initialize package.json
echo "Initializing package.json..."
cat > package.json << 'EOL'
{
  "name": "appsmith-worker",
  "version": "1.0.0",
  "description": "Worker Service for AI tasks and async job processing",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint --ext .ts src/",
    "test": "vitest run"
  },
  "keywords": ["worker", "ai", "typescript", "job-queue"],
  "author": "",
  "license": "MIT"
}
EOL

# Install dependencies
echo "Installing dependencies..."
npm install bullmq ioredis pg dotenv @hono/node-server hono openai axios node-fetch

# Install dev dependencies
echo "Installing development dependencies..."
npm install --save-dev typescript tsx @types/node eslint vitest

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
mkdir -p src/jobs src/services src/db src/utils

# Create main application file
echo "Creating main application file..."
cat > src/index.ts << 'EOL'
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { logger } from 'hono/logger'
import { startWorkers } from './jobs'
import { setupQueues } from './jobs/queues'

// Initialize the Hono app
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

// Job management endpoints
app.get('/jobs', async (c) => {
  // Implement job listing logic here
  return c.json({ jobs: [] })
})

app.get('/jobs/:id', async (c) => {
  const id = c.req.param('id')
  // Implement job fetching logic here
  return c.json({ job: { id } })
})

app.post('/jobs', async (c) => {
  try {
    const data = await c.req.json()
    // Implement job creation logic here
    return c.json({ jobId: 'new-job-id', status: 'queued' }, 201)
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to create job' }, 500)
  }
})

// Error handling
app.onError((err, c) => {
  console.error(`${err}`)
  return c.json({
    error: {
      message: err.message || 'Internal Server Error',
      status: err.status || 500
    }
  }, err.status || 500)
})

// Start server and workers
const port = parseInt(process.env.PORT || '8080', 10)
console.log(`Worker server is running on port ${port}`)

// Setup job queues
setupQueues()

// Start processing jobs
startWorkers()

// Start the HTTP server
serve({
  fetch: app.fetch,
  port
})
EOL

# Create job queue setup
echo "Creating job queue setup..."
cat > src/jobs/queues.ts << 'EOL'
import { Queue } from 'bullmq'
import { redisConnection } from '../utils/redis'

// Define queue names
export const QUEUE_NAMES = {
  DIAGRAM_GENERATION: 'diagram-generation',
  AI_PROCESSING: 'ai-processing',
  DOCUMENT_GENERATION: 'document-generation'
}

// Create queues
let diagramQueue: Queue
let aiProcessingQueue: Queue
let documentQueue: Queue

export function setupQueues() {
  diagramQueue = new Queue(QUEUE_NAMES.DIAGRAM_GENERATION, { 
    connection: redisConnection,
    defaultJobOptions: {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000
      },
      removeOnComplete: false,
      removeOnFail: false
    }
  })

  aiProcessingQueue = new Queue(QUEUE_NAMES.AI_PROCESSING, {
    connection: redisConnection,
    defaultJobOptions: {
      attempts: 2,
      backoff: {
        type: 'exponential',
        delay: 1000
      },
      removeOnComplete: false,
      removeOnFail: false
    }
  })

  documentQueue = new Queue(QUEUE_NAMES.DOCUMENT_GENERATION, {
    connection: redisConnection,
    defaultJobOptions: {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000
      },
      removeOnComplete: false,
      removeOnFail: false
    }
  })

  console.log('Job queues initialized')
  
  return {
    diagramQueue,
    aiProcessingQueue,
    documentQueue
  }
}

export function getQueues() {
  return {
    diagramQueue,
    aiProcessingQueue,
    documentQueue
  }
}
EOL

# Create job workers
echo "Creating job workers..."
cat > src/jobs/index.ts << 'EOL'
import { Worker } from 'bullmq'
import { redisConnection } from '../utils/redis'
import { QUEUE_NAMES } from './queues'
import { processDiagramGeneration } from './processors/diagram'
import { processAITask } from './processors/ai'
import { processDocumentGeneration } from './processors/document'

export function startWorkers() {
  // Diagram generation worker
  const diagramWorker = new Worker(QUEUE_NAMES.DIAGRAM_GENERATION, processDiagramGeneration, {
    connection: redisConnection,
    concurrency: 2
  })

  // AI processing worker
  const aiWorker = new Worker(QUEUE_NAMES.AI_PROCESSING, processAITask, {
    connection: redisConnection,
    concurrency: 2
  })

  // Document generation worker
  const documentWorker = new Worker(QUEUE_NAMES.DOCUMENT_GENERATION, processDocumentGeneration, {
    connection: redisConnection,
    concurrency: 2
  })

  // Set up event handlers for the workers
  const setupWorkerEvents = (worker: Worker, name: string) => {
    worker.on('completed', job => {
      console.log(`${name} job ${job.id} completed`)
    })

    worker.on('failed', (job, err) => {
      console.error(`${name} job ${job?.id} failed with error: ${err.message}`)
    })

    worker.on('error', err => {
      console.error(`${name} worker error: ${err.message}`)
    })
  }

  setupWorkerEvents(diagramWorker, 'Diagram')
  setupWorkerEvents(aiWorker, 'AI')
  setupWorkerEvents(documentWorker, 'Document')

  console.log('All workers started')

  return {
    diagramWorker,
    aiWorker,
    documentWorker
  }
}
EOL

# Create job processor directories
mkdir -p src/jobs/processors

# Create diagram processor
echo "Creating job processors..."
cat > src/jobs/processors/diagram.ts << 'EOL'
import { Job } from 'bullmq'
import { updateJobStatus } from '../../db/jobs'

export async function processDiagramGeneration(job: Job) {
  try {
    console.log(`Processing diagram generation job ${job.id}`)
    
    // Update job status to in-progress
    await updateJobStatus(job.id as string, 'processing')
    
    // Extract job data
    const { ideaId, diagramType } = job.data
    
    // Implement diagram generation logic here
    // This could involve calling external APIs or services
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // Generate result (this would be the actual diagram data in production)
    const result = {
      diagramUrl: `https://example.com/diagrams/${ideaId}/${diagramType}.svg`,
      generatedAt: new Date().toISOString()
    }
    
    // Update job status to completed
    await updateJobStatus(job.id as string, 'completed', result)
    
    return result
  } catch (error) {
    console.error(`Diagram generation failed: ${error}`)
    
    // Update job status to failed
    await updateJobStatus(job.id as string, 'failed', null, error.message)
    
    throw error
  }
}
EOL

# Create AI processor
cat > src/jobs/processors/ai.ts << 'EOL'
import { Job } from 'bullmq'
import { updateJobStatus } from '../../db/jobs'
import { callLLMService } from '../../services/ai'

export async function processAITask(job: Job) {
  try {
    console.log(`Processing AI task job ${job.id}`)
    
    // Update job status to in-progress
    await updateJobStatus(job.id as string, 'processing')
    
    // Extract job data
    const { prompt, model, options } = job.data
    
    // Call AI service
    const aiResponse = await callLLMService(prompt, model, options)
    
    // Update job status to completed
    await updateJobStatus(job.id as string, 'completed', aiResponse)
    
    return aiResponse
  } catch (error) {
    console.error(`AI processing failed: ${error}`)
    
    // Update job status to failed
    await updateJobStatus(job.id as string, 'failed', null, error.message)
    
    throw error
  }
}
EOL

# Create document processor
cat > src/jobs/processors/document.ts << 'EOL'
import { Job } from 'bullmq'
import { updateJobStatus } from '../../db/jobs'

export async function processDocumentGeneration(job: Job) {
  try {
    console.log(`Processing document generation job ${job.id}`)
    
    // Update job status to in-progress
    await updateJobStatus(job.id as string, 'processing')
    
    // Extract job data
    const { ideaId, documentType, content } = job.data
    
    // Implement document generation logic here
    
    // Simulate processing time
    await new Promise(resolve => setTimeout(resolve, 1500))
    
    // Generate result (this would be the actual document data in production)
    const result = {
      documentUrl: `https://example.com/documents/${ideaId}/${documentType}.pdf`,
      generatedAt: new Date().toISOString()
    }
    
    // Update job status to completed
    await updateJobStatus(job.id as string, 'completed', result)
    
    return result
  } catch (error) {
    console.error(`Document generation failed: ${error}`)
    
    // Update job status to failed
    await updateJobStatus(job.id as string, 'failed', null, error.message)
    
    throw error
  }
}
EOL

# Create utilities
echo "Creating utilities..."
cat > src/utils/redis.ts << 'EOL'
import IORedis from 'ioredis'
import dotenv from 'dotenv'

dotenv.config()

// Create Redis connection
export const redisConnection = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: 3,
  enableReadyCheck: false,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000)
    return delay
  }
})

redisConnection.on('error', (err) => {
  console.error('Redis connection error:', err)
})

redisConnection.on('connect', () => {
  console.log('Connected to Redis')
})
EOL

# Create AI service
cat > src/services/ai.ts << 'EOL'
import OpenAI from 'openai'
import dotenv from 'dotenv'

dotenv.config()

const openai = new OpenAI({
  apiKey: process.env.AI_API_KEY
})

export async function callLLMService(prompt: string, model = 'gpt-3.5-turbo', options = {}) {
  try {
    const response = await openai.chat.completions.create({
      model,
      messages: [
        { role: 'system', content: 'You are a helpful assistant.' },
        { role: 'user', content: prompt }
      ],
      ...options
    })
    
    return {
      text: response.choices[0].message.content,
      model: response.model,
      usage: response.usage
    }
  } catch (error) {
    console.error('LLM service error:', error)
    throw new Error(`Failed to call LLM service: ${error.message}`)
  }
}
EOL

# Create database logic for jobs
cat > src/db/jobs.ts << 'EOL'
import { Pool } from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
})

export async function updateJobStatus(jobId: string, status: string, result = null, error = null) {
  try {
    const now = new Date()
    
    let query = `
      UPDATE job_queue 
      SET status = $1, updated_at = $2
    `
    
    const params = [status, now]
    
    if (status === 'processing') {
      query += `, started_at = $3`
      params.push(now)
    } else if (status === 'completed') {
      query += `, completed_at = $3, result = $4`
      params.push(now, JSON.stringify(result))
    } else if (status === 'failed') {
      query += `, completed_at = $3, error = $4`
      params.push(now, error)
    }
    
    query += ` WHERE id = $${params.length + 1} RETURNING *`
    params.push(jobId)
    
    const res = await pool.query(query, params)
    return res.rows[0]
  } catch (error) {
    console.error(`Error updating job status: ${error}`)
    throw error
  }
}

export async function createJob(jobType: string, payload: any) {
  try {
    const query = `
      INSERT INTO job_queue (job_type, payload, status)
      VALUES ($1, $2, 'pending')
      RETURNING id
    `
    
    const res = await pool.query(query, [jobType, JSON.stringify(payload)])
    return res.rows[0].id
  } catch (error) {
    console.error(`Error creating job: ${error}`)
    throw error
  }
}

export async function getJob(jobId: string) {
  try {
    const query = `
      SELECT * FROM job_queue
      WHERE id = $1
    `
    
    const res = await pool.query(query, [jobId])
    return res.rows[0]
  } catch (error) {
    console.error(`Error getting job: ${error}`)
    throw error
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
PORT=8080
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/appsmith
REDIS_URL=redis://localhost:6379
AI_API_KEY=your_openai_api_key_here
EOL

echo "Worker project setup complete!"