#!/bin/bash

# Configuration
S3_BUCKET="your-bucket-name"
BACKUP_DIR="/path/to/backup"  # Directory to backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}.tar.gz"
LOG_FILE="/var/log/backup.log"

# Ensure AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create backup
log "Starting backup process..."
tar -czf "/tmp/${BACKUP_NAME}" "$BACKUP_DIR" 2>> "$LOG_FILE"

# Upload to S3
if [ $? -eq 0 ]; then
    log "Backup created successfully, uploading to S3..."
    aws s3 cp "/tmp/${BACKUP_NAME}" "s3://${S3_BUCKET}/${BACKUP_NAME}" 2>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log "Backup uploaded successfully to S3"
        # Cleanup local backup
        rm "/tmp/${BACKUP_NAME}"

        # Optional: Remove old backups (keeping last 7 days)
        aws s3 ls "s3://${S3_BUCKET}/" | \
        awk '{print $4}' | \
        sort -r | \
        tail -n +8 | \
        xargs -I {} aws s3 rm "s3://${S3_BUCKET}/{}"
    else
        log "Error uploading to S3"
        exit 1
    fi
else
    log "Error creating backup"
    exit 1
fi
