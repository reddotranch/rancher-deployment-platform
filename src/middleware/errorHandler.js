const logger = require('../utils/logger');

// Error handling middleware
const errorHandler = (err, req, res, next) => {
  logger.error(err.stack);

  // Default error response
  let error = {
    message: err.message || 'Internal Server Error',
    status: err.status || 500
  };

  // Include stack trace in development
  if (process.env.NODE_ENV === 'development') {
    error.stack = err.stack;
  }

  res.status(error.status).json({ error });
};

// 404 handler
const notFoundHandler = (req, res) => {
  res.status(404).json({
    error: {
      message: 'Route not found',
      status: 404,
      path: req.path
    }
  });
};

module.exports = {
  errorHandler,
  notFoundHandler
};
