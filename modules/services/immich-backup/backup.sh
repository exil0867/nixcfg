#!/usr/bin/env bash

# Enable error handling
set -e
set -o pipefail

# --- Configuration ---
# TIMESTAMP for DB Naming
NOW=$(date +"%Y-%m-%d_%H-%M-%S")

# Container Names (Must match your docker-compose/nix config)
DB_CONTAINER="immich_postgres"
DB_USER="postgres"

# Source Paths (Host Paths)
# Note: These match the variables in your nix config
SRC_UPLOAD="/mnt/1TB-ST1000DM010-2EP102/srv/immich/data"
SRC_GALLERY_1="/mnt/1TB-ST1000DM010-2EP102/databox/photoprism-gallery"
SRC_GALLERY_2="/mnt/1TB-ST1000DM010-2EP102/databox/immich-gallery"

# Destination Paths (Backup Drive)
BACKUP_ROOT="/mnt/1TB-TOSHIBA-MQ04ABF100/backups/immich"
BACKUP_DB="$BACKUP_ROOT/database"
BACKUP_FILES="$BACKUP_ROOT/files"

# --- Pre-flight Checks ---

echo "Starting Immich Backup at $NOW"

# 1. Check if Backup Drive is mounted
if ! mountpoint -q /mnt/1TB-TOSHIBA-MQ04ABF100; then
    echo "ERROR: Backup drive /mnt/1TB-TOSHIBA-MQ04ABF100 is not mounted!"
    exit 1
fi

# 2. Check if Source Drive is mounted (sanity check before rsync --delete)
if ! mountpoint -q /mnt/1TB-ST1000DM010-2EP102; then
    echo "ERROR: Source drive /mnt/1TB-ST1000DM010-2EP102 is not mounted! Aborting to prevent data deletion."
    exit 1
fi

# Create destination directories
mkdir -p "$BACKUP_DB"
mkdir -p "$BACKUP_FILES/immich-data"
mkdir -p "$BACKUP_FILES/external-photoprism"
mkdir -p "$BACKUP_FILES/external-immich"

# --- Step 1: Database Backup ---
echo "--- Dumping Database ---"

# Dump compressed SQL
# We use docker exec to run pg_dumpall inside the container
docker exec -t "$DB_CONTAINER" pg_dumpall --clean --if-exists --username="$DB_USER" | gzip > "$BACKUP_DB/immich_db_$NOW.sql.gz"

echo "Database dump successful: $BACKUP_DB/immich_db_$NOW.sql.gz"

# --- Step 2: Prune Old Database Dumps ---
echo "--- Pruning Old Database Dumps (Keeping last 20) ---"

# List files by time (newest first), skip the first 20, delete the rest
find "$BACKUP_DB" -name "immich_db_*.sql.gz" -type f -printf '%T@ %p\n' | \
    sort -rn | \
    tail -n +21 | \
    cut -d' ' -f2- | \
    xargs -I {} rm -- "{}"

# --- Step 3: File System Synchronization (Rsync) ---
# We run DB backup FIRST, then Files (per Immich docs recommendation for live systems)
# Flags:
# -a: Archive mode (permissions, times, symlinks)
# -v: Verbose
# --delete: Delete files in backup that no longer exist in source (Mirroring)
# --progress: Show progress (useful for logs)

echo "--- Syncing Upload/Library Data ---"
rsync -av --delete "$SRC_UPLOAD/" "$BACKUP_FILES/immich-data/"

echo "--- Syncing External Library 1 (PhotoPrism) ---"
rsync -av --delete "$SRC_GALLERY_1/" "$BACKUP_FILES/external-photoprism/"

echo "--- Syncing External Library 2 (Immich Old) ---"
rsync -av --delete "$SRC_GALLERY_2/" "$BACKUP_FILES/external-immich/"

echo "--- Backup Completed Successfully at $(date) ---"