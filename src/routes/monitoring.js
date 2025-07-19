const express = require('express');
const router = express.Router();
const prometheus = require('../utils/prometheus');

// Prometheus metrics endpoint
router.get('/', async (req, res) => {
  try {
    const metrics = await prometheus.register.metrics();
    res.set('Content-Type', prometheus.register.contentType);
    res.end(metrics);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to collect metrics',
      message: error.message
    });
  }
});

// Custom metrics endpoint
router.get('/custom', (req, res) => {
  try {
    const customMetrics = {
      http_requests_total: prometheus.httpRequestsTotal.get(),
      http_request_duration_seconds: prometheus.httpRequestDuration.get(),
      application_info: {
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        uptime_seconds: process.uptime(),
        start_time: new Date(Date.now() - process.uptime() * 1000).toISOString()
      },
      system_metrics: {
        memory_usage_bytes: process.memoryUsage(),
        cpu_usage: process.cpuUsage(),
        event_loop_lag: prometheus.eventLoopLag.get()
      }
    };

    res.json(customMetrics);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to collect custom metrics',
      message: error.message
    });
  }
});

module.exports = router;
