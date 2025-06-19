#!/bin/sh
set -e  # Exit on any error
set -x  # Print commands as they execute

echo "=== Starting S3 sync script ==="
echo "Current directory: $(pwd)"
echo "Script location: $0"

# Install packages
echo "Installing packages..."
apk add --no-cache aws-cli inotify-tools bash || {
    echo "Failed to install packages" >&2
    exit 1
}

echo "S3_BUCKET is: $S3_BUCKET"

# Check if S3_BUCKET is set
if [ -z "$S3_BUCKET" ]; then
    echo "ERROR: S3_BUCKET environment variable is not set!" >&2
    exit 1
fi

# Check if backups directory exists
if [ ! -d "/backups" ]; then
    echo "ERROR: /backups directory does not exist!" >&2
    exit 1
fi

echo "Listing /backups directory:"
ls -la /backups/

# Function to sync backups
sync_backups() {
  echo "=== Syncing backups to S3 ==="
  echo "Command: aws s3 sync /backups s3://$S3_BUCKET/ --include backup_*.sql.gz --exclude *"
  
  if aws s3 sync /backups s3://$S3_BUCKET/ \
    --include "backup_*.sql.gz" \
    --exclude "*"; then
    echo "Sync completed successfully"
  else
    echo "Sync FAILED" >&2
    return 1
  fi
}

# Test AWS credentials
echo "Testing AWS credentials..."
aws sts get-caller-identity || {
    echo "ERROR: AWS credentials not configured properly!" >&2
    exit 1
}

# Initial sync on startup
echo "=== Performing initial sync ==="
sync_backups || {
    echo "Initial sync failed, but continuing..." >&2
}


echo "=== Starting file watcher ==="
# Watch for new files and sync
inotifywait -m -e close_write /backups --format "%f" | while read filename; do
  echo "File event detected: $filename"
  if [[ "$filename" == backup_*.sql.gz ]]; then
    echo "New backup detected: $filename"
    sync_backups || echo "Sync failed for $filename" >&2
  else
    echo "Ignoring file: $filename"
  fi
done