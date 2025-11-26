# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a simple Docker-based backup service for PostgreSQL databases. It performs automated backups using `pg_dump` and syncs them to AWS S3 for redundancy.

## Architecture

The service consists of one Docker container defined in `docker-compose.yml`:

**backup-orchestrator**: Uses `postgres:16` image to run automated backups in a loop
   - Runs backup immediately on startup, then repeats at specified interval
   - Backup interval controlled by `BACKUP_INTERVAL` env var (default: 86400 seconds = 1 day)
   - Performs database backups (pg_dump) for databases:
     - `mordor` database (main financer database)
     - `transactions` database (optional, if `TRANSACTIONS_HOST` is set)
   - Creates gzipped SQL dumps in timestamped directories under `/backups`
   - Automatically syncs backups to S3 after creation
   - Automatically keeps only the 5 most recent backup sets locally
   - Connects to external `financer-services_database` network
   - All logs go to stdout/console (visible in Portainer/docker logs)

## Configuration

All configuration is in `stack.env`:
- Database connection: `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` (for mordor database)
- Transactions DB (optional): `TRANSACTIONS_HOST`, `TRANSACTIONS_PORT`, `TRANSACTIONS_USER`, `TRANSACTIONS_PASSWORD`
- AWS credentials: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `S3_BUCKET`
- Backup frequency: `BACKUP_INTERVAL` (in seconds, default: 86400 = daily)
  - Daily backups: 86400
  - Weekly backups: 604800
  - Twice daily: 43200

## Running the Service

Start the backup service:
```bash
docker-compose up -d
```

View logs:
```bash
docker-compose logs -f backup-orchestrator
```

Stop the service:
```bash
docker-compose down
```

## Restoring Backups

Backups are organized in timestamped directories: `/backups/YYYYMMDD_HHMMSS/`

Each backup set contains:
- `mordor_YYYYMMDD_HHMMSS.sql.gz` - Main database backup
- `transactions_YYYYMMDD_HHMMSS.sql.gz` - Transactions database backup (if available)

Download from server:
```bash
scp -r your-username@your-server:/mnt/sda/backups/financer/YYYYMMDD_HHMMSS ./
```

Restore database:
```bash
gunzip -c YYYYMMDD_HHMMSS/mordor_*.sql.gz | psql -h localhost -U your-username -d mordor
```

## Important Notes

- Backups are stored at `/mnt/sda/backups/financer` on the host
- The service connects to an external Docker network: `financer-services_database`
- Backups are synced to S3 immediately after creation (if `S3_BUCKET` is configured)
- Local retention: 5 backup sets (older ones are automatically deleted)
- First backup runs immediately on container startup
- All logs go to stdout (visible with `docker-compose logs -f`)
- Simple and straightforward - perfect for Portainer deployment
