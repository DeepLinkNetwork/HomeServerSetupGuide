# Loki and Promtail Logging Setup

This guide will walk you through setting up a centralized logging solution for your home server using Loki and Promtail. This stack will allow you to:

- Collect logs from your server and services
- Store logs efficiently with Loki
- Query and analyze logs through Grafana
- Set up alerts based on log patterns
- Troubleshoot issues across your entire infrastructure

## Directory Structure

First, ensure you have the proper directory structure:

```bash
mkdir -p ~/docker/logging/loki/config
mkdir -p ~/docker/logging/promtail/config
```

## Loki Setup

Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus. It's designed to be very cost-effective and easy to operate.

### Loki Configuration

Create the Loki configuration file:

```bash
nano ~/docker/logging/loki/config/loki-config.yml
```

Add the following content:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

analytics:
  reporting_enabled: false
```

## Promtail Setup

Promtail is an agent which ships the contents of local logs to a Loki instance.

### Promtail Configuration

Create the Promtail configuration file:

```bash
nano ~/docker/logging/promtail/config/promtail-config.yml
```

Add the following content:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*log

  - job_name: nginx
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          __path__: /var/log/nginx/*log

  - job_name: authelia
    static_configs:
      - targets:
          - localhost
        labels:
          job: authelia
          __path__: /home/ubuntu/docker/authelia/config/notification.txt
```

## Docker Compose Configuration

Create a docker-compose.yml file for the logging stack:

```bash
nano ~/docker/logging/docker-compose.yml
```

Add the following content:

```yaml
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ./loki/config:/etc/loki
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    ports:
      - "3100:3100"
    networks:
      - proxy
    profiles:
      - logging

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./promtail/config:/etc/promtail
      - /var/log:/var/log
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /home/ubuntu/docker:/home/ubuntu/docker:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    ports:
      - "9080:9080"
    networks:
      - proxy
    profiles:
      - logging

networks:
  proxy:
    external: true

volumes:
  loki_data:
```

## Starting the Logging Stack

Start the logging stack with Docker Compose:

```bash
cd ~/docker/logging
docker-compose --profile logging up -d
```

## Configuring Nginx Proxy Manager for Loki

Set up a proxy host in Nginx Proxy Manager for Loki:

1. Go to "Hosts" > "Proxy Hosts" and click "Add Proxy Host"
2. Configure the following:
   - Domain Name: loki.yourdomain.com
   - Scheme: http
   - Forward Hostname / IP: loki
   - Forward Port: 3100
3. Under the "SSL" tab:
   - Select your SSL certificate
   - Force SSL: Enabled
4. Under the "Advanced" tab, add the Authelia configuration (from the previous guide)
5. Click "Save"

## Integrating Loki with Grafana

Now, let's add Loki as a data source in Grafana:

1. Access Grafana at https://grafana.yourdomain.com
2. Go to "Configuration" > "Data Sources"
3. Click "Add data source"
4. Select "Loki"
5. Set the URL to http://loki:3100
6. Click "Save & Test"

## Creating Log Dashboards in Grafana

Let's create a basic log dashboard:

1. Go to "Create" > "Dashboard"
2. Click "Add new panel"
3. Select "Loki" as the data source
4. In the query field, enter a LogQL query:
   ```
   {job="varlogs"}
   ```
5. Adjust the time range as needed
6. Click "Apply"

### Importing Log Dashboards

You can also import pre-made dashboards:

1. Go to "Create" > "Import"
2. Enter dashboard ID 13639 (Loki Dashboard)
3. Click "Load"
4. Select "Loki" as the data source
5. Click "Import"

## Advanced Log Queries

Loki uses LogQL, a query language inspired by PromQL. Here are some useful queries:

### Filter by Log Content

```
{job="docker"} |= "error"
```

This shows all logs from the "docker" job containing the word "error".

### Filter by Regular Expression

```
{job="nginx"} |~ "GET /api/.*"
```

This shows all logs from the "nginx" job matching the regular expression.

### Count Error Occurrences

```
count_over_time({job="varlogs"} |= "error"[1h])
```

This counts how many times "error" appears in the logs over the last hour.

## Setting Up Log-Based Alerts

You can set up alerts based on log patterns:

1. In Grafana, go to "Alerting" > "New alert rule"
2. Configure a Loki query, for example:
   ```
   count_over_time({job="varlogs"} |= "error"[5m]) > 10
   ```
3. This will alert if there are more than 10 errors in 5 minutes
4. Set notification channels and save the alert

## Log Retention and Management

By default, Loki will retain logs based on the configuration in the `limits_config` section. You can adjust the retention period by modifying the `reject_old_samples_max_age` value.

For example, to keep logs for 30 days:

```yaml
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 720h  # 30 days
```

## Troubleshooting

### Loki Issues

- Check logs: `docker logs loki`
- Verify loki-config.yml syntax
- Check if Loki is accessible: `curl http://localhost:3100/ready`

### Promtail Issues

- Check logs: `docker logs promtail`
- Verify promtail-config.yml syntax
- Check if Promtail is sending logs: `curl http://localhost:9080/metrics | grep loki_sent`

### Grafana Integration Issues

- Verify the Loki data source URL
- Check network connectivity between Grafana and Loki
- Verify that Loki is receiving logs: `curl -G -s "http://localhost:3100/loki/api/v1/label" --data-urlencode 'match={}'`

## Best Practices

1. **Log Rotation**: Ensure your system has proper log rotation configured to prevent disk space issues
2. **Query Optimization**: Use label filters before content filters for better performance
3. **Label Management**: Use meaningful labels but avoid high cardinality
4. **Resource Allocation**: Monitor Loki's resource usage and adjust as needed
5. **Security**: Protect access to your logs as they may contain sensitive information

## Next Steps

Now that you have your logging stack set up, you can proceed to the next section to configure security features including automatic Tor users blocking and additional alerting options.
