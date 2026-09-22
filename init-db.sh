#!/bin/bash
set -e

# สร้าง user แอป (strapi) ด้วยสิทธิ์น้อยสุดที่จำเป็น:
#  - REVOKE FROM PUBLIC ก่อน grant — PG ให้ CONNECT/TEMPORARY แก่ PUBLIC บน DB ใหม่โดย default
#  - CONNECT, TEMPORARY บน database (เข้าใช้ + temp tables)
#  - USAGE, CREATE บน schema public (Strapi ต้องสร้าง/แก้ table ตอน migration — PG15+ ไม่ให้ CREATE โดย default)
#  - ไม่ให้ CREATEDB / ALL PRIVILEGES เพื่อลดสิทธิ์ privilege escalation
# หมายเหตุ: GRANT ... ON DATABASE ไม่รับ function call (current_database() = syntax error) → ใช้ psql variable แทน
psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    -v db_name="$POSTGRES_DB" \
    -v app_user="${STRAPI_DB_USER:-strapi}" \
    -v app_pass="${STRAPI_DB_PASSWORD:?STRAPI_DB_PASSWORD is required}" <<'EOSQL'
CREATE USER :"app_user" WITH PASSWORD :'app_pass';
REVOKE ALL ON DATABASE :"db_name" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE :"db_name" TO :"app_user";
GRANT USAGE, CREATE ON SCHEMA public TO :"app_user";
EOSQL
