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
