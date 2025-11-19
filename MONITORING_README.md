# 📊 Vision Assistant - Monitoring & Observability

Complete monitoring stack for the Vision Assistant application with Prometheus, Grafana, and comprehensive metrics collection.

## 🚀 Quick Start

### Start Monitoring Services
```bash
# Start all monitoring services
./start-monitoring.sh start

# Or start with main application
docker-compose up -d
```

### Access Monitoring Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3030 | admin / vision2024! |
| **Prometheus** | http://localhost:9090 | - |
| **Node Exporter** | http://localhost:9100 | - |
| **cAdvisor** | http://localhost:8080 | - |

## 📈 Available Metrics

### Application Metrics

#### API Gateway (`/metrics`)
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration histogram
- `nodejs_heap_size_used_bytes` - Node.js heap usage
- `nodejs_heap_size_total_bytes` - Total heap size
- `process_cpu_user_seconds_total` - CPU usage

#### AI Service (`/metrics`)
- `ai_service_requests_total` - Total AI service requests
- `ai_service_request_duration_seconds` - AI request latency
- `ai_processing_duration_seconds` - AI processing time
- Python process metrics

#### Real-time Service (`/metrics`)
- WebSocket connection metrics
- Redis pub/sub metrics
- Node.js performance metrics

### Infrastructure Metrics

#### System Metrics (Node Exporter)
- CPU usage and load
- Memory usage
- Disk I/O and space
- Network statistics
- System uptime

#### Container Metrics (cAdvisor)
- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage
- Container uptime

#### Database Metrics
- PostgreSQL connections
- Query performance
- Database size
- Redis memory usage
- Redis operations

## 📊 Grafana Dashboards

### Pre-configured Dashboard
The system includes a comprehensive dashboard that shows:

#### Service Health Panel
- Real-time status of all services
- Uptime monitoring
- Health check status

#### Performance Metrics
- HTTP request rates and latency
- Error rates and trends
- Response time percentiles (95th, 99th)

#### Resource Usage
- Container CPU and memory usage
- Database connection pools
- Redis memory usage
- Disk space monitoring

#### Application-Specific Metrics
- AI processing times
- Object detection accuracy
- User session metrics
- API usage patterns

### Importing the Dashboard

1. Open Grafana at http://localhost:3030
2. Login with admin/vision2024!
3. Go to **Dashboards** → **Import**
4. Upload `monitoring/grafana/dashboards/vision-assistant-dashboard.json`

## 🔧 Configuration Files

### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'api-gateway'
    static_configs:
      - targets: ['vision-assistant-api-gateway:3000']
    metrics_path: '/metrics'

  - job_name: 'ai-service'
    static_configs:
      - targets: ['vision-assistant-ai-service:8000']
    metrics_path: '/metrics'

  # ... more services
```

### Grafana Provisioning
- **Datasources**: `monitoring/grafana/provisioning/datasources/prometheus.yml`
- **Dashboards**: `monitoring/grafana/provisioning/dashboards/dashboards.yml`

## 📋 Monitoring Commands

### Service Management
```bash
# Start monitoring only
./start-monitoring.sh start

# Stop monitoring only
./start-monitoring.sh stop

# Restart monitoring
./start-monitoring.sh restart

# Check status
./start-monitoring.sh status
```

### View Logs
```bash
# View specific service logs
./start-monitoring.sh logs prometheus
./start-monitoring.sh logs grafana

# View all monitoring logs
docker-compose logs monitoring
```

### Health Checks
```bash
# Check all services health
curl http://localhost:3000/health
curl http://localhost:8000/health
curl http://localhost:3001/health

# Check monitoring services
curl http://localhost:9090/-/healthy
curl http://localhost:3030/api/health
```

## 🚨 Alerting (Future Enhancement)

### Planned Alerts
- Service down notifications
- High error rates
- Resource usage thresholds
- Performance degradation

### Alert Manager Setup
```yaml
# Future: monitoring/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@vision-assistant.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@vision-assistant.com'
```

## 📊 Custom Metrics Examples

### Adding Custom Metrics to Services

#### Node.js Services (API Gateway, Real-time)
```javascript
const client = require('prom-client');

// Counter example
const requestsTotal = new client.Counter({
  name: 'vision_requests_total',
  help: 'Total number of vision requests',
  labelNames: ['type', 'status']
});

// Histogram example
const processingTime = new client.Histogram({
  name: 'vision_processing_duration_seconds',
  help: 'Time spent processing vision requests',
  labelNames: ['operation']
});

// Usage
requestsTotal.labels('object_detection', 'success').inc();
processingTime.labels('face_recognition').observe(0.5);
```

#### Python Services (AI Service)
```python
from prometheus_client import Counter, Histogram

# Counter
ai_requests = Counter(
    'ai_requests_total',
    'Total AI processing requests',
    ['model', 'status']
)

# Histogram
processing_time = Histogram(
    'ai_processing_seconds',
    'AI processing time',
    ['operation']
)

# Usage
ai_requests.labels(model='yolo', status='success').inc()
processing_time.labels(operation='object_detection').observe(1.2)
```

## 🔍 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check logs
docker logs vision-assistant-prometheus

# Check if ports are available
netstat -tulpn | grep :9090
```

#### Metrics Not Appearing
```bash
# Check if service is reachable
curl http://localhost:3000/metrics

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

#### Grafana Not Loading Dashboard
```bash
# Restart Grafana
docker restart vision-assistant-grafana

# Check Grafana logs
docker logs vision-assistant-grafana
```

### Performance Tuning

#### Prometheus
- Adjust `scrape_interval` based on your needs
- Configure data retention: `--storage.tsdb.retention.time=200h`
- Use persistent storage for production

#### Grafana
- Enable caching for better performance
- Configure refresh intervals appropriately
- Use dashboard folders for organization

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)
- [cAdvisor Documentation](https://github.com/google/cadvisor)

## 🎯 Next Steps

1. **Add Alerting**: Configure AlertManager for notifications
2. **Log Aggregation**: Add Loki for centralized logging
3. **Tracing**: Add Jaeger for distributed tracing
4. **Custom Dashboards**: Create domain-specific dashboards
5. **Performance Monitoring**: Add APM (Application Performance Monitoring)

---

## 📞 Support

For issues with monitoring setup:
1. Check the logs: `./start-monitoring.sh logs [service]`
2. Verify service health: `curl http://localhost:[port]/health`
3. Check Prometheus targets: `http://localhost:9090/targets`
4. Review Grafana logs for dashboard issues

**Happy Monitoring! 🎉**
