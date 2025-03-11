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
