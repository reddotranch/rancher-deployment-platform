const client = require('prom-client');

// Create a Registry
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  registers: [register]
});

const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

const rancherClusters = new client.Gauge({
  name: 'rancher_clusters_total',
  help: 'Total number of Rancher clusters',
  registers: [register]
});

const kubernetesNodes = new client.Gauge({
  name: 'kubernetes_nodes_total',
  help: 'Total number of Kubernetes nodes',
  labelNames: ['cluster', 'status'],
  registers: [register]
});

// Middleware function to collect HTTP metrics
const middleware = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode
    });
    
    httpRequestDuration.observe({
      method: req.method,
      route: route
    }, duration);
  });
  
  next();
};

// Function to collect custom metrics
const collectCustomMetrics = async () => {
  try {
    // Update active connections (placeholder)
    activeConnections.set(Math.floor(Math.random() * 100));
    
    // Update Rancher clusters (placeholder)
    rancherClusters.set(Math.floor(Math.random() * 10));
    
    // Update Kubernetes nodes (placeholder)
    kubernetesNodes.set({ cluster: 'default', status: 'ready' }, Math.floor(Math.random() * 20));
    kubernetesNodes.set({ cluster: 'default', status: 'not_ready' }, Math.floor(Math.random() * 5));
    
    return true;
  } catch (error) {
    throw new Error(`Failed to collect custom metrics: ${error.message}`);
  }
};

module.exports = {
  register,
  middleware,
  collectCustomMetrics,
  httpRequestsTotal,
  httpRequestDuration,
  activeConnections,
  rancherClusters,
  kubernetesNodes
};
