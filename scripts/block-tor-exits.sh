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
