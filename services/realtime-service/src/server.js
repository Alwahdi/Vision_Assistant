#!/usr/bin/env node

/**
 * Vision Assistant - Real-time Service
 * WebSocket server for real-time communication
 */

import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { createClient } from 'redis';
import jwt from 'jsonwebtoken';
import { register, collectDefaultMetrics } from 'prom-client';

// Load environment variables
dotenv.config();

// Create Express app
const app = express();
const server = createServer(app);

// Initialize Socket.IO
const io = new Server(server, {
  cors: {
    origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true,
  },
  transports: ['websocket', 'polling'],
});

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));
app.use(compression());
app.use(express.json());

// Logging
if (process.env.NODE_ENV === 'production') {
  app.use(morgan('combined'));
} else {
  app.use(morgan('dev'));
}

// Prometheus metrics
collectDefaultMetrics();

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'vision-assistant-realtime-service',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

// Readiness probe
app.get('/ready', (req, res) => {
  res.json({
    status: 'ready',
    service: 'vision-assistant-realtime-service',
    timestamp: new Date().toISOString(),
  });
});

// Liveness probe
app.get('/live', (req, res) => {
  res.json({
    status: 'alive',
    service: 'vision-assistant-realtime-service',
    timestamp: new Date().toISOString(),
  });
});

// Redis client for pub/sub
let redisClient;
try {
  redisClient = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  });

  redisClient.on('error', (err) => {
    console.error('Redis Client Error:', err);
  });

  redisClient.on('connect', () => {
    console.log('Connected to Redis');
  });

  await redisClient.connect();
} catch (error) {
  console.error('Failed to connect to Redis:', error);
}

// Socket.IO connection handling
io.use(async (socket, next) => {
  try {
    // Authentication middleware
    const token = socket.handshake.auth.token;

    if (!token) {
      return next(new Error('Authentication token required'));
    }

    // Verify JWT token (placeholder - implement proper verification)
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'development-secret');
      socket.userId = decoded.userId;
      socket.username = decoded.username;
      next();
    } catch (err) {
      return next(new Error('Invalid authentication token'));
    }
  } catch (error) {
    next(new Error('Authentication failed'));
  }
});

io.on('connection', (socket) => {
  console.log(`User ${socket.userId} connected: ${socket.id}`);

  // Join user-specific room
  socket.join(`user:${socket.userId}`);

  // Handle vision processing results
  socket.on('vision:process', async (data) => {
    try {
      console.log(`Vision processing request from user ${socket.userId}:`, data);

      // Emit processing started
      socket.emit('vision:processing_started', {
        requestId: data.requestId,
        timestamp: new Date().toISOString(),
      });

      // In a real implementation, this would call the AI service
      // For now, emit mock results after a delay
      setTimeout(() => {
        socket.emit('vision:results', {
          requestId: data.requestId,
          results: [
            {
              object: 'person',
              confidence: 0.95,
              boundingBox: { x: 10, y: 20, width: 100, height: 200 },
            }
          ],
          processingTime: 1.2,
          timestamp: new Date().toISOString(),
        });
      }, 1000);

    } catch (error) {
      console.error('Vision processing error:', error);
      socket.emit('vision:error', {
        requestId: data.requestId,
        error: 'Processing failed',
        timestamp: new Date().toISOString(),
      });
    }
  });

  // Handle navigation updates
  socket.on('navigation:update', (data) => {
    console.log(`Navigation update from user ${socket.userId}:`, data);

    // Broadcast to user's room (for multiple devices)
    socket.to(`user:${socket.userId}`).emit('navigation:updated', {
      ...data,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle voice commands
  socket.on('voice:command', (data) => {
    console.log(`Voice command from user ${socket.userId}:`, data);

    // Process voice command and emit response
    socket.emit('voice:response', {
      command: data.command,
      response: `Processed command: ${data.command}`,
      confidence: 0.92,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle disconnection
  socket.on('disconnect', (reason) => {
    console.log(`User ${socket.userId} disconnected: ${reason}`);
  });

  // Handle errors
  socket.on('error', (error) => {
    console.error(`Socket error for user ${socket.userId}:`, error);
  });
});

// Periodic health broadcast
setInterval(() => {
  io.emit('health', {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    connectedClients: io.engine.clientsCount,
  });
}, 30000);

// Start server
const PORT = process.env.PORT || 3001;

server.listen(PORT, () => {
  console.log(`🚀 Vision Assistant Real-time Service listening on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔌 WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM received, shutting down gracefully');
  server.close(async () => {
    console.log('✅ Server closed');
    if (redisClient) {
      await redisClient.quit();
    }
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 SIGINT received, shutting down gracefully');
  server.close(async () => {
    console.log('✅ Server closed');
    if (redisClient) {
      await redisClient.quit();
    }
    process.exit(0);
  });
});

export default app;