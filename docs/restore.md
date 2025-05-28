- All backup files are stored at `/mnt/sda/backups/financer`

- To download the files from SCP `scp your-username@your-server:/mnt/sda/backups/financer/backup_mordor_*.sql.gz ./`

- To restore it, we can just run `gunzip -c backup_mordor_YYYYMMDD_HHMMSS.sql.gz | psql -h localhost -U your-username -d your-database`
