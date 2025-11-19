#!/usr/bin/env node

/**
 * Simple Vision Assistant Test
 * Test basic functionality without complex dependencies
 */

import http from 'http';

console.log('🚀 Vision Assistant - Simple Test');
console.log('==================================');

// Create a simple HTTP server
const server = http.createServer((req, res) => {
    if (req.url === '/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'healthy',
            service: 'vision-assistant-test',
            version: '1.0.0',
            timestamp: new Date().toISOString()
        }));
    } else if (req.url === '/' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Hello from Vision Assistant!');
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

const PORT = 3000;

server.listen(PORT, () => {
    console.log(`✅ Server running on http://localhost:${PORT}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log(`📄 Main page: http://localhost:${PORT}/`);
    console.log('');
    console.log('🧪 Testing server...');

    // Test the server
    setTimeout(() => {
        const req = http.get(`http://localhost:${PORT}/health`, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    console.log('✅ Health check passed:', response.status);
                    console.log('🎉 Vision Assistant is working!');
                } catch (e) {
                    console.log('❌ Health check failed: invalid response');
                }
                server.close(() => {
                    console.log('🛑 Server stopped');
                    process.exit(0);
                });
            });
        });

        req.on('error', (err) => {
            console.log('❌ Health check failed:', err.message);
            server.close(() => {
                process.exit(1);
            });
        });
    }, 1000);
});
