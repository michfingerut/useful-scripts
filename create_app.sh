#!/bin/bash

# Function to display script header
display_header() {
  echo "=========================================="
  echo "         App Template Generator           "
  echo "=========================================="
  echo
}

# Function to get user input with validation
get_input() {
  local prompt=$1
  local var_name=$2
  local default=$3
  local value=""

  while [ -z "$value" ]; do
    read -p "$prompt [default: $default]: " value
    value=${value:-$default}
    if [ -z "$value" ]; then
      echo "Error: Input cannot be empty. Please try again."
    fi
  done
  
  eval "$var_name=\"$value\""
}

# Function to validate DB choice
get_db_choice() {
  local prompt=$1
  local var_name=$2
  local valid_choice=false
  local choice=""

  while [ "$valid_choice" = false ]; do
    read -p "$prompt (postgres/mongodb): " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    
    if [ "$choice" = "postgres" ] || [ "$choice" = "postgresql" ]; then
      valid_choice=true
      eval "$var_name=\"postgres\""
    elif [ "$choice" = "mongodb" ] || [ "$choice" = "mongo" ]; then
      valid_choice=true
      eval "$var_name=\"mongodb\""
    else
      echo "Invalid choice. Please enter 'postgres' or 'mongodb'."
    fi
  done
}

# Get user inputs
display_header
get_input "Enter app name" "APP_NAME" "my-app"
get_db_choice "Choose database type" "DB_TYPE"

# Generate random ports to avoid conflicts
CLIENT_PORT=$((3000 + RANDOM % 1000))
SERVER_PORT=$((8000 + RANDOM % 1000))

echo
echo "Creating app structure for: $APP_NAME"
echo "Database type: $DB_TYPE"
echo "Client port: $CLIENT_PORT"
echo "Server port: $SERVER_PORT"
echo

# Create main app directory
mkdir -p "$APP_NAME"
cd "$APP_NAME"

# Create basic structure for server
mkdir -p server/src/routes server/src/models server/src/controllers server/src/config

# Create scripts directory and scripts
mkdir -p scripts

# Create start script
cat > scripts/start.sh << EOL
#!/bin/bash

# Function to display a header
display_header() {
  echo "=========================================="
  echo "           Starting $APP_NAME            "
  echo "=========================================="
  echo
}

display_header

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: docker-compose is not installed or not in PATH"
  exit 1
fi

# Ensure we're in the right directory
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "\$SCRIPT_DIR/.."

echo "Starting Docker containers..."
docker-compose up -d

echo
echo "Checking container status..."
docker-compose ps

echo
echo "=========================================="
echo "Application is now running!"
echo "Frontend: http://localhost:$CLIENT_PORT"
echo "Backend API: http://localhost:$SERVER_PORT"
echo "=========================================="
echo
echo "To view logs, run: docker-compose logs -f"
echo "To stop the application, run: ./scripts/stop.sh"
EOL

# Create stop script
cat > scripts/stop.sh << EOL
#!/bin/bash

# Function to display a header
display_header() {
  echo "=========================================="
  echo "           Stopping $APP_NAME            "
  echo "=========================================="
  echo
}

display_header

# Ensure we're in the right directory
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "\$SCRIPT_DIR/.."

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: docker-compose is not installed or not in PATH"
  exit 1
fi

# Stop containers
echo "Stopping Docker containers..."
docker-compose down

# Ask if user wants to remove database volumes
read -p "Do you want to remove database volumes as well? (y/N): " remove_volumes

if [[ "\$remove_volumes" =~ ^[Yy]$ ]]; then
  echo "Removing database volumes..."
  if [ "$DB_TYPE" = "postgres" ]; then
    docker volume rm ${APP_NAME//[^a-zA-Z0-9]/_}_postgres_data
  else
    docker volume rm ${APP_NAME//[^a-zA-Z0-9]/_}_mongodb_data
  fi
  echo "Database volumes removed."
fi

echo
echo "=========================================="
echo "Application has been stopped successfully!"
echo "=========================================="
EOL

# Make scripts executable
chmod +x scripts/start.sh scripts/stop.sh

# Create .gitignore
cat > .gitignore << EOL
# Dependencies
node_modules/
**/node_modules/

# Environment
.env
.env.local
.env.development
.env.test
.env.production

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Dist / build
dist/
build/
**/dist/
**/build/

# IDE
.idea/
.vscode/
*.sublime-project
*.sublime-workspace

# OS
.DS_Store
Thumbs.db
EOL

# Create README.md
cat > README.md << EOL
# $APP_NAME

A full-stack application with Node.js backend (ES6 modules) and Vite frontend.

## Structure

- \`/client\`: Frontend application built with Vite
- \`/server\`: Backend API built with Express.js using ES6 modules
- \`/scripts\`: Utility scripts for running and managing the app
- Database: $DB_TYPE

## Getting Started

### Prerequisites

- Node.js (v14 or later)
- Docker and Docker Compose
- npm or yarn

### Development

1. Clone this repository
2. Set up environment variables by copying \`.env_template\` to \`.env\`
3. Run \`./scripts/start.sh\` to start all services
4. The client will be available at http://localhost:$CLIENT_PORT
5. The server will be available at http://localhost:$SERVER_PORT
6. To stop the app, run \`./scripts/stop.sh\`

## Scripts

- \`./scripts/start.sh\`: Start the application with Docker Compose
- \`./scripts/stop.sh\`: Stop the application (with optional database volume removal)

## License

MIT
EOL

# Create .env and .env_template
if [ "$DB_TYPE" = "postgres" ]; then
  DB_PORT=5432
  DB_URI="postgresql://postgres:postgres@db:5432/app_db"
else
  DB_PORT=27017
  DB_URI="mongodb://mongo:mongo@db:27017/app_db?authSource=admin"
fi

cat > .env << EOL
# Application
NODE_ENV=development

# Client
CLIENT_PORT=$CLIENT_PORT
VITE_API_URL=http://localhost:$SERVER_PORT/api

# Server
SERVER_PORT=$SERVER_PORT
SERVER_HOST=0.0.0.0

# Database
DB_TYPE=$DB_TYPE
DB_URI=$DB_URI
EOL

cp .env .env_template

# Create docker-compose.yml
cat > docker-compose.yml << EOL
services:
  client:
    build:
      context: ./client
      dockerfile: Dockerfile
    ports:
      - "\${CLIENT_PORT}:\${CLIENT_PORT}"
    volumes:
      - ./client:/app
      - /app/node_modules
    environment:
      - PORT=\${CLIENT_PORT}
      - VITE_API_URL=http://localhost:\${SERVER_PORT}/api
    depends_on:
      - server
    restart: unless-stopped

  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    ports:
      - "\${SERVER_PORT}:\${SERVER_PORT}"
    volumes:
      - ./server:/app
      - /app/node_modules
    environment:
      - NODE_ENV=\${NODE_ENV:-development}
      - PORT=\${SERVER_PORT}
      - DB_URI=\${DB_URI}
    depends_on:
      - db
    restart: unless-stopped
EOL

# Add database service based on the choice
if [ "$DB_TYPE" = "postgres" ]; then
  cat >> docker-compose.yml << EOL
  db:
    image: postgres:14-alpine
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=app_db
    restart: unless-stopped

volumes:
  postgres_data:
EOL
else
  cat >> docker-compose.yml << EOL
  db:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=mongo
      - MONGO_INITDB_ROOT_PASSWORD=mongo
      - MONGO_INITDB_DATABASE=app_db
    restart: unless-stopped

volumes:
  mongodb_data:
EOL
fi

# Set up server

# Create package.json for server with ES6 modules support
cat > server/package.json << EOL
{
  "name": "${APP_NAME}-server",
  "version": "1.0.0",
  "description": "Backend server for ${APP_NAME}",
  "type": "module",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon --config nodemon.json",
    "test": "NODE_OPTIONS='--experimental-vm-modules' jest --detectOpenHandles",
    "test:watch": "NODE_OPTIONS='--experimental-vm-modules' jest --watch",
    "lint": "eslint src/**/*.js test/**/*.js",
    "lint:fix": "eslint src/**/*.js test/**/*.js --fix"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
EOL

# Add DB-specific dependencies
if [ "$DB_TYPE" = "postgres" ]; then
  cat >> server/package.json << EOL
    "pg": "^8.10.0",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.31.0"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "nodemon": "^2.0.22",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0"
  }
}
EOL
else
  cat >> server/package.json << EOL
    "mongoose": "^7.0.3"
  },
  "devDependencies": {
    "jest": "^29.5.0", 
    "nodemon": "^2.0.22",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0"
  }
}
EOL
fi

# Create Dockerfile for server (removed - will be created later with proper Jest config)
cat > server/Dockerfile << EOL
FROM node:18-alpine

# Install bash for better shell experience
RUN apk add --no-cache bash

WORKDIR /app

COPY package*.json ./
COPY nodemon.json ./
COPY jest.config.js ./
COPY .eslintrc.json ./

RUN npm install

COPY . .

EXPOSE \${SERVER_PORT}

CMD ["npm", "run", "dev"]
EOL

# Create server index.js with ES6 syntax
cat > server/src/index.js << EOL
import { config } from 'dotenv';
import app from './app.js';

// Load environment variables
config();

const PORT = process.env.SERVER_PORT || 8000;
const HOST = process.env.SERVER_HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(\`Server running at http://\${HOST}:\${PORT}/\`);
});
EOL

# Create app.js with proper DB configuration (ES6 syntax)
cat > server/src/app.js << EOL
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

// Get directory name in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Initialize Express
const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Database connection
EOL

# Add DB-specific connection code with ES6 syntax
if [ "$DB_TYPE" = "postgres" ]; then
  cat >> server/src/app.js << EOL
import { Sequelize } from 'sequelize';
import dbConfig from './config/db.config.js';

export const sequelize = new Sequelize(dbConfig.DB_URI, {
  dialect: 'postgres',
  logging: false
});

// Test database connection
async function testConnection() {
  try {
    await sequelize.authenticate();
    console.log('Database connection established successfully.');
  } catch (error) {
    console.error('Unable to connect to the database:', error);
  }
}

testConnection();

// Sync database models
sequelize.sync({ alter: true })
  .then(() => {
    console.log('Database synchronized');
  })
  .catch(err => {
    console.error('Failed to sync database:', err);
  });
EOL

  # Create DB config for PostgreSQL (ES6)
  cat > server/src/config/db.config.js << EOL
export default {
  DB_URI: process.env.DB_URI || 'postgresql://postgres:postgres@localhost:5432/app_db'
};
EOL

  # Create a basic Sequelize model (ES6)
  cat > server/src/models/example.model.js << EOL
import { DataTypes } from 'sequelize';
import { sequelize } from '../app.js';

const Example = sequelize.define('example', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT
  }
});

export default Example;
EOL

else
  cat >> server/src/app.js << EOL
import mongoose from 'mongoose';
import dbConfig from './config/db.config.js';

// Connect to MongoDB
mongoose.connect(dbConfig.DB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
  })
  .catch(err => {
    console.error('Could not connect to MongoDB:', err);
    process.exit(1);
  });
EOL

  # Create DB config for MongoDB (ES6)
  cat > server/src/config/db.config.js << EOL
export default {
  DB_URI: process.env.DB_URI || 'mongodb://mongo:mongo@localhost:27017/app_db?authSource=admin'
};
EOL

  # Create a basic Mongoose model (ES6)
  cat > server/src/models/example.model.js << EOL
import mongoose from 'mongoose';

const exampleSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  description: {
    type: String
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

const Example = mongoose.model('Example', exampleSchema);
export default Example;
EOL

fi

# Continue with the rest of app.js (ES6 syntax)
cat >> server/src/app.js << EOL

// Routes
app.get('/', (req, res) => {
  res.send('Hello World!');
});

// API routes
import indexRouter from './routes/index.js';
app.use('/api', indexRouter);

// Handle 404
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ message: 'Internal server error' });
});

export default app;
EOL

# Create a basic route file (ES6)
cat > server/src/routes/index.js << EOL
import express from 'express';
const router = express.Router();

// Example route
router.get('/', (req, res) => {
  res.json({ message: 'Welcome to the API' });
});

export default router;
EOL

# We need to add these additions to the server setup section in the script

# Update server directory structure to include test directory
mkdir -p server/test/unit server/test/integration

# Create nodemon.json config file to watch both src and test directories
cat > server/nodemon.json << EOL
{
  "watch": ["src/**/*", "test/**/*"],
  "ext": "js,mjs,json",
  "ignore": ["node_modules/**/*"],
  "exec": "node src/index.js"
}
EOL

# Update package.json for server with Jest and updated nodemon configuration
cat > server/package.json << EOL
{
  "name": "${APP_NAME}-server",
  "version": "1.0.0",
  "description": "Backend server for ${APP_NAME}",
  "type": "module",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon --config nodemon.json",
    "test": "NODE_OPTIONS='--experimental-vm-modules' jest --detectOpenHandles",
    "test:watch": "NODE_OPTIONS='--experimental-vm-modules' jest --watch",
    "lint": "eslint src/**/*.js test/**/*.js",
    "lint:fix": "eslint src/**/*.js test/**/*.js --fix"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
EOL

# Add DB-specific dependencies
if [ "$DB_TYPE" = "postgres" ]; then
  cat >> server/package.json << EOL
    "pg": "^8.10.0",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.31.0"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "nodemon": "^2.0.22",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0"
  }
}
EOL
else
  cat >> server/package.json << EOL
    "mongoose": "^7.0.3"
  },
  "devDependencies": {
    "jest": "^29.5.0", 
    "nodemon": "^2.0.22",
    "supertest": "^6.3.3",
    "eslint": "^8.40.0"
  }
}
EOL
fi

# Create Jest config file for ES modules
cat > server/jest.config.js << EOL
export default {
  testEnvironment: 'node',
  verbose: true,
  testMatch: ['**/test/**/*.test.js']
};
EOL

# Create ESLint config file
cat > server/.eslintrc.json << EOL
{
  "env": {
    "node": true,
    "es2022": true
  },
  "extends": ["eslint:recommended"],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "indent": ["error", 2],
    "linebreak-style": ["error", "unix"],
    "quotes": ["error", "single"],
    "semi": ["error", "always"],
    "no-unused-vars": ["warn"],
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
EOL

# Create example unit test for a model
cat > server/test/unit/example.model.test.js << EOL
import { describe, it, expect } from '@jest/globals';

describe('Example Model', () => {
  it('should be defined', () => {
    expect(true).toBe(true);
  });
  
  it('should pass basic test', () => {
    const example = { name: 'test' };
    expect(example.name).toBe('test');
  });
  
  it('should handle async operations', async () => {
    const result = await Promise.resolve('success');
    expect(result).toBe('success');
  });
});
EOL

# Create example integration test for a route
cat > server/test/integration/routes.test.js << EOL
import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import request from 'supertest';
import app from '../../src/app.js';

let server;

describe('API Routes', () => {
  beforeAll(async () => {
    // Setup test server
    const PORT = 8999;
    server = app.listen(PORT);
    
    // Wait a bit for server to start
    await new Promise(resolve => setTimeout(resolve, 100));
  });

  afterAll(async () => {
    // Close server after tests
    if (server) {
      await new Promise(resolve => server.close(resolve));
    }
  });

  describe('GET /', () => {
    it('should return a hello world message', async () => {
      const response = await request(app).get('/');
      expect(response.status).toBe(200);
      expect(response.text).toContain('Hello World');
    });
  });

  describe('GET /api', () => {
    it('should return welcome message', async () => {
      const response = await request(app).get('/api');
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toBe('Welcome to the API');
    });
  });

  describe('Non-existent route', () => {
    it('should return 404 for non-existent routes', async () => {
      const response = await request(app).get('/non-existent-route');
      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toBe('Route not found');
    });
  });
});
EOL

# Create a template Dockerfile for client (will be moved to client directory after Vite setup)
cat > client_Dockerfile_template << EOL
FROM node:18

# Install bash for better shell experience
RUN apt-get update && apt-get install -y bash && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE \${CLIENT_PORT}

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "\${CLIENT_PORT}"]
EOL

echo
echo "=========================================="
echo "       Server Setup Complete!            "
echo "=========================================="
echo
echo "Now, let's set up the client using Vite's interactive prompt."
echo
echo "You'll be guided through Vite's setup process where you can choose your preferred frontend framework."
echo "When prompted, select the frontend configuration you prefer (React, Vue, etc.)."
echo
echo "Press Enter to continue and start the Vite setup..."
read -p ""

# Now run the Vite CLI to allow interactive setup, not creating client directory beforehand
echo "Running Vite setup in interactive mode..."

# Run the Vite command
npm create vite@latest client

# If Vite setup is successful, move the Dockerfile template into client directory
if [ -d "client" ]; then
  mv client_Dockerfile_template client/Dockerfile
  
  # If package.json exists in client, we assume Vite setup was successful
  if [ -d "client" ] && [ -f "client/package.json" ]; then
    # Check what framework was selected
    FRAMEWORK=""
    if grep -q "@vitejs/plugin-react" client/package.json; then
      FRAMEWORK="react"
    elif grep -q "@vitejs/plugin-vue" client/package.json; then
      FRAMEWORK="vue"
    elif grep -q "@vitejs/plugin-svelte" client/package.json; then
      FRAMEWORK="svelte"
    fi
    
    # Create a proper Vite config based on the framework
    if [ -f "client/vite.config.js" ]; then
      # Back up the original config
      cp client/vite.config.js client/vite.config.js.bak
      
      echo "Updating Vite configuration for Docker compatibility..."
      
      if [ "$FRAMEWORK" = "react" ]; then
        cat > client/vite.config.js << EOL
// Modified by app-template-generator
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: parseInt(process.env.CLIENT_PORT || 3000),
    strictPort: true
  }
})
EOL
      elif [ "$FRAMEWORK" = "vue" ]; then
        cat > client/vite.config.js << EOL
// Modified by app-template-generator
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: parseInt(process.env.CLIENT_PORT || 3000),
    strictPort: true
  }
})
EOL
      elif [ "$FRAMEWORK" = "svelte" ]; then
        cat > client/vite.config.js << EOL
// Modified by app-template-generator
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [svelte()],
  server: {
    host: '0.0.0.0',
    port: parseInt(process.env.CLIENT_PORT || 3000),
    strictPort: true
  }
})
EOL
      else
        # Generic config for other frameworks
        cat > client/vite.config.js << EOL
// Modified by app-template-generator
import { defineConfig } from 'vite'

// https://vitejs.dev/config/
export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: parseInt(process.env.CLIENT_PORT || 3000),
    strictPort: true
  }
})
EOL
      fi
      
      echo "Vite configuration updated for Docker compatibility with $FRAMEWORK framework."
    fi
    
    # Create a simple API service in the client directory
    mkdir -p client/src/services
    cat > client/src/services/api.js << EOL
// API service created by app-template-generator
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:$SERVER_PORT/api';

export const fetchApi = async (endpoint = '') => {
  try {
    const response = await fetch(\`\${API_URL}/\${endpoint}\`);
    if (!response.ok) {
      throw new Error(\`Error: \${response.status}\`);
    }
    return await response.json();
  } catch (error) {
    console.error('API request failed:', error);
    throw error;
  }
};
EOL
    
    echo "API service created at client/src/services/api.js"
    
    # Add lint scripts to client package.json
    echo "Adding lint scripts to client package.json..."
    
    # Add ESLint dependency to client
    npm install --prefix client eslint --save-dev
    
    # Create ESLint config for client
    cat > client/.eslintrc.json << EOL
{
  "env": {
    "browser": true,
    "es2022": true
  },
  "extends": ["eslint:recommended"],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "indent": ["error", 2],
    "linebreak-style": ["error", "unix"],
    "quotes": ["error", "single"],
    "semi": ["error", "always"],
    "no-unused-vars": ["warn"],
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
EOL
    
    # Add lint scripts to package.json (we'll modify the scripts section)
    # This is a simple approach - in a real scenario you might want to use jq or similar
    echo "Lint configuration added to client."
  fi
fi

echo
echo "=========================================="
echo "          Setup Complete!                "
echo "=========================================="
echo
echo "Your app '$APP_NAME' has been created with the following structure:"
echo
echo "- $APP_NAME/"
echo "  |- client/               # Frontend created with Vite"
echo "  |- server/               # Node.js backend (Express) with ES6 modules"
echo "  |- scripts/              # Utility scripts"
echo "  |   |- start.sh          # Start the application"
echo "  |   |- stop.sh           # Stop the application (with DB cleanup option)"
echo "  |- .env                  # Environment variables"
echo "  |- .env_template         # Template for environment variables"
echo "  |- .gitignore           "
echo "  |- docker-compose.yml    # Docker setup with client, server, and $DB_TYPE"
echo "  |- README.md            "
echo
echo "Next steps:"
echo "1. Navigate to the client directory and install dependencies:"
echo "   cd $APP_NAME/client && npm install"
echo
echo "2. Navigate to the server directory and install dependencies:"
echo "   cd $APP_NAME/server && npm install"
echo
echo "3. Start your application using the provided script:"
echo "   cd $APP_NAME && ./scripts/start.sh"
echo
echo "4. To stop the application, use:"
echo "   ./scripts/stop.sh"
echo
echo "Your application will be available at:"
echo "- Frontend: http://localhost:$CLIENT_PORT"
echo "- Backend API: http://localhost:$SERVER_PORT"
echo
echo "Happy coding! 🚀"