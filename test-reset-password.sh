#!/usr/bin/env bash
# ทดสอบ full flow: Forgot Password -> ดึง reset token จาก DB -> Reset Password
# ทำครบในคำสั่งเดียว ไม่ต้องเปิด api.rest มา copy-paste token เอง
#
# Usage:
#   ./test-reset-password.sh admin [new_password]
#   ./test-reset-password.sh user  [new_password]
# ถ้าไม่ระบุ new_password จะใช้รหัสผ่านเดิมจาก .env (ไม่เปลี่ยนอะไรจริง แค่ทดสอบ flow)
set -euo pipefail

cd "$(dirname "$0")"
export $(grep -E '^(ADMIN_EMAIL|ADMIN_PASSWORD|USER_PASSWORD|DATABASE_USER|DATABASE_DB|DATABASE_PASSWORD)=' .env | xargs)

HOST="http://localhost:9093"
DB_CONTAINER="69-s3-db"
USER_EMAIL="russell123@gmail.com"

target="${1:?ระบุ admin หรือ user}"

psql_query() {
  docker exec -e PGPASSWORD="$DATABASE_PASSWORD" "$DB_CONTAINER" \
    psql -U "$DATABASE_USER" -d "$DATABASE_DB" -t -A -c "$1"
}

case "$target" in
  admin)
    password="${2:-$ADMIN_PASSWORD}"

    echo "-> Forgot Password (Admin)"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" -X POST "$HOST/admin/forgot-password" \
      -H "Content-Type: application/json" -d "{\"email\":\"$ADMIN_EMAIL\"}"

    token=$(psql_query "select reset_password_token from admin_users where email='$ADMIN_EMAIL';")
    echo "-> token: $token"

    echo "-> Reset Password (Admin)"
    curl -s -X POST "$HOST/admin/reset-password" \
      -H "Content-Type: application/json" \
      -d "{\"resetPasswordToken\":\"$token\",\"password\":\"$password\"}" | python3 -m json.tool
    ;;

  user)
    password="${2:-$USER_PASSWORD}"

    echo "-> Forgot Password (User) [ไม่มี email provider — ยิงแบบ background ไม่รอจนจบ]"
    ( curl -s -o /dev/null -X POST "$HOST/api/auth/forgot-password" \
        -H "Content-Type: application/json" -d "{\"email\":\"$USER_EMAIL\"}" & disown ) 2>/dev/null
    sleep 2

    token=$(psql_query "select reset_password_token from up_users where email='$USER_EMAIL';")
    echo "-> token: $token"

    echo "-> Reset Password (User)"
    curl -s -X POST "$HOST/api/auth/reset-password" \
      -H "Content-Type: application/json" \
      -d "{\"code\":\"$token\",\"password\":\"$password\",\"passwordConfirmation\":\"$password\"}" | python3 -m json.tool
    ;;

  *)
    echo "target ต้องเป็น admin หรือ user" >&2
    exit 1
    ;;
esac
