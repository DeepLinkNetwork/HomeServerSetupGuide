# Security and Alerting Setup

This guide will walk you through setting up advanced security features for your home server, including automatic Tor exit node blocking, comprehensive alerting via email and Slack, and Docker profiles for service isolation. These features will help:

- Protect your services from malicious actors
- Get notified about important events and potential security threats
- Organize your Docker services for better management

## Automatic Tor Exit Node Blocking

Tor exit nodes can be used by malicious actors to attack your services. Let's set up automatic blocking of Tor exit nodes using a script and cron job.

### Directory Setup

First, create a directory for the security scripts:

```bash
mkdir -p ~/docker/security/tor-blocking
cd ~/docker/security/tor-blocking
```

### Tor Exit Node Blocking Script

Create a script to fetch and block Tor exit nodes:

```bash
nano ~/docker/security/tor-blocking/block-tor-exits.sh
```

Add the following content:

```bash
#!/bin/bash

# Script to block Tor exit nodes
# This script fetches the current list of Tor exit nodes and blocks them using iptables

# Log file
LOG_FILE="/var/log/tor-blocking.log"

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
fi

# Log function
log() {
    echo "$(date): $1" | sudo tee -a "$LOG_FILE"
}

log "Starting Tor exit node blocking script"

# Create a new ipset if it doesn't exist
if ! sudo ipset list tor-exits &>/dev/null; then
    log "Creating new ipset for Tor exit nodes"
    sudo ipset create tor-exits hash:ip hashsize 4096
fi

# Flush the existing ipset
log "Flushing existing Tor exit node list"
sudo ipset flush tor-exits

# Fetch the current list of Tor exit nodes
log "Fetching current Tor exit node list"
TOR_EXITS=$(curl -s https://check.torproject.org/exit-addresses | grep ExitAddress | cut -d ' ' -f 2)

# Count of exit nodes
EXIT_COUNT=$(echo "$TOR_EXITS" | wc -l)
log "Found $EXIT_COUNT Tor exit nodes"

# Add each exit node to the ipset
for IP in $TOR_EXITS; do
    sudo ipset add tor-exits $IP
done

# Check if the iptables rule exists, if not add it
if ! sudo iptables -C INPUT -m set --match-set tor-exits src -j DROP 2>/dev/null; then
    log "Adding iptables rule to block Tor exit nodes"
    sudo iptables -A INPUT -m set --match-set tor-exits src -j DROP
    sudo iptables -A FORWARD -m set --match-set tor-exits src -j DROP
fi

# Make iptables rules persistent
if command -v netfilter-persistent &>/dev/null; then
    log "Saving iptables rules"
    sudo netfilter-persistent save
fi

log "Tor exit node blocking updated successfully"

# Send alert to Prometheus Alertmanager
if [ -n "$EXIT_COUNT" ] && [ "$EXIT_COUNT" -gt 0 ]; then
    log "Sending alert to Alertmanager"
    curl -XPOST http://localhost:9093/api/v1/alerts -H "Content-Type: application/json" -d "[{
        \"labels\": {
            \"alertname\": \"TorExitNodesBlocked\",
            \"severity\": \"info\",
            \"instance\": \"$(hostname)\"
        },
        \"annotations\": {
            \"summary\": \"Tor exit nodes blocked\",
            \"description\": \"$EXIT_COUNT Tor exit nodes have been blocked\"
        }
    }]"
fi

exit 0
```

Make the script executable:

```bash
chmod +x ~/docker/security/tor-blocking/block-tor-exits.sh
```

### Install Required Packages

Install the necessary packages for IP blocking:

```bash
sudo apt update
sudo apt install -y ipset iptables-persistent curl
```

### Set Up Cron Job

Set up a cron job to run the script every hour:

```bash
sudo crontab -e
```

Add the following line:

```
0 * * * * /home/ubuntu/docker/security/tor-blocking/block-tor-exits.sh
```

### Run the Script Manually

Run the script manually to verify it works:

```bash
sudo ~/docker/security/tor-blocking/block-tor-exits.sh
```

Check the log file:

```bash
cat /var/log/tor-blocking.log
```

## Fail2Ban Integration

Fail2Ban can help protect your server from brute force attacks. Let's set it up to work with our services.

### Install Fail2Ban

```bash
sudo apt install -y fail2ban
```

### Configure Fail2Ban for SSH

Create a custom SSH jail configuration:

```bash
sudo nano /etc/fail2ban/jail.d/ssh.conf
```

Add the following content:

```
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
```

### Configure Fail2Ban for Nginx

Create a custom Nginx jail configuration:

```bash
sudo nano /etc/fail2ban/jail.d/nginx.conf
```

Add the following content:

```
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 86400

[nginx-badbots]
enabled = true
filter = nginx-badbots
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400
```

### Restart Fail2Ban

```bash
sudo systemctl restart fail2ban
```

### Check Fail2Ban Status

```bash
sudo fail2ban-client status
```

## Email Alerting Setup

Let's configure email alerting for our monitoring system.

### Configure Postfix for Email Relay

Install Postfix for email sending:

```bash
sudo apt install -y postfix mailutils
```

During installation, select "Internet Site" and enter your domain name.

Edit the Postfix configuration:

```bash
sudo nano /etc/postfix/main.cf
```

Update the following settings:

```
myhostname = yourdomain.com
mydomain = yourdomain.com
myorigin = $mydomain
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

Create the SASL password file:

```bash
sudo nano /etc/postfix/sasl_passwd
```

Add your Gmail credentials:

```
[smtp.gmail.com]:587 your-email@gmail.com:your-app-password
```

Generate the hash database and set permissions:

```bash
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd.db
```

Restart Postfix:

```bash
sudo systemctl restart postfix
```

Test email sending:

```bash
echo "Test email from your home server" | mail -s "Test Alert" your-email@example.com
```

### Update Alert Manager Configuration

Update the Alert Manager configuration to use the local mail relay:

```bash
nano ~/docker/monitoring/alertmanager/config/alertmanager.yml
```

Update the email configuration:

```yaml
global:
  resolve_timeout: 5m
  smtp_smarthost: 'localhost:25'
  smtp_from: 'alerts@yourdomain.com'
  smtp_require_tls: false

# Rest of the configuration remains the same
```

Restart Alert Manager:

```bash
cd ~/docker/monitoring
docker-compose restart alertmanager
```

## Slack Alerting Setup

Let's configure Slack alerting for our monitoring system.

### Create a Slack Webhook

1. Go to your Slack workspace
2. Create a new channel for alerts (e.g., #server-alerts)
3. Go to https://api.slack.com/apps and create a new app
4. Enable "Incoming Webhooks" for your app
5. Create a new webhook URL for your alerts channel
6. Copy the webhook URL

### Update Alert Manager Configuration

Update the Alert Manager configuration to use the Slack webhook:

```bash
nano ~/docker/monitoring/alertmanager/config/alertmanager.yml
```

Ensure the Slack configuration is properly set:

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#server-alerts'
        send_resolved: true
        title: "{{ .GroupLabels.alertname }}"
        text: "{{ range .Alerts }}{{ .Annotations.description }}\n{{ end }}"
```

Replace `'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'` with your actual webhook URL.

Restart Alert Manager:

```bash
cd ~/docker/monitoring
docker-compose restart alertmanager
```

## Docker Profiles Configuration

Docker Compose profiles allow you to selectively start services. Let's organize our services into logical profiles.

### Update Docker Compose Files

We've already added profile configurations to our Docker Compose files. Let's create a script to manage them all:

```bash
nano ~/docker/manage-services.sh
```

Add the following content:

```bash
#!/bin/bash

# Script to manage Docker Compose services using profiles

# Function to display usage
usage() {
    echo "Usage: $0 [command] [profile]"
    echo "Commands:"
    echo "  start   - Start services with the specified profile"
    echo "  stop    - Stop services with the specified profile"
    echo "  restart - Restart services with the specified profile"
    echo "  status  - Show status of all services"
    echo "Profiles:"
    echo "  all       - All services"
    echo "  proxy     - Nginx Proxy Manager and Authelia"
    echo "  auth      - Authelia only"
    echo "  monitoring - Prometheus, Grafana, and Alert Manager"
    echo "  logging   - Loki and Promtail"
    echo "  security  - Security-related services"
    exit 1
}

# Check if command is provided
if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1
PROFILE=$2

# Function to start services
start_services() {
    case $1 in
        all)
            echo "Starting all services..."
            cd ~/docker/nginx-proxy-manager && docker-compose --profile proxy up -d
            cd ~/docker/authelia && docker-compose --profile auth up -d
            cd ~/docker/monitoring && docker-compose --profile monitoring up -d
            cd ~/docker/logging && docker-compose --profile logging up -d
            ;;
        proxy)
            echo "Starting proxy services..."
            cd ~/docker/nginx-proxy-manager && docker-compose --profile proxy up -d
            ;;
        auth)
            echo "Starting authentication services..."
            cd ~/docker/authelia && docker-compose --profile auth up -d
            ;;
        monitoring)
            echo "Starting monitoring services..."
            cd ~/docker/monitoring && docker-compose --profile monitoring up -d
            ;;
        logging)
            echo "Starting logging services..."
            cd ~/docker/logging && docker-compose --profile logging up -d
            ;;
        security)
            echo "Starting security services..."
            # Add security services here when available
            ;;
        *)
            echo "Unknown profile: $1"
            usage
            ;;
    esac
}

# Function to stop services
stop_services() {
    case $1 in
        all)
            echo "Stopping all services..."
            cd ~/docker/logging && docker-compose --profile logging down
            cd ~/docker/monitoring && docker-compose --profile monitoring down
            cd ~/docker/authelia && docker-compose --profile auth down
            cd ~/docker/nginx-proxy-manager && docker-compose --profile proxy down
            ;;
        proxy)
            echo "Stopping proxy services..."
            cd ~/docker/nginx-proxy-manager && docker-compose --profile proxy down
            ;;
        auth)
            echo "Stopping authentication services..."
            cd ~/docker/authelia && docker-compose --profile auth down
            ;;
        monitoring)
            echo "Stopping monitoring services..."
            cd ~/docker/monitoring && docker-compose --profile monitoring down
            ;;
        logging)
            echo "Stopping logging services..."
            cd ~/docker/logging && docker-compose --profile logging down
            ;;
        security)
            echo "Stopping security services..."
            # Add security services here when available
            ;;
        *)
            echo "Unknown profile: $1"
            usage
            ;;
    esac
}

# Function to restart services
restart_services() {
    stop_services $1
    start_services $1
}

# Function to show status
show_status() {
    echo "Docker containers status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Execute command
case $COMMAND in
    start)
        if [ -z "$PROFILE" ]; then
            echo "Error: Profile not specified"
            usage
        fi
        start_services $PROFILE
        ;;
    stop)
        if [ -z "$PROFILE" ]; then
            echo "Error: Profile not specified"
            usage
        fi
        stop_services $PROFILE
        ;;
    restart)
        if [ -z "$PROFILE" ]; then
            echo "Error: Profile not specified"
            usage
        fi
        restart_services $PROFILE
        ;;
    status)
        show_status
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        ;;
esac

exit 0
```

Make the script executable:

```bash
chmod +x ~/docker/manage-services.sh
```

### Using the Service Management Script

Start all services:

```bash
~/docker/manage-services.sh start all
```

Start only monitoring services:

```bash
~/docker/manage-services.sh start monitoring
```

Check the status of all services:

```bash
~/docker/manage-services.sh status
```

## Security Monitoring Dashboard

Let's create a security monitoring dashboard in Grafana to visualize security events.

### Create Security Dashboard Configuration

```bash
mkdir -p ~/docker/monitoring/grafana/dashboards
nano ~/docker/monitoring/grafana/dashboards/security-dashboard.json
```

Add the following content:

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 10,
  "links": [],
  "panels": [
    {
      "alert": {
        "alertRuleTags": {},
        "conditions": [
          {
            "evaluator": {
              "params": [
                10
              ],
              "type": "gt"
            },
            "operator": {
              "type": "and"
            },
            "query": {
              "params": [
                "A",
                "5m",
                "now"
              ]
            },
            "reducer": {
              "params": [],
              "type": "avg"
            },
            "type": "query"
          }
        ],
        "executionErrorState": "alerting",
        "for": "5m",
        "frequency": "1m",
        "handler": 1,
        "name": "Failed SSH Logins",
        "noDataState": "no_data",
        "notifications": []
      },
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(count_over_time({job=\"varlogs\"} |~ \"Failed password for.*sshd\" [1m]))",
          "legendFormat": "Failed SSH Logins",
          "refId": "A"
        }
      ],
      "thresholds": [
        {
          "colorMode": "critical",
          "fill": true,
          "line": true,
          "op": "gt",
          "value": 10,
          "visible": true
        }
      ],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Failed SSH Logins",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null,
            "filterable": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 4,
      "options": {
        "showHeader": true,
        "sortBy": [
          {
            "desc": true,
            "displayName": "Time"
          }
        ]
      },
      "pluginVersion": "7.4.0",
      "targets": [
        {
          "expr": "{job=\"varlogs\"} |~ \"Failed password for.*sshd\" | line_format \"{{.message}}\"",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Recent Failed SSH Logins",
      "type": "table"
    },
    {
      "alert": {
        "alertRuleTags": {},
        "conditions": [
          {
            "evaluator": {
              "params": [
                5
              ],
              "type": "gt"
            },
            "operator": {
              "type": "and"
            },
            "query": {
              "params": [
                "A",
                "5m",
                "now"
              ]
            },
            "reducer": {
              "params": [],
              "type": "avg"
            },
            "type": "query"
          }
        ],
        "executionErrorState": "alerting",
        "for": "5m",
        "frequency": "1m",
        "handler": 1,
        "name": "HTTP 403/404 Errors",
        "noDataState": "no_data",
        "notifications": []
      },
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "hiddenSeries": false,
      "id": 6,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(count_over_time({job=\"nginx\"} |~ \"HTTP/1.1\\\" (403|404)\" [1m]))",
          "legendFormat": "HTTP 403/404 Errors",
          "refId": "A"
        }
      ],
      "thresholds": [
        {
          "colorMode": "critical",
          "fill": true,
          "line": true,
          "op": "gt",
          "value": 5,
          "visible": true
        }
      ],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "HTTP 403/404 Errors",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "datasource": "Loki",
      "fieldConfig": {
        "defaults": {
          "custom": {
            "align": null,
            "filterable": false
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 8,
      "options": {
        "showHeader": true,
        "sortBy": [
          {
            "desc": true,
            "displayName": "Time"
          }
        ]
      },
      "pluginVersion": "7.4.0",
      "targets": [
        {
          "expr": "{job=\"nginx\"} |~ \"HTTP/1.1\\\" (403|404)\" | line_format \"{{.message}}\"",
          "legendFormat": "",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Recent HTTP 403/404 Errors",
      "type": "table"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Security Dashboard",
  "uid": "security",
  "version": 1
}
```

### Update Grafana Configuration

To automatically load the dashboard, update the Grafana Docker Compose configuration:

```bash
nano ~/docker/monitoring/docker-compose.yml
```

Add a volume for the dashboards:

```yaml
grafana:
  image: grafana/grafana:latest
  container_name: grafana
  restart: unless-stopped
  volumes:
    - grafana_data:/var/lib/grafana
    - ./grafana/dashboards:/var/lib/grafana/dashboards  # Add this line
  environment:
    - GF_SECURITY_ADMIN_USER=admin
    - GF_SECURITY_ADMIN_PASSWORD=secure_password
    - GF_USERS_ALLOW_SIGN_UP=false
    - GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/security-dashboard.json  # Add this line
  ports:
    - "3000:3000"
  networks:
    - proxy
  profiles:
    - monitoring
```

Restart Grafana:

```bash
cd ~/docker/monitoring
docker-compose restart grafana
```

## System Backup Script

Let's create a script to back up your important configuration files:

```bash
nano ~/docker/backup-configs.sh
```

Add the following content:

```bash
#!/bin/bash

# Script to back up important configuration files

# Backup directory
BACKUP_DIR="/home/ubuntu/backups"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILE="$BACKUP_DIR/homeserver-backup-$TIMESTAMP.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Log file
LOG_FILE="$BACKUP_DIR/backup-$TIMESTAMP.log"

# Log function
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

log "Starting backup process"

# Directories to back up
DIRS_TO_BACKUP=(
    "/home/ubuntu/docker/nginx-proxy-manager/data"
    "/home/ubuntu/docker/authelia/config"
    "/home/ubuntu/docker/monitoring/prometheus/config"
    "/home/ubuntu/docker/monitoring/alertmanager/config"
    "/home/ubuntu/docker/logging/loki/config"
    "/home/ubuntu/docker/logging/promtail/config"
    "/home/ubuntu/docker/security"
    "/etc/fail2ban"
)

# Create temporary directory
TEMP_DIR=$(mktemp -d)
log "Created temporary directory: $TEMP_DIR"

# Copy files to temporary directory
for DIR in "${DIRS_TO_BACKUP[@]}"; do
    if [ -d "$DIR" ]; then
        TARGET_DIR="$TEMP_DIR$(dirname "$DIR")"
        mkdir -p "$TARGET_DIR"
        cp -r "$DIR" "$TARGET_DIR"
        log "Copied $DIR to $TARGET_DIR"
    else
        log "Warning: Directory $DIR does not exist, skipping"
    fi
done

# Create tar archive
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .
log "Created backup archive: $BACKUP_FILE"

# Clean up temporary directory
rm -rf "$TEMP_DIR"
log "Cleaned up temporary directory"

# Keep only the 5 most recent backups
ls -t "$BACKUP_DIR"/homeserver-backup-*.tar.gz | tail -n +6 | xargs -r rm
log "Removed old backups, keeping the 5 most recent"

# Send email notification
if command -v mail &>/dev/null; then
    echo "Home server backup completed. Backup file: $BACKUP_FILE" | mail -s "Home Server Backup Completed" your-email@example.com
    log "Sent email notification"
fi

log "Backup process completed successfully"

exit 0
```

Make the script executable:

```bash
chmod +x ~/docker/backup-configs.sh
```

Set up a cron job to run the backup script weekly:

```bash
crontab -e
```

Add the following line:

```
0 2 * * 0 /home/ubuntu/docker/backup-configs.sh
```

## Next Steps

You have now completed the setup of a comprehensive home server with:

- Secure access through Nginx Proxy Manager and Authelia
- Monitoring with Prometheus and Grafana
- Logging with Loki and Promtail
- Security features including Tor exit node blocking
- Alerting via email and Slack
- Docker profiles for service organization

To further enhance your home server, consider:

1. Setting up additional services like Nextcloud for file storage
2. Implementing a VPN server for secure remote access
3. Adding a media server like Plex or Jellyfin
4. Setting up home automation with Home Assistant
5. Implementing regular security audits and updates

Remember to regularly update your system and Docker containers to ensure you have the latest security patches.
