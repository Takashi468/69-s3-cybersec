#!/bin/bash
set -e

# สร้าง user แอป (strapi) ด้วยสิทธิ์น้อยสุดที่จำเป็น:
#  - CONNECT, TEMPORARY บน database (เข้าใช้ + temp tables)
#  - USAGE, CREATE บน schema public (Strapi ต้องสร้าง/แก้ table ตอน migration — PG15+ ไม่ให้ CREATE โดย default)
#  - ไม่ให้ CREATEDB / ALL PRIVILEGES เพื่อลดสิทธิ์ privilege escalation
psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    -v app_user="${STRAPI_DB_USER:-strapi}" \
    -v app_pass="${STRAPI_DB_PASSWORD:?STRAPI_DB_PASSWORD is required}" <<'EOSQL'
CREATE USER :"app_user" WITH PASSWORD :'app_pass';
GRANT CONNECT, TEMPORARY ON DATABASE current_database() TO :"app_user";
GRANT USAGE, CREATE ON SCHEMA public TO :"app_user";
EOSQL

# ปิด trust auth บน unix socket (default ของ postgres image) → scram-sha-256
# TCP connections คุมด้วย POSTGRES_HOST_AUTH_METHOD ใน docker-compose.yml
if [ -f "$PGDATA/pg_hba.conf" ]; then
    sed -i 's/^\(local[[:space:]]\+all[[:space:]]\+all[[:space:]]\+\)trust/\1scram-sha-256/' "$PGDATA/pg_hba.conf"
fi
