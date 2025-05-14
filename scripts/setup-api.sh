#!/bin/bash
set -e

# Create directory for Hono API project
echo "Creating Hono API project directory..."
mkdir -p api
cd api

# Initialize package.json
echo "Initializing package.json..."
cat > package.json << 'EOL'
{
  "name": "appsmith-api",
  "version": "1.0.0",
  "description": "Hono API Server for Appsmith",
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint --ext .ts src/",
    "test": "vitest run"
  },
  "keywords": ["api", "hono", "typescript"],
  "author": "",
  "license": "MIT"
}
EOL

# Install dependencies
echo "Installing dependencies..."
npm install hono @hono/node-server @hono/zod-validator zod bcrypt jsonwebtoken pg drizzle-orm dotenv cors

# Install dev dependencies
echo "Installing development dependencies..."
npm install --save-dev typescript tsx @types/node @types/bcrypt @types/jsonwebtoken @types/pg eslint vitest drizzle-kit

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
mkdir -p src/routes src/middleware src/controllers src/services src/db src/utils

# Create main application file
echo "Creating main application file..."
cat > src/index.ts << 'EOL'
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { ideasRouter } from './routes/ideas'
import { ticketsRouter } from './routes/tickets'
import { usersRouter } from './routes/users'
import { authRouter } from './routes/auth'
import { jwtAuth } from './middleware/auth'

const app = new Hono()

// Middleware
app.use('*', logger())
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  exposeHeaders: ['Content-Length', 'X-Request-Id'],
  maxAge: 86400,
  credentials: true,
}))

// Health check endpoint
app.get('/api/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  })
})

// Public routes
app.route('/api/auth', authRouter)

// Protected routes
app.use('/api/*', jwtAuth)
app.route('/api/ideas', ideasRouter)
app.route('/api/tickets', ticketsRouter)
app.route('/api/users', usersRouter)

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

// Start server
const port = parseInt(process.env.PORT || '8000', 10)
console.log(`Server is running on port ${port}`)

serve({
  fetch: app.fetch,
  port
})

export default app
EOL

# Create authentication middleware
echo "Creating authentication middleware..."
cat > src/middleware/auth.ts << 'EOL'
import { Context, Next } from 'hono'
import jwt from 'jsonwebtoken'

export const jwtAuth = async (c: Context, next: Next) => {
  const authHeader = c.req.header('Authorization')
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401)
  }
  
  const token = authHeader.split(' ')[1]
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'default_secret')
    c.set('user', decoded)
    await next()
  } catch (error) {
    return c.json({ error: 'Invalid token' }, 401)
  }
}
EOL

# Create database configuration
echo "Creating database configuration..."
cat > src/db/index.ts << 'EOL'
import { Pool } from 'pg'
import { drizzle } from 'drizzle-orm/node-postgres'
import dotenv from 'dotenv'

dotenv.config()

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
})

export const db = drizzle(pool)
export const query = pool.query.bind(pool)
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
PORT=8000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/appsmith
JWT_SECRET=your_jwt_secret_key_here
CORS_ORIGIN=http://localhost:3000
EOL

# Create sample route file for ideas
echo "Creating sample route files..."
cat > src/routes/ideas.ts << 'EOL'
import { Hono } from 'hono'
import { z } from 'zod'
import { zValidator } from '@hono/zod-validator'

const ideasRouter = new Hono()

const ideaSchema = z.object({
  title: z.string().min(3).max(255),
  description: z.string().min(10),
  status: z.enum(['draft', 'published', 'archived']).optional(),
})

ideasRouter.get('/', async (c) => {
  try {
    // Implement database fetch logic here
    return c.json({ ideas: [] })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to fetch ideas' }, 500)
  }
})

ideasRouter.post('/', zValidator('json', ideaSchema), async (c) => {
  try {
    const data = await c.req.valid('json')
    // Implement database insert logic here
    return c.json({ message: 'Idea created', data }, 201)
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to create idea' }, 500)
  }
})

ideasRouter.get('/:id', async (c) => {
  try {
    const id = c.req.param('id')
    // Implement database fetch by id logic here
    return c.json({ id })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to fetch idea' }, 500)
  }
})

ideasRouter.put('/:id', zValidator('json', ideaSchema), async (c) => {
  try {
    const id = c.req.param('id')
    const data = await c.req.valid('json')
    // Implement database update logic here
    return c.json({ message: 'Idea updated', id, data })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to update idea' }, 500)
  }
})

ideasRouter.delete('/:id', async (c) => {
  try {
    const id = c.req.param('id')
    // Implement database delete logic here
    return c.json({ message: 'Idea deleted', id })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Failed to delete idea' }, 500)
  }
})

export { ideasRouter }
EOL

# Create auth routes
cat > src/routes/auth.ts << 'EOL'
import { Hono } from 'hono'
import { z } from 'zod'
import { zValidator } from '@hono/zod-validator'
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'

const authRouter = new Hono()

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
})

const registerSchema = loginSchema.extend({
  name: z.string().min(2),
})

authRouter.post('/login', zValidator('json', loginSchema), async (c) => {
  try {
    const { email, password } = await c.req.valid('json')
    
    // Implement user lookup and password validation here
    // This is just a placeholder - replace with actual DB query
    const user = { id: '1', email, name: 'Test User', password_hash: '' };
    
    if (!user) {
      return c.json({ error: 'Invalid credentials' }, 401)
    }
    
    // Replace with actual password check
    const passwordIsValid = true // bcrypt.compareSync(password, user.password_hash);
    
    if (!passwordIsValid) {
      return c.json({ error: 'Invalid credentials' }, 401)
    }
    
    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET || 'default_secret',
      { expiresIn: '24h' }
    )
    
    return c.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    })
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Login failed' }, 500)
  }
})

authRouter.post('/register', zValidator('json', registerSchema), async (c) => {
  try {
    const { email, password, name } = await c.req.valid('json')
    
    // Check if user already exists
    // Implement actual DB check here
    
    // Hash password
    const salt = await bcrypt.genSalt(10)
    const hashedPassword = await bcrypt.hash(password, salt)
    
    // Create user
    // Implement actual DB insert here
    
    return c.json({ message: 'User registered successfully' }, 201)
  } catch (error) {
    console.error(error)
    return c.json({ error: 'Registration failed' }, 500)
  }
})

export { authRouter }
EOL

echo "Hono API project setup complete!"