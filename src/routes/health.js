const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');
const database = require('../utils/database');

// Health check endpoint
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    
    // Check database connection
    const dbHealth = await database.healthCheck();
    
    // Check memory usage
    const memoryUsage = process.memoryUsage();
    const memoryUsagePercent = (memoryUsage.rss / 1024 / 1024).toFixed(2);
    
    // Check uptime
    const uptime = process.uptime();
    
    const responseTime = Date.now() - startTime;
    
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      uptime: `${Math.floor(uptime / 60)} minutes`,
      responseTime: `${responseTime}ms`,
      memory: {
        used: `${memoryUsagePercent} MB`,
        heap: {
          used: `${(memoryUsage.heapUsed / 1024 / 1024).toFixed(2)} MB`,
          total: `${(memoryUsage.heapTotal / 1024 / 1024).toFixed(2)} MB`
        }
      },
      database: {
        status: dbHealth ? 'connected' : 'disconnected',
        responseTime: dbHealth ? dbHealth.responseTime : null
      },
      cpu: {
        usage: process.cpuUsage()
      }
    };

    // If any critical service is down, return 503
    if (!dbHealth) {
      healthStatus.status = 'unhealthy';
      return res.status(503).json(healthStatus);
    }

    res.json(healthStatus);
  } catch (error) {
    logger.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Readiness probe
router.get('/ready', async (req, res) => {
  try {
    // Check if application is ready to serve traffic
    const dbReady = await database.isReady();
    
    if (dbReady) {
      res.json({
        status: 'ready',
        timestamp: new Date().toISOString(),
        services: {
          database: 'ready'
        }
      });
    } else {
      res.status(503).json({
        status: 'not ready',
        timestamp: new Date().toISOString(),
        services: {
          database: 'not ready'
        }
      });
    }
  } catch (error) {
    logger.error('Readiness check failed:', error);
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Liveness probe
router.get('/live', (req, res) => {
  // Simple liveness check - if the process is running, it's alive
  res.json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    pid: process.pid,
    uptime: process.uptime()
  });
});

// Detailed health information
router.get('/detailed', async (req, res) => {
  try {
    const healthInfo = {
      application: {
        name: 'Rancher Deployment Platform',
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        nodeVersion: process.version,
        platform: process.platform,
        architecture: process.arch,
        pid: process.pid,
        uptime: process.uptime(),
        startTime: new Date(Date.now() - process.uptime() * 1000).toISOString()
      },
      system: {
        memory: process.memoryUsage(),
        cpu: process.cpuUsage(),
        loadAverage: require('os').loadavg(),
        freeMemory: require('os').freemem(),
        totalMemory: require('os').totalmem(),
        hostname: require('os').hostname()
      },
      services: {
        database: await database.getDetailedHealth(),
        // Add other service health checks here
      },
      features: {
        monitoring: process.env.ENABLE_MONITORING === 'true',
        backup: process.env.ENABLE_BACKUP === 'true',
        security: process.env.ENABLE_SECURITY_SCAN === 'true',
        autoScaling: process.env.ENABLE_AUTO_SCALING === 'true'
      },
      timestamp: new Date().toISOString()
    };

    res.json(healthInfo);
  } catch (error) {
    logger.error('Detailed health check failed:', error);
    res.status(500).json({
      error: 'Failed to get detailed health information',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;
