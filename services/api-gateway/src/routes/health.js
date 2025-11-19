/**
 * Health check routes for API Gateway
 */

import express from 'express';
import responseTime from 'response-time';

const router = express.Router();

// Add response time tracking
router.use(responseTime());

// Basic health check
router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'vision-assistant-api-gateway',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

// Detailed health check
router.get('/detailed', async (req, res) => {
  const health = {
    status: 'healthy',
    service: 'vision-assistant-api-gateway',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    checks: {},
  };

  // Check memory usage
  const memUsage = process.memoryUsage();
  health.checks.memory = {
    status: memUsage.heapUsed < memUsage.heapTotal * 0.9 ? 'healthy' : 'warning',
    used: Math.round(memUsage.heapUsed / 1024 / 1024),
    total: Math.round(memUsage.heapTotal / 1024 / 1024),
    unit: 'MB',
  };

  // Check database connectivity (placeholder)
  health.checks.database = {
    status: 'unknown',
    message: 'Database connectivity check not implemented yet',
  };

  // Check Redis connectivity (placeholder)
  health.checks.redis = {
    status: 'unknown',
    message: 'Redis connectivity check not implemented yet',
  };

  // Check external services (placeholder)
  health.checks.external_services = {
    status: 'unknown',
    message: 'External service checks not implemented yet',
  };

  // Determine overall status
  const hasFailures = Object.values(health.checks).some(check =>
    check.status === 'unhealthy' || check.status === 'error'
  );

  if (hasFailures) {
    health.status = 'unhealthy';
    res.status(503);
  }

  res.json(health);
});

// Readiness probe
router.get('/ready', (req, res) => {
  // In a real application, check if the service is ready to accept traffic
  // This might include checking database connections, external services, etc.
  res.json({
    status: 'ready',
    service: 'vision-assistant-api-gateway',
    timestamp: new Date().toISOString(),
  });
});

// Liveness probe
router.get('/live', (req, res) => {
  res.json({
    status: 'alive',
    service: 'vision-assistant-api-gateway',
    timestamp: new Date().toISOString(),
  });
});

export default router;
