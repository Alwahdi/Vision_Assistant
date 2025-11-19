/**
 * API routes for Vision Assistant API Gateway
 */

import express from 'express';
import axios from 'axios';

const router = express.Router();

// Service URLs from environment
const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';
const REALTIME_SERVICE_URL = process.env.REALTIME_SERVICE_URL || 'http://localhost:3001';
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:3002';
const CONTENT_SERVICE_URL = process.env.CONTENT_SERVICE_URL || 'http://localhost:3003';

// Proxy middleware helper
const createProxyMiddleware = (targetUrl) => {
  return async (req, res, next) => {
    try {
      const url = `${targetUrl}${req.path}`;
      const method = req.method.toLowerCase();

      const response = await axios({
        method,
        url,
        data: req.body,
        headers: {
          ...req.headers,
          'x-forwarded-for': req.ip,
          'x-forwarded-host': req.hostname,
          'x-forwarded-proto': req.protocol,
        },
        params: req.query,
        timeout: 30000,
      });

      res.status(response.status).json(response.data);
    } catch (error) {
      if (error.response) {
        // Service returned an error
        res.status(error.response.status).json(error.response.data);
      } else if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
        // Service is not available
        res.status(503).json({
          error: 'Service Unavailable',
          message: 'The requested service is currently unavailable',
          timestamp: new Date().toISOString(),
        });
      } else {
        // Other errors
        console.error('Proxy error:', error);
        res.status(500).json({
          error: 'Internal Server Error',
          message: 'An unexpected error occurred',
          timestamp: new Date().toISOString(),
        });
      }
    }
  };
};

// AI Service routes
router.use('/ai', createProxyMiddleware(AI_SERVICE_URL));

// Real-time Service routes
router.use('/realtime', createProxyMiddleware(REALTIME_SERVICE_URL));

// User Service routes
router.use('/users', createProxyMiddleware(USER_SERVICE_URL));

// Content Service routes
router.use('/content', createProxyMiddleware(CONTENT_SERVICE_URL));

// API information
router.get('/', (req, res) => {
  res.json({
    name: 'Vision Assistant API Gateway',
    version: '1.0.0',
    description: 'Unified API gateway for Vision Assistant platform',
    services: {
      ai: `${AI_SERVICE_URL}/docs`,
      realtime: `${REALTIME_SERVICE_URL}/docs`,
      users: `${USER_SERVICE_URL}/docs`,
      content: `${CONTENT_SERVICE_URL}/docs`,
    },
    documentation: '/api/docs',
    health: '/health',
    timestamp: new Date().toISOString(),
  });
});

// API documentation redirect
router.get('/docs', (req, res) => {
  res.redirect('/api/docs');
});

// API version
router.get('/version', (req, res) => {
  res.json({
    version: '1.0.0',
    build: process.env.BUILD_SHA || 'development',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
  });
});

// API status
router.get('/status', async (req, res) => {
  const services = [
    { name: 'ai-service', url: `${AI_SERVICE_URL}/health` },
    { name: 'realtime-service', url: `${REALTIME_SERVICE_URL}/health` },
    { name: 'user-service', url: `${USER_SERVICE_URL}/health` },
    { name: 'content-service', url: `${CONTENT_SERVICE_URL}/health` },
  ];

  const status = {
    gateway: 'healthy',
    timestamp: new Date().toISOString(),
    services: {},
  };

  for (const service of services) {
    try {
      const response = await axios.get(service.url, { timeout: 5000 });
      status.services[service.name] = {
        status: response.data.status === 'healthy' ? 'healthy' : 'unhealthy',
        response_time: response.data.response_time || 'unknown',
      };
    } catch (error) {
      status.services[service.name] = {
        status: 'unhealthy',
        error: error.message,
      };
    }
  }

  // Determine overall status
  const hasUnhealthy = Object.values(status.services).some(s => s.status === 'unhealthy');
  if (hasUnhealthy) {
    status.gateway = 'degraded';
  }

  res.json(status);
});

export default router;
