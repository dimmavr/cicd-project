#!/bin/bash
set -euo pipefail

# ---- Configuration ----
APP_DIR="/opt/webapp"
APP_FILE="webapp.sh"
STAGING="/tmp/webapp.sh"
BACKUP_DIR="/opt/webapp/backups"
SERVICE="webapp"
APP_USER="webapp"
HEALTH_URL="http://127.0.0.1:8000"

echo "=== install.sh started ==="

# ---- Step 1: Backup current version (with timestamp) ----
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
mkdir -p "${BACKUP_DIR}"

if [ -f "${APP_DIR}/${APP_FILE}" ]; then
    cp "${APP_DIR}/${APP_FILE}" "${BACKUP_DIR}/${APP_FILE}.${TIMESTAMP}"
    echo "[backup] Saved current version to ${BACKUP_DIR}/${APP_FILE}.${TIMESTAMP}"
else
    echo "[backup] No current version found, skipping backup"
fi

# ---- Step 2: Install new version from staging ----
if [ ! -f "${STAGING}" ]; then
    echo "[install] ERROR: staging file ${STAGING} not found"
    exit 1
fi

mv "${STAGING}" "${APP_DIR}/${APP_FILE}"
chown "${APP_USER}:${APP_USER}" "${APP_DIR}/${APP_FILE}"
chmod 755 "${APP_DIR}/${APP_FILE}"
echo "[install] New version installed to ${APP_DIR}/${APP_FILE}"

# ---- Step 3: Restart service ----
systemctl restart "${SERVICE}"
echo "[restart] Service ${SERVICE} restarted"

# ---- Step 4: Health check ----
sleep 2
echo "[health] Checking ${HEALTH_URL} ..."

if curl -fs --max-time 5 "${HEALTH_URL}" > /dev/null; then
    echo "[health] OK - deployment successful"
    echo "=== install.sh finished ==="
    exit 0
else
    echo "[health] FAILED - starting rollback"

    # ---- Step 5: Rollback to latest backup ----
    LATEST_BACKUP=$(ls -1 "${BACKUP_DIR}"/${APP_FILE}.* 2>/dev/null | sort | tail -1)

    if [ -z "${LATEST_BACKUP}" ]; then
        echo "[rollback] ERROR: no backup found, cannot rollback"
        exit 1
    fi

    echo "[rollback] Restoring ${LATEST_BACKUP}"
    cp "${LATEST_BACKUP}" "${APP_DIR}/${APP_FILE}"
    chown "${APP_USER}:${APP_USER}" "${APP_DIR}/${APP_FILE}"
    chmod 755 "${APP_DIR}/${APP_FILE}"

    systemctl restart "${SERVICE}"
    echo "[rollback] Service restarted with previous version"
    echo "=== install.sh finished WITH ROLLBACK ==="
    exit 1
fi
