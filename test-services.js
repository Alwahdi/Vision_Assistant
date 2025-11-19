#!/usr/bin/env node

/**
 * Vision Assistant - Service Tester
 * Simple test to verify services are working
 */

import http from 'http';

const services = [
    { name: 'API Gateway', url: 'http://localhost:3000/health', port: 3000 },
    { name: 'AI Service', url: 'http://localhost:8000/health', port: 8000 },
    { name: 'Realtime Service', url: 'http://localhost:3001/health', port: 3001 },
];

function testService(service) {
    return new Promise((resolve) => {
        const req = http.get(service.url, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    resolve({
                        name: service.name,
                        status: res.statusCode === 200 ? '✅ Running' : '⚠️  Warning',
                        code: res.statusCode,
                        response: response.status || 'unknown'
                    });
                } catch (e) {
                    resolve({
                        name: service.name,
                        status: '❌ Error',
                        code: res.statusCode,
                        response: 'invalid json'
                    });
                }
            });
        });

        req.on('error', (err) => {
            resolve({
                name: service.name,
                status: '❌ Not Running',
                code: null,
                response: err.code
            });
        });

        req.setTimeout(5000, () => {
            req.destroy();
            resolve({
                name: service.name,
                status: '⏰ Timeout',
                code: null,
                response: 'timeout'
            });
        });
    });
}

async function testAllServices() {
    console.log('🔍 Testing Vision Assistant Services');
    console.log('=====================================\n');

    const results = await Promise.all(services.map(testService));

    results.forEach(result => {
        console.log(`${result.name}: ${result.status}`);
        if (result.code) {
            console.log(`  Status Code: ${result.code}`);
        }
        console.log(`  Response: ${result.response}`);
        console.log('');
    });

    const running = results.filter(r => r.status.includes('✅')).length;
    const total = results.length;

    console.log(`📊 Summary: ${running}/${total} services running`);
    console.log('');

    if (running === total) {
        console.log('🎉 All services are running successfully!');
    } else if (running > 0) {
        console.log('⚠️  Some services are running, others need attention.');
    } else {
        console.log('❌ No services are currently running.');
        console.log('\n💡 Try running:');
        console.log('   ./run-services.sh start');
        console.log('   or');
        console.log('   ./deploy-local.sh start');
    }
}

// Run the test
testAllServices().catch(console.error);
