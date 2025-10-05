# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker-based backup service for a PostgreSQL database (personal finances). It performs automated backups using `pg_dump` and syncs them to AWS S3 for redundancy.

## Architecture

The service consists of two Docker containers defined in `docker-compose.yml`:

1. **backup**: Uses `postgres:15` image to run weekly `pg_dump` operations
   - Creates gzipped SQL dumps in `/backups` (mounted from `/mnt/sda/backups/financer`)
   - Automatically keeps only the 4 most recent backups locally
   - Backup interval controlled by `BACKUP_INTERVAL` env var (default: 604800 seconds = 1 week)
   - Connects to external `financer-services_database` network

2. **s3-uploader**: Uses `alpine:latest` to sync backups to S3
   - Watches `/backups` directory using `inotifywait`
   - Automatically syncs new `.sql.gz` files to S3 when created
   - Performs initial sync on startup
   - Requires AWS credentials and `S3_BUCKET` env var

## Configuration

All configuration is in `stack.env`:
- Database connection: `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- AWS credentials: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `S3_BUCKET`
- Backup frequency: `BACKUP_INTERVAL` (in seconds)

## Running the Service

Start the backup service:
```bash
docker-compose up -d
```

View logs:
```bash
docker-compose logs -f backup
docker-compose logs -f s3-uploader
```

Stop the service:
```bash
docker-compose down
```

## Restoring Backups

Backup files are named: `backup_mordor_YYYYMMDD_HHMMSS.sql.gz`

Download from server:
```bash
scp your-username@your-server:/mnt/sda/backups/financer/backup_mordor_*.sql.gz ./
```

Restore to database:
```bash
gunzip -c backup_mordor_YYYYMMDD_HHMMSS.sql.gz | psql -h localhost -U your-username -d your-database
```

## Important Notes

- Backups are stored at `/mnt/sda/backups/financer` on the host
- The service connects to an external Docker network: `financer-services_database`
- Only files matching `backup_*.sql.gz` are synced to S3
- Local retention: 4 backups (older ones are automatically deleted)
