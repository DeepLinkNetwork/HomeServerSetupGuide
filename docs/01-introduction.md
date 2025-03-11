# Introduction and Network Setup

This guide will walk you through setting up your home server environment, including network configuration, domain setup, and basic system preparation.

## System Requirements

Before starting, ensure your system meets these requirements:

- A computer with Ubuntu Server freshly installed
- Minimum 4GB RAM (8GB or more recommended for running all services)
- At least 50GB of free disk space
- Docker and Docker Compose installed
- SSH server configured and accessible
- Static WAN IP address
- Router with ports 80 and 443 forwarded to your server

## Network Configuration

### Static IP Setup

For a reliable home server, you should configure a static internal IP address:

1. Identify your network interface:
   ```bash
   ip a
   ```

2. Edit the Netplan configuration:
   ```bash
   sudo nano /etc/netplan/00-installer-config.yaml
   ```

3. Configure a static IP (example configuration):
   ```yaml
   network:
     version: 2
     ethernets:
       ens18:  # Replace with your interface name
         dhcp4: no
         addresses: [192.168.1.100/24]  # Choose an IP outside your router's DHCP range
         gateway4: 192.168.1.1  # Your router's IP
         nameservers:
           addresses: [1.1.1.1, 8.8.8.8]
   ```

4. Apply the configuration:
   ```bash
   sudo netplan apply
   ```

### Port Forwarding

Configure your router to forward ports 80 and 443 to your server's internal IP address:

1. Access your router's admin interface (typically http://192.168.1.1)
2. Navigate to port forwarding settings (may be under "Advanced" or "NAT/Gaming")
3. Create two port forwarding rules:
   - Forward external port 80 (HTTP) to internal port 80 on your server's IP
   - Forward external port 443 (HTTPS) to internal port 443 on your server's IP

### Domain Setup

For accessing your services remotely, you'll need a domain name:

1. Purchase a domain from a registrar (Namecheap, GoDaddy, etc.)
2. Set up DNS A records pointing to your static WAN IP:
   - Create an A record for your root domain (e.g., `example.com`)
   - Create wildcard A records for subdomains (e.g., `*.example.com`)

If you don't want to purchase a domain, you can use a free dynamic DNS service like Duck DNS or No-IP.

## System Preparation

### Update System

First, ensure your system is up to date:

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Required Packages

Install some essential packages:

```bash
sudo apt install -y curl wget git nano htop
```

### Docker Setup Verification

Verify Docker is installed and running:

```bash
docker --version
docker-compose --version
sudo systemctl status docker
```

If Docker is not installed, install it:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install -y docker-compose
```

Log out and log back in for group changes to take effect.

### Create Docker Network

Create a shared Docker network for all your services:

```bash
docker network create proxy
```

### Create Directory Structure

Create a directory structure for your services:

```bash
mkdir -p ~/docker/nginx-proxy-manager
mkdir -p ~/docker/authelia
mkdir -p ~/docker/monitoring/prometheus
mkdir -p ~/docker/monitoring/grafana
mkdir -p ~/docker/monitoring/alertmanager
mkdir -p ~/docker/logging/loki
mkdir -p ~/docker/logging/promtail
```

## Next Steps

Now that your system is prepared, you can proceed to the next section to set up Nginx Proxy Manager and Authelia for secure access to your services.
