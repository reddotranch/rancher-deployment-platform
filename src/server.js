const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const winston = require('winston');
const cron = require('node-cron');
require('dotenv').config();

// Import modules
const healthRoutes = require('./routes/health');
const apiRoutes = require('./routes/api');
const rancherRoutes = require('./routes/rancher');
const monitoringRoutes = require('./routes/monitoring');
const { errorHandler } = require('./middleware/errorHandler');
const { rateLimiter } = require('./middleware/rateLimiter');
const { authMiddleware } = require('./middleware/auth');
const logger = require('./utils/logger');
const database = require('./utils/database');
const prometheus = require('./utils/prometheus');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 8080;

// Configure logger
const appLogger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'rancher-platform' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
});

// Global error handling for uncaught exceptions
process.on('uncaughtException', (error) => {
  appLogger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  appLogger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true,
}));

app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    appLogger.info('HTTP Request', {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
});

// Rate limiting
app.use(rateLimiter);

// Prometheus metrics collection
app.use(prometheus.middleware);

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// Routes
app.use('/health', healthRoutes);
app.use('/api/v1', authMiddleware, apiRoutes);
app.use('/api/v1/rancher', authMiddleware, rancherRoutes);
app.use('/metrics', monitoringRoutes);

// Root route - serve UI or API response based on Accept header
app.get('/', (req, res) => {
  // If the request accepts HTML (browser), serve the UI
  if (req.accepts('html') && !req.accepts('json')) {
    res.sendFile(path.join(__dirname, '../public/index.html'));
  } else {
    // Otherwise, serve JSON API response
    res.json({
      name: 'Rancher Deployment Platform',
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      status: 'running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      features: {
        monitoring: process.env.ENABLE_MONITORING === 'true',
        backup: process.env.ENABLE_BACKUP === 'true',
        security: process.env.ENABLE_SECURITY_SCAN === 'true',
        autoScaling: process.env.ENABLE_AUTO_SCALING === 'true'
      }
    });
  }
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl,
    method: req.method
  });
});

// Error handling middleware
app.use(errorHandler);

// Initialize database connection
async function initializeDatabase() {
  try {
    await database.connect();
    appLogger.info('Database connection established successfully');
  } catch (error) {
    appLogger.error('Failed to connect to database:', error);
    process.exit(1);
  }
}

// Scheduled tasks
function initializeScheduledTasks() {
  // Health check task - every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    try {
      const healthStatus = await database.healthCheck();
      appLogger.info('Scheduled health check completed', { status: healthStatus });
    } catch (error) {
      appLogger.error('Scheduled health check failed:', error);
    }
  });

  // Cleanup task - daily at 2 AM
  cron.schedule('0 2 * * *', async () => {
    try {
      appLogger.info('Running daily cleanup tasks');
      // Add cleanup logic here
    } catch (error) {
      appLogger.error('Daily cleanup task failed:', error);
    }
  });

  // Metrics collection - every minute
  cron.schedule('* * * * *', async () => {
    try {
      await prometheus.collectCustomMetrics();
    } catch (error) {
      appLogger.error('Metrics collection failed:', error);
    }
  });

  appLogger.info('Scheduled tasks initialized');
}

// Global server reference
let httpServer = null;

// Graceful shutdown
function gracefulShutdown(signal) {
  appLogger.info(`Received ${signal}, shutting down gracefully...`);
  
  if (httpServer) {
    httpServer.close(() => {
      appLogger.info('HTTP server closed');
      
      // Close database connection
      database.disconnect()
        .then(() => {
          appLogger.info('Database connection closed');
          process.exit(0);
        })
        .catch((error) => {
          appLogger.error('Error closing database connection:', error);
          process.exit(1);
        });
    });
  } else {
    process.exit(0);
  }

  // Force close after 30 seconds
  setTimeout(() => {
    appLogger.error('Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 30000);
}

// Start server
async function startServer() {
  try {
    // Initialize database
    await initializeDatabase();
    
    // Initialize scheduled tasks
    initializeScheduledTasks();
    
    // Start HTTP server
    httpServer = app.listen(PORT, '0.0.0.0', () => {
      appLogger.info(`Rancher Deployment Platform server started on port ${PORT}`, {
        environment: process.env.NODE_ENV,
        version: process.env.npm_package_version || '1.0.0',
        pid: process.pid
      });
    });

    // Graceful shutdown handlers
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    return httpServer;
  } catch (error) {
    appLogger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Start the application
if (require.main === module) {
  startServer();
}

module.exports = app;
