#!/usr/bin/env bash
# ทดสอบ full flow แบบ CLI ล้วนๆ ไม่ต้องเปิด Mailpit UI เลย:
#   Forgot Password -> ดึงอีเมลจาก Mailpit API -> แกะ token จากลิงก์ -> Reset Password
#
# Usage:
#   ./test-reset-password.sh admin [new_password]
#   ./test-reset-password.sh user  [new_password]
# ถ้าไม่ระบุ new_password จะใช้รหัสผ่านเดิมจาก .env (ไม่เปลี่ยนอะไรจริง แค่ทดสอบ flow)
set -euo pipefail

cd "$(dirname "$0")"
export $(grep -E '^(ADMIN_EMAIL|ADMIN_PASSWORD|USER_PASSWORD|MAILPIT_PORT)=' .env | xargs)

HOST="http://localhost:9093"
MAILPIT="http://localhost:${MAILPIT_PORT}"
USER_EMAIL="russell123@gmail.com"

target="${1:?ระบุ admin หรือ user}"

# นับจำนวนอีเมลถึง $1 ตอนนี้ (ใช้เทียบก่อน/หลังยิง forgot-password กันอ่านอีเมลเก่าซ้ำ)
count_messages() {
  curl -s "$MAILPIT/api/v1/search?query=to:$1" \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['total'])"
}

# รอจน Mailpit มีอีเมลใหม่เข้ามา (สูงสุด ~5 วิ) แล้วดึง code จากอีเมลล่าสุดที่ส่งถึง $1
latest_reset_code() {
  local to_email="$1"
  local before="$2"
  local id="" after

  for _ in $(seq 1 25); do
    after=$(count_messages "$to_email")
    if [[ "$after" -gt "$before" ]]; then
      id=$(curl -s "$MAILPIT/api/v1/search?query=to:$to_email" \
        | python3 -c "import sys,json;print(json.load(sys.stdin)['messages'][0]['ID'])")
      break
    fi
    sleep 0.2
  done
  [[ -z "$id" ]] && { echo "รออีเมลถึง $to_email ใน Mailpit ไม่ทัน (timeout)" >&2; exit 1; }

  curl -s "$MAILPIT/api/v1/message/$id" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['Text'])" \
    | grep -oP 'code=\K[a-f0-9]+'
}

case "$target" in
  admin)
    password="${2:-$ADMIN_PASSWORD}"
    before=$(count_messages "$ADMIN_EMAIL")

    echo "-> Forgot Password (Admin)"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" -X POST "$HOST/admin/forgot-password" \
      -H "Content-Type: application/json" -d "{\"email\":\"$ADMIN_EMAIL\"}"

    token=$(latest_reset_code "$ADMIN_EMAIL" "$before")
    echo "-> token (จากอีเมลใน Mailpit): $token"

    echo "-> Reset Password (Admin)"
    curl -s -X POST "$HOST/admin/reset-password" \
      -H "Content-Type: application/json" \
      -d "{\"resetPasswordToken\":\"$token\",\"password\":\"$password\"}" | python3 -m json.tool
    ;;

  user)
    password="${2:-$USER_PASSWORD}"
    before=$(count_messages "$USER_EMAIL")

    echo "-> Forgot Password (User)"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" -X POST "$HOST/api/auth/forgot-password" \
      -H "Content-Type: application/json" -d "{\"email\":\"$USER_EMAIL\"}"

    token=$(latest_reset_code "$USER_EMAIL" "$before")
    echo "-> token (จากอีเมลใน Mailpit): $token"

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
