#!/bin/bash
set -e

# ─────────────────────────────────────────
# CONFIG - sesuaikan jika perlu
# ─────────────────────────────────────────
GDRIVE_FILE_ID="13Xy-wBdfUGb3woowL4RPlw6xtIYAmFek"
ZIP_NAME="creatio.zip"
EXTRACT_DIR="creatio-extracted"
DEPLOY_DIR="/opt/creatio"

# ─────────────────────────────────────────
# STEP 1 — Install dependencies
# ─────────────────────────────────────────
echo "📦 Checking dependencies..."
if ! command -v gdown &> /dev/null; then
  echo "Installing gdown..."
  pip3 install gdown --break-system-packages -q
fi

if ! command -v docker &> /dev/null; then
  echo "❌ Docker not found. Please install Docker first."
  exit 1
fi

# ─────────────────────────────────────────
# STEP 2 — Download zip dari Google Drive
# ─────────────────────────────────────────
echo "⬇️  Downloading Creatio zip from Google Drive..."
gdown "https://drive.google.com/uc?id=${GDRIVE_FILE_ID}" -O ${ZIP_NAME}

# ─────────────────────────────────────────
# STEP 3 — Extract zip
# ─────────────────────────────────────────
echo "📂 Extracting zip..."
rm -rf ${EXTRACT_DIR}
unzip -q ${ZIP_NAME} -d ${EXTRACT_DIR}

# Cari folder utama hasil extract (kadang ada subfolder)
INNER_DIR=$(find ${EXTRACT_DIR} -maxdepth 1 -mindepth 1 -type d | head -1)
if [ -z "$INNER_DIR" ]; then
  INNER_DIR=${EXTRACT_DIR}
fi

echo "📁 Extracted to: ${INNER_DIR}"

# ─────────────────────────────────────────
# STEP 4 — Siapkan folder deploy
# ─────────────────────────────────────────
echo "🔧 Preparing deploy directory..."
mkdir -p ${DEPLOY_DIR}/creatio-app
mkdir -p ${DEPLOY_DIR}/db-backup

# Copy creatio-app (exclude folder db)
rsync -a --exclude='/db/' ${INNER_DIR}/ ${DEPLOY_DIR}/creatio-app/

# Copy DB backup dari folder db/
DB_FILE=$(find ${INNER_DIR}/db -type f | head -1)
if [ -n "$DB_FILE" ]; then
  echo "🗄️  Found DB file: $DB_FILE"
  cp "$DB_FILE" ${DEPLOY_DIR}/db-backup/creatio.backup
else
  echo "⚠️  No DB file found in /db folder!"
fi

# Copy docker files
cp docker-compose.yaml ${DEPLOY_DIR}/
cp Dockerfile ${DEPLOY_DIR}/
cp db-backup/restore.sh ${DEPLOY_DIR}/db-backup/restore.sh
chmod +x ${DEPLOY_DIR}/db-backup/restore.sh

# Copy .env jika belum ada
if [ ! -f "${DEPLOY_DIR}/.env" ]; then
  cp .env.example ${DEPLOY_DIR}/.env
  echo "⚠️  .env file created from .env.example — please edit ${DEPLOY_DIR}/.env before continuing!"
  echo "    Edit with: nano ${DEPLOY_DIR}/.env"
  exit 0
fi

# ─────────────────────────────────────────
# STEP 5 — Docker compose up
# ─────────────────────────────────────────
echo "🐳 Starting containers..."
cd ${DEPLOY_DIR}
docker compose down -v 2>/dev/null || true
docker compose up -d --build

echo ""
echo "✅ Deploy complete!"
echo "   Creatio: http://$(curl -s ifconfig.me):$(grep CREATIO_PORT .env | cut -d= -f2)"
echo "   pgAdmin: http://$(curl -s ifconfig.me):$(grep PGADMIN_PORT .env | cut -d= -f2)"
