#!/bin/sh
apk add --no-cache aws-cli inotify-tools bash

echo "S3_BUCKET is: $S3_BUCKET"

# Function to sync backups
sync_backups() {
  echo "Syncing backups to S3..."
  echo "Full command: aws s3 sync /backups s3://$S3_BUCKET/ --include backup_*.sql.gz --exclude *"
  if aws s3 sync /backups s3://$S3_BUCKET/ \
    --include "backup_*.sql.gz" \
    --exclude "*"; then
    echo "Sync completed"
  else
    echo "Sync FAILED" >&2
  fi
}

# Initial sync on startup
sync_backups

# Watch for new files and sync
inotifywait -m -e close_write /backups --format "%f" | while read filename; do
  if [[ "$filename" == backup_*.sql.gz ]]; then
    echo "New backup detected: $filename"
    sync_backups
  fi
done