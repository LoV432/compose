#!/bin/bash
set -eu

source .restic.env
# The .restic.env has this:
# export RESTIC_PASSWORD=""
# export DISCORD_WEBHOOK_URL=""
# If the backup script is asking for a password, something is wrong with the .restic.env file.

echo "=== Restic Backup Cron Job ==="
echo "$(date)"
echo ""

# === CONFIG ===
export RESTIC_REPOSITORY="rclone:gdrive-backup:restic-backups"
export RCLONE_CONFIG="/home/lov432/.config/rclone/rclone.conf"

DATA_DIR="/home/lov432/dockers/dockers_data"
BACKUP_DIR="/home/lov432/dockers/dockers_backup"
COMPOSE_DIR="/home/lov432/dockers/compose"
VAULTWARDEN_COMPOSE="/home/lov432/dockers/compose/vaultwarden/docker-compose.yaml"

# === Failure handler ===
notify_failure() {
  curl -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\": \"🚨 Restic backup script failed on freight-arch at $(date). Check logs.\"}" \
    "$DISCORD_WEBHOOK_URL"

  echo "Restic backup script failed on freight-arch at $(date). Check logs."
  docker compose -f "$VAULTWARDEN_COMPOSE" start
  exit 1
}

trap 'notify_failure' ERR

# === Pihole Backup ===
if [[ $(date +%u) == "6" ]] || [[ $(date +%u) == "3" ]]; then
  echo "Pihole backup..."

  PIBACKUP=$(ssh -oStrictHostKeyChecking=no -oBatchMode=yes root@192.168.1.23 pihole-FTL --teleporter)
  scp -oStrictHostKeyChecking=no -oBatchMode=yes root@192.168.1.23:$PIBACKUP $BACKUP_DIR/pihole/pi-hole_pihole_teleporter.zip
  ssh -oStrictHostKeyChecking=no -oBatchMode=yes root@192.168.1.23 rm $PIBACKUP

  echo ""
fi

# === OpenWRT Backup ===
if [[ $(date +%u) == "6" ]] || [[ $(date +%u) == "3" ]]; then
  echo "OpenWRT backup..."
  
  # Take backups
  ssh -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.1 'umask go=; sysupgrade -b /tmp/router-backup.tar.gz'
  ssh -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.101 'umask go=; sysupgrade -b /tmp/router-backup.tar.gz'
  
  # Copy backups to backup directory
  scp -O -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.1:/tmp/router-backup.tar.gz $BACKUP_DIR/openwrt/router-main-backup.tar.gz
  scp -O -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.101:/tmp/router-backup.tar.gz $BACKUP_DIR/openwrt/router-dumbap1-backup.tar.gz
  
  # Cleanup on routers
  ssh -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.1 'rm /tmp/router-backup.tar.gz'
  ssh -oStrictHostKeyChecking=no -oBatchMode=yes 192.168.1.101 'rm /tmp/router-backup.tar.gz'

  echo ""
fi

# === sing-box Backup ===
echo "sing-box backup..."
scp -O -oStrictHostKeyChecking=no -oBatchMode=yes root@192.168.1.24:/etc/sing-box/config.json $BACKUP_DIR/sing-box/config.json
echo ""

# === What to backup ===
BACKUP_PATHS=(
  "$DATA_DIR/authelia"
  "$DATA_DIR/homer"
  "$DATA_DIR/traefik"
  "$DATA_DIR/vaultwarden"
  "$DATA_DIR/yt-download"
  "$BACKUP_DIR/arr"
  "$BACKUP_DIR/emby"
  "$BACKUP_DIR/pihole"
  "$BACKUP_DIR/openwrt"
  "$BACKUP_DIR/sing-box"
  "$COMPOSE_DIR"
)

# === Stop Vaultwarden ===
echo "Stopping Vaultwarden..."
docker compose -f "$VAULTWARDEN_COMPOSE" stop
echo ""

# === Run Restic Backup ===
echo "Starting Restic backup..."
restic backup "${BACKUP_PATHS[@]}" \
  --exclude "traefik/config/logs/*" \
  --exclude "yt-download/downloads/*" \
  --exclude "postgres/*.sql" \
  --exclude ".git*" \
  --tag "scheduled-backup"

echo "Backup done"
echo ""

# === Restart Vaultwarden ===
echo "Starting Vaultwarden..."
docker compose -f "$VAULTWARDEN_COMPOSE" start
echo ""

# === Apply Retention Policy ===
echo "Applying Restic retention policy..."
restic forget \
  --keep-daily 14 \
  --keep-monthly 24 \
  --prune

echo "Retention policy done"
echo ""

echo "=== Restic Backup Cron Job Done ==="
echo "$(date)"
