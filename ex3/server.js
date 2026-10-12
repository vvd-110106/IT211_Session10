const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Root endpoint: Application and architecture status
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'success',
    service: 'hw-backend',
    version: '1.0.0',
    buildType: process.env.BUILD_TYPE || 'Multi-stage Build (Alpine)',
    message: 'DevOps Session 10 - Exercise 3: Web Backend API is running stably!',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint for Docker HEALTHCHECK and monitoring
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    uptimeSeconds: Math.floor(process.uptime()),
    nodeVersion: process.version,
    memoryUsage: process.memoryUsage(),
    timestamp: Date.now()
  });
});

// Sample business API endpoint
app.get('/api/items', (req, res) => {
  res.status(200).json({
    total: 3,
    data: [
      { id: 1, name: 'Docker Layer Caching Optimization', status: 'Active' },
      { id: 2, name: 'Multi-stage Build Pipeline', status: 'Completed' },
      { id: 3, name: 'Lightweight Alpine Runtime', status: 'Verified' }
    ]
  });
});

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[INFO] Server started successfully on port ${PORT}`);
  console.log(`[INFO] Environment: ${process.env.NODE_ENV || 'production'}`);
  console.log(`[INFO] Process ID: ${process.pid}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[INFO] SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('[INFO] HTTP server closed cleanly');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('[INFO] SIGINT signal received: closing HTTP server');
  server.close(() => {
    console.log('[INFO] HTTP server closed cleanly');
    process.exit(0);
  });
});
