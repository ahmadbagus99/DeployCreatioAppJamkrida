#!/bin/bash
set -e

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
GDRIVE_FILE_ID="13Xy-wBdfUGb3woowL4RPlw6xtIYAmFek"
ZIP_NAME="creatio.zip"
EXTRACT_DIR="creatio-extracted"
DEPLOY_DIR="/opt/creatio"

# ─────────────────────────────────────────
# STEP 1 — Install dependencies
# ─────────────────────────────────────────
echo "📦 Checking dependencies..."

# Install python3-pip, unzip, rsync kalau belum ada
apt update -qq
apt install -y -qq python3-pip unzip rsync curl

if ! command -v gdown &> /dev/null; then
  echo "Installing gdown..."
  pip3 install gdown --break-system-packages -q
fi

if ! command -v docker &> /dev/null; then
  echo "🐳 Docker not found. Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "✅ Docker installed."
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

# ─────────────────────────────────────────
# STEP 5 — Setup .env
# ─────────────────────────────────────────
if [ ! -f "${DEPLOY_DIR}/.env" ]; then
  cp .env.example ${DEPLOY_DIR}/.env
  echo ""
  echo "⚠️  .env file created at ${DEPLOY_DIR}/.env"
  echo "   Please edit it now: nano ${DEPLOY_DIR}/.env"
  echo "   Then re-run: ./deploy.sh"
  exit 0
fi

# Load .env
export $(grep -v '^#' ${DEPLOY_DIR}/.env | xargs)

# ─────────────────────────────────────────
# STEP 6 — Generate ConnectionStrings.config
# ─────────────────────────────────────────
echo "⚙️  Generating ConnectionStrings.config from .env..."

cat > ${DEPLOY_DIR}/creatio-app/ConnectionStrings.config << XMLEOF
<?xml version="1.0" encoding="utf-8"?>
<connectionStrings>
  <add name="db" connectionString="Server=${POSTGRES_HOST};Port=5432;Database=${POSTGRES_DB};User ID=${POSTGRES_USER};password=${POSTGRES_PASSWORD};Timeout=500; CommandTimeout=400;MaxPoolSize=1024;" />
  <add name="dbPostgreSql" connectionString="Pooling=true; Database=${POSTGRES_DB}; Host=${POSTGRES_HOST}; Port=5432; Username=${POSTGRES_USER}; Password=${POSTGRES_PASSWORD}; Timeout=5; CommandTimeout=400" />
  <add name="redis" connectionString="host=${REDIS_HOST};db=0;port=6379;password=${REDIS_PASSWORD}" />
  <add name="dbMssqlCore" connectionString="Data Source=tscore-ms-01\mssql2008; Initial Catalog=BPMonlineCore; Persist Security Info=True; MultipleActiveResultSets=True; Integrated Security=SSPI; Pooling = true; Max Pool Size = 100; Async = true" />
  <add name="dbMssqlUnitTest" connectionString="Data Source=TSAppHost-02; Initial Catalog=BPMonlineUnitTest; Persist Security Info=True; MultipleActiveResultSets=True; User ID=UnitTest; Password=UnitTest; Async = true" />
  <add name="tempDirectoryPath" connectionString="%TEMP%/%USER%/%APPLICATION%" />
  <add name="consumerInfoServiceUri" connectionString="http://sso.bpmonline.com:4566/ConsumerInfoService.svc" />
  <add name="consumerInfoServiceAccessInfoPageUri" connectionString="http://sso.bpmonline.com:4566/AccessInfoPage.aspx" />
  <add name="logstashConfigFolderPath" connectionString="%TEMP%\%APPLICATION%\LogstashConfig" />
  <add name="elasticsearchCredentials" connectionString="User=gs-es; Password=DEQpJMfKqUVTWg9wYVgi;" />
  <add name="influx" connectionString="url=http://10.0.7.161:30359; user=; password=; batchIntervalMs=5000" />
  <add name="clientPerformanceLoggerServiceUri" connectionString="http://tsbuild-k8s-m1:30001/" />
  <add name="messageBroker" connectionString="amqp://guest:guest@localhost/BPMonlineSolution" />
</connectionStrings>
XMLEOF

echo "✅ ConnectionStrings.config generated."

# ─────────────────────────────────────────
# STEP 7 — Docker compose up
# ─────────────────────────────────────────
echo "🐳 Starting containers..."
cd ${DEPLOY_DIR}
docker compose down -v 2>/dev/null || true
docker compose up -d --build

echo ""
echo "✅ Deploy complete!"
echo "   Creatio : http://$(curl -s ifconfig.me):${CREATIO_PORT}"
echo "   pgAdmin : http://$(curl -s ifconfig.me):${PGADMIN_PORT}"