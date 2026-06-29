#!/bin/bash
set -euo pipefail

#configuration

SSH_KEY="/var/lib/jenkins/.ssh/id_ed25519"
DEPLOY_USER="deploy"
APP_NODE="192.168.56.11"
LOCAL_APP="webapp.sh"
REMOTE_TMP="/tmp/webapp.sh"

echo "=== Deploy started ==="

#Step 1: Upload new version to app-node (staging area)

echo "[1] uploading ${LOCAL_APP} to ${APP_NODE}:${REMOTE_TMP}"
scp -i "${SSH_KEY}" "${LOCAL_APP}" "${DEPLOY_USER}"@"${APP_NODE}":"${REMOTE_TMP}" 
echo "[1] upload ok"

# ---- Step 2: Run install on app-node (backup + install + restart) ----
echo "[2] Running install on ${APP_NODE} ..."
ssh -i "${SSH_KEY}" "${DEPLOY_USER}@${APP_NODE}" 'sudo /opt/webapp/install.sh'
echo "[2] Install OK"


echo "=== Deploy finished ==="
