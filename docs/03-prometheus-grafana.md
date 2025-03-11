# Prometheus and Grafana Monitoring Setup

This guide will walk you through setting up a comprehensive monitoring solution for your home server using Prometheus, Grafana, and Alert Manager. This stack will allow you to:

- Collect metrics from your server and services
- Visualize performance data with customizable dashboards
- Set up alerts for critical events
- Monitor system health and resource usage

## Directory Structure

First, ensure you have the proper directory structure:

```bash
mkdir -p ~/docker/monitoring/prometheus/config
mkdir -p ~/docker/monitoring/grafana
mkdir -p ~/docker/monitoring/alertmanager/config
mkdir -p ~/docker/monitoring/node-exporter
```

## Prometheus Setup

Prometheus is an open-source systems monitoring and alerting toolkit. It collects and stores metrics as time series data.

### Prometheus Configuration

Create the Prometheus configuration file:

```bash
nano ~/docker/monitoring/prometheus/config/prometheus.yml
```

Add the following content:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "cadvisor"
    static_configs:
      - targets: ["cadvisor:8080"]

  - job_name: "nginx-proxy-manager"
    static_configs:
      - targets: ["nginx-proxy-manager:81"]
    metrics_path: /metrics
    
  - job_name: "loki"
    static_configs:
      - targets: ["loki:3100"]
```

Create a directory for alert rules:

```bash
mkdir -p ~/docker/monitoring/prometheus/config/rules
```

Create a basic alert rules file:

```bash
nano ~/docker/monitoring/prometheus/config/rules/alerts.yml
```

Add the following content:

```yaml
groups:
  - name: basic_alerts
    rules:
      - alert: HighCPULoad
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU load (instance {{ $labels.instance }})"
          description: "CPU load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

      - alert: HighMemoryLoad
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory load (instance {{ $labels.instance }})"
          description: "Memory load is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes{fstype!="tmpfs"} - node_filesystem_free_bytes{fstype!="tmpfs"}) / node_filesystem_size_bytes{fstype!="tmpfs"} * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage (instance {{ $labels.instance }})"
          description: "Disk usage is > 80%\n  VALUE = {{ $value }}\n  LABELS: {{ $labels }}"
```

## Alert Manager Setup

Alert Manager handles alerts sent by Prometheus and routes them to the appropriate receiver.

Create the Alert Manager configuration file:

```bash
nano ~/docker/monitoring/alertmanager/config/alertmanager.yml
```

Add the following content (customize with your email or Slack details):

```yaml
global:
  resolve_timeout: 5m
  # For email alerts
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'  # Use app password for Gmail
  smtp_require_tls: true

# Route all alerts to all receivers
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'email-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'slack-notifications'
      continue: true

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'your-email@gmail.com'
        send_resolved: true
  
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        send_resolved: true
        title: "{{ .GroupLabels.alertname }}"
        text: "{{ range .Alerts }}{{ .Annotations.description }}\n{{ end }}"

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```

## Node Exporter Setup

Node Exporter collects hardware and OS metrics from the host system.

## Docker Compose Configuration

Create a docker-compose.yml file for the monitoring stack:

```bash
nano ~/docker/monitoring/docker-compose.yml
```

Add the following content:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/config:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - proxy
    profiles:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager/config:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    networks:
      - proxy
    profiles:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - proxy
    profiles:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    networks:
      - proxy
    profiles:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secure_password  # Change this!
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    networks:
      - proxy
    profiles:
      - monitoring

networks:
  proxy:
    external: true

volumes:
  prometheus_data:
  grafana_data:
```

## Starting the Monitoring Stack

Start the monitoring stack with Docker Compose:

```bash
cd ~/docker/monitoring
docker-compose --profile monitoring up -d
```

## Configuring Nginx Proxy Manager for Monitoring Services

Now, let's set up proxy hosts in Nginx Proxy Manager for each monitoring service:

### Prometheus

1. Go to "Hosts" > "Proxy Hosts" and click "Add Proxy Host"
2. Configure the following:
   - Domain Name: prometheus.yourdomain.com
   - Scheme: http
   - Forward Hostname / IP: prometheus
   - Forward Port: 9090
3. Under the "SSL" tab:
   - Select your SSL certificate
   - Force SSL: Enabled
4. Under the "Advanced" tab, add the Authelia configuration (from the previous guide)
5. Click "Save"

### Grafana

1. Go to "Hosts" > "Proxy Hosts" and click "Add Proxy Host"
2. Configure the following:
   - Domain Name: grafana.yourdomain.com
   - Scheme: http
   - Forward Hostname / IP: grafana
   - Forward Port: 3000
3. Under the "SSL" tab:
   - Select your SSL certificate
   - Force SSL: Enabled
4. Under the "Advanced" tab, add the Authelia configuration
5. Click "Save"

### Alert Manager

1. Go to "Hosts" > "Proxy Hosts" and click "Add Proxy Host"
2. Configure the following:
   - Domain Name: alerts.yourdomain.com
   - Scheme: http
   - Forward Hostname / IP: alertmanager
   - Forward Port: 9093
3. Under the "SSL" tab:
   - Select your SSL certificate
   - Force SSL: Enabled
4. Under the "Advanced" tab, add the Authelia configuration
5. Click "Save"

## Configuring Grafana

1. Access Grafana at https://grafana.yourdomain.com
2. Log in with the default credentials:
   - Username: admin
   - Password: secure_password (the one you set in docker-compose.yml)
3. You'll be prompted to change the default password

### Adding Prometheus as a Data Source

1. Go to "Configuration" > "Data Sources"
2. Click "Add data source"
3. Select "Prometheus"
4. Set the URL to http://prometheus:9090
5. Click "Save & Test"

### Importing Dashboards

Let's import some useful dashboards:

1. Go to "Create" > "Import"
2. Enter one of these dashboard IDs:
   - 1860 (Node Exporter Full)
   - 893 (Docker and System Monitoring)
   - 10619 (Docker Monitoring)
3. Click "Load"
4. Select "Prometheus" as the data source
5. Click "Import"

Repeat for each dashboard ID.

## Creating Custom Alerts

You can create custom alerts in Grafana:

1. Go to "Alerting" in the left sidebar
2. Click "New alert rule"
3. Configure your alert conditions
4. Set notification channels (email, Slack, etc.)
5. Save the alert

## Testing Alerts

To test if your alerts are working:

1. For CPU alerts: Run a stress test
   ```bash
   sudo apt install stress
   stress --cpu 8 --timeout 300
   ```

2. For disk space alerts: Create a large file
   ```bash
   fallocate -l 10G /tmp/large_file
   ```

3. Check Alert Manager at https://alerts.yourdomain.com to see if alerts are triggered

## Troubleshooting

### Prometheus Issues

- Check logs: `docker logs prometheus`
- Verify prometheus.yml syntax
- Check if targets are up in the Prometheus UI (Status > Targets)

### Grafana Issues

- Check logs: `docker logs grafana`
- Verify data source connection
- Check permissions on grafana_data volume

### Alert Manager Issues

- Check logs: `docker logs alertmanager`
- Verify alertmanager.yml syntax
- Test email or Slack notifications manually

## Next Steps

Now that you have your monitoring stack set up, you can proceed to the next section to configure Loki and Promtail for centralized logging.
