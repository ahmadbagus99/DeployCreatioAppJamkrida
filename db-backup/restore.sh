#!/bin/bash
set -e

BACKUP_FILE="/backups/creatio.backup"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "⚠️  Backup file not found at $BACKUP_FILE, skipping restore."
  exit 0
fi

echo "🔄 Restoring database from $BACKUP_FILE..."

pg_restore \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --no-password \
  --verbose \
  "$BACKUP_FILE" || true

echo "✅ Database restore complete."