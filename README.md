# Unified Backup Orchestration Service

A comprehensive Docker-based backup service that handles multiple PostgreSQL databases and Docker volumes, with automatic syncing to AWS S3 and extensible configuration.

## Features

- **Multiple Database Backups**: Backup multiple PostgreSQL databases (mordor, transactions, etc.)
- **Volume Backups**: Full Docker volume backups using tar.gz
- **Daily Scheduling**: Automated backups every day at 3am (configurable via cron)
- **S3 Integration**: Automatic sync to AWS S3 with proper error handling
- **Retention Policy**: Keeps exactly 5 backups per target, automatically deletes older ones
- **Comprehensive Logging**: Detailed logs for every backup operation
- **Extensible Configuration**: YAML-based config for easy addition of new databases/volumes
- **Error Handling**: Robust error handling with detailed logging and status reporting

## Architecture

Single unified `backup-orchestrator` service that:
1. Runs on a daily cron schedule (3am by default)
2. Performs all database backups using `pg_dump`
3. Creates volume backups using `docker run` and tar
4. Syncs all backups to S3 bucket
5. Applies retention policy (keeps 5 most recent backups)
6. Maintains detailed logs for debugging

## Configuration

### `backups.yml` - Backup Targets

Define which databases and volumes to backup in `backups.yml`:

```yaml
backup_targets:
  - name: "mordor"
    type: "database"
    enabled: true
    config:
      host: "postgres"
      port: 5432
      user: "${POSTGRES_USER}"
      password: "${POSTGRES_PASSWORD}"
      database: "mordor"

  - name: "transactions"
    type: "database"
    enabled: true
    config:
      host: "transactions"
      port: 5433
      user: "${TRANSACTIONS_USER}"
      password: "${TRANSACTIONS_PASSWORD}"
      database: "transactions"

volume_backups:
  - name: "postgres-data"
    enabled: true
    volume_name: "financer-services_postgres_data"
    description: "PostgreSQL data directory"

backup_config:
  retention_count: 5
  backup_dir: "/backups"
  s3_bucket: "${S3_BUCKET}"
  s3_region: "${AWS_DEFAULT_REGION}"
  schedule: "0 3 * * *"  # Daily at 3am
  compression_level: 6
```

### `stack.env` - Environment Variables

Configure credentials and service details in `stack.env`:

```env
# Mordor database (main)
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DB=mordor

# Transactions database (second instance)
TRANSACTIONS_HOST=transactions
TRANSACTIONS_PORT=5433
TRANSACTIONS_USER=admin
TRANSACTIONS_PASSWORD=admin

# AWS S3
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=your-bucket-name
```

## Usage

### Starting the Service

```bash
docker-compose up -d
```

### Viewing Logs

```bash
# View service logs
docker-compose logs -f backup-orchestrator

# View backup execution logs
docker exec financer-backup-service_backup-orchestrator-1 cat /backups/logs/backup_*.log
```

### Manual Backup Execution

```bash
docker exec financer-backup-service_backup-orchestrator-1 /backup.sh
```

### Stopping the Service

```bash
docker-compose down
```

## Backup Structure

Backups are organized by timestamp:

```
/mnt/sda/backups/financer/
├── YYYYMMDD_HHMMSS/
│   ├── mordor_YYYYMMDD_HHMMSS.sql.gz
│   ├── transactions_YYYYMMDD_HHMMSS.sql.gz
│   └── postgres-data_volume_YYYYMMDD_HHMMSS.tar.gz
├── logs/
│   ├── backup_YYYYMMDD_HHMMSS.log
│   └── ...
```

### S3 Bucket Structure

Backup timestamps are synced to S3:
```
s3://financer-backup/
└── YYYYMMDD_HHMMSS/
    ├── mordor_YYYYMMDD_HHMMSS.sql.gz
    ├── transactions_YYYYMMDD_HHMMSS.sql.gz
    └── postgres-data_volume_YYYYMMDD_HHMMSS.tar.gz
```

## Restoring Backups

### Restore from Database Dump

```bash
# Download backup from S3 or local
gunzip -c mordor_YYYYMMDD_HHMMSS.sql.gz | psql -h localhost -U admin -d mordor
```

### Restore from Volume Backup

```bash
# Extract volume backup (requires stopping containers using the volume)
docker-compose down
tar xzf postgres-data_volume_YYYYMMDD_HHMMSS.tar.gz -C /mnt/sda/backups/financer/
docker-compose up -d
```

## Adding New Backup Targets

### Add a New Database

Edit `backups.yml` and add a new entry to `backup_targets`:

```yaml
backup_targets:
  # ... existing entries ...
  - name: "my-new-db"
    type: "database"
    enabled: true
    config:
      host: "my-db-host"
      port: 5432
      user: "${POSTGRES_USER}"
      password: "${POSTGRES_PASSWORD}"
      database: "my-new-db"
```

Also add environment variables to `stack.env` if using a different host/port/credentials.

### Add a New Volume

Edit `backups.yml` and add a new entry to `volume_backups`:

```yaml
volume_backups:
  # ... existing entries ...
  - name: "my-volume"
    enabled: true
    volume_name: "my-docker-volume"
    description: "Description of what this volume contains"
```

Then restart the service:
```bash
docker-compose down
docker-compose up -d
```

## Retention Policy

The service automatically maintains exactly 5 backups per target. When a 6th backup is created:
- The oldest backup directory is removed
- All files within it are deleted
- This keeps disk usage under control

To change retention count, modify `retention_count` in `backups.yml`.

## Backup Schedule

Backups run daily at 3am (America/Sao_Paulo timezone) via cron inside the container.

To change the schedule, modify the `schedule` field in `backups.yml` using cron syntax:
- `0 3 * * *` = 3am daily
- `0 2 * * 0` = 2am every Sunday
- `0 */6 * * *` = Every 6 hours

Then restart the service for changes to take effect.

## Troubleshooting

### S3 Sync Not Working

Check AWS credentials and permissions:
```bash
docker exec financer-backup-service_backup-orchestrator-1 aws s3 ls
```

### Database Connection Issues

Verify database connectivity:
```bash
docker exec financer-backup-service_backup-orchestrator-1 \
  pg_isready -h postgres -p 5432 -U admin
```

### Check Backup Logs

```bash
docker exec financer-backup-service_backup-orchestrator-1 \
  tail -f /backups/logs/backup_*.log
```

## Future Enhancements

- [ ] Rsync to remote server
- [ ] Backup compression level configuration
- [ ] Per-target retention policies
- [ ] Backup verification/integrity checks
- [ ] Email notifications on success/failure
- [ ] Incremental backups
- [ ] Backup encryption
