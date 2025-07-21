const express = require('express');
const router = express.Router();

// API routes for the Rancher platform
router.get('/', (req, res) => {
  res.json({
    message: 'Rancher Deployment Platform API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      metrics: '/metrics',
      rancher: '/rancher',
      clusters: '/clusters'
    }
  });
});

// Get platform status
router.get('/status', (req, res) => {
  res.json({
    status: 'operational',
    timestamp: new Date().toISOString(),
    services: {
      api: 'healthy',
      database: 'healthy',
      monitoring: 'healthy'
    }
  });
});

// Get version information
router.get('/version', (req, res) => {
  res.json({
    version: process.env.npm_package_version || '1.0.0',
    build: process.env.BUILD_NUMBER || 'local',
    commit: process.env.GIT_COMMIT || 'unknown',
    environment: process.env.NODE_ENV || 'development'
  });
});

module.exports = router;
