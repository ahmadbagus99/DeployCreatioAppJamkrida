# DeployCreatioAppJamkrida

Auto deploy Creatio dari Google Drive ke server.

## Struktur Repo

```
DeployCreatioAppJamkrida/
├── Dockerfile
├── docker-compose.yaml
├── deploy.sh           ← script utama
├── .env.example
├── .gitignore
└── db-backup/
    └── restore.sh      ← auto restore DB saat postgres init
```

## Cara Deploy ke Server Baru

```bash
# 1. Clone repo
git clone https://github.com/ahmadbagus99/DeployCreatioAppJamkrida.git
cd DeployCreatioAppJamkrida

# 2. Jalankan deploy script
chmod +x deploy.sh
./deploy.sh
```

Script otomatis akan:
1. Download zip Creatio dari Google Drive
2. Extract dan pisahkan creatio-app & DB
3. Setup folder `/opt/creatio`
4. Buat `.env` dari template (edit jika perlu)
5. `docker compose up -d --build`
6. Postgres auto restore DB saat pertama init

## Re-deploy (update versi baru)

Upload zip baru ke Google Drive dengan File ID yang sama, lalu:

```bash
./deploy.sh
```

> ⚠️ Script akan `docker compose down -v` dulu — semua data di volume akan terhapus dan DB di-restore ulang dari backup.

## Manual Edit .env

```bash
nano /opt/creatio/.env
```
