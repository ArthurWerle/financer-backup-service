# This is a simple backup service that'll run a `pg_dump` weekly on my personal finances database.

This service will:

- perform weekly backups of my database running `pg_dump` and storing them in a backups folder.
- sync all backup files from the backups folder with `aws s3`.
