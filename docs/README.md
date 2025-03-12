# Home Server Setup Guide

This comprehensive guide will help you set up a secure and monitored home server using Ubuntu Server. The guide covers the following components:

![Server Diagram](https://raw.githubusercontent.com/DeepLinkNetwork/HomeServerSetupGuide/refs/heads/main/website/images/server-diagram.svg)

## Components

1. **Nginx Proxy Manager with Authelia**
   - Secure access to your services with a reverse proxy
   - Single sign-on and multi-factor authentication

2. **Monitoring Stack**
   - Prometheus for metrics collection
   - Grafana for visualization
   - Alert Manager for notifications

3. **Logging Stack**
   - Loki for log aggregation
   - Promtail for log collection
   - Log visualization in Grafana

4. **Security Features**
   - Automatic Tor users blocking
   - Email and Slack alerting
   - Docker profiles for service isolation

## Prerequisites

- Ubuntu Server (fresh installation)
- Docker and Docker Compose installed
- SSH access configured
- Static WAN IP address
- Router with ports 80 and 443 forwarded to your server

## Directory Structure

- `/docs` - Documentation for each component
- `/config` - Configuration files and templates
- `/scripts` - Helper scripts for setup and maintenance
- `/website` - Website files for documentation presentation

## Getting Started

Follow the guides in order for the best experience:

1. [Introduction and Network Setup](./01-introduction.md)
2. [Nginx Proxy Manager and Authelia Setup](./02-nginx-authelia.md)
3. [Prometheus and Grafana Monitoring](./03-prometheus-grafana.md)
4. [Loki and Promtail Logging](./04-loki-promtail.md)
5. [Security and Alerting](./05-security-alerting.md)
