# Mailpit — ทดสอบอีเมล (Forgot Password) แบบ local

## คืออะไร

Mailpit คือ SMTP server ปลอมสำหรับ dev/test เท่านั้น — Strapi ในโปรเจกต์นี้ถูกตั้งค่าให้ส่งอีเมลทั้งหมด (เช่น
"Forgot Password" ของทั้ง Admin และ User) มาที่ Mailpit แทนที่จะพยายามส่งออกอินเทอร์เน็ตจริง จะได้ทดสอบ flow
ได้ครบโดยไม่ต้องมี SMTP จริง และไม่ต้องไปขุด token จากฐานข้อมูลเอง

**ก่อนหน้านี้** (ไม่มี Mailpit): endpoint `Forgot Password (User)` จะค้างประมาณ 7-8 นาทีแล้วจบด้วย error เพราะ
พยายามต่อ SMTP จริงไม่ได้ ส่วน `Forgot Password (Admin)` จะดูเหมือนสำเร็จ (204) แต่จริงๆ ส่งอีเมลไม่ได้เงียบๆ

**ตอนนี้**: ทั้งสอง endpoint ตอบกลับภายในเสี้ยววินาที และอีเมลจริงไปโผล่ให้ดูที่หน้าเว็บ Mailpit

## ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | หน้าที่ |
|---|---|
| [docker-compose.yml](docker-compose.yml) | service `mailpit` + mount `config/plugins.js` เข้า container `app` |
| [config/plugins.js](config/plugins.js) | ตั้งค่า Strapi email plugin ให้ชี้ไปที่ Mailpit แทน SMTP จริง |
| `.env` | ตัวแปร `MAILPIT_PORT` (พอร์ตที่ใช้เปิดหน้าเว็บดูอีเมลบน host) |

## วิธีใช้งาน

### 1. เปิด container (ทำครั้งเดียว / ทุกครั้งที่ `docker compose up`)

```bash
docker compose up -d
```

Mailpit จะถูกสร้างและ start มาพร้อมกับ `app`/`db`/`admin` โดยอัตโนมัติ (ไม่ต้องสั่งแยก)

### 2. ยิง Forgot Password ตามปกติ

ใช้ `api.rest` (หรือ `api.rest.simple`) ยิง request ตามปกติ:

- `### Forgot Password (Admin)` → `POST /admin/forgot-password`
- `### Forgot Password (User)` → `POST /api/auth/forgot-password`

ทั้งสองจะตอบกลับเร็ว (ไม่ค้างแล้ว)

### 3. เปิดดูอีเมลที่ Mailpit

เปิดเบราว์เซอร์ไปที่:

```
http://127.0.0.1:8025
```

(ถ้าตั้ง `MAILPIT_PORT` ใน `.env` เป็นค่าอื่น ให้เปลี่ยนพอร์ตตามนั้น)

จะเห็นรายการอีเมลที่ Strapi ส่งมา เปิดดูเนื้อหาจะมีลิงก์แบบนี้:

```
http://0.0.0.0:1337/admin/auth/reset-password?code=<token>          ← Admin
http://.../reset-password?code=<token>                               ← User
```

Copy ค่า `<token>` หลัง `code=` มาใช้ต่อได้เลย

### 4. ยิง Reset Password ต่อ

ใส่ token ที่ copy มาใน `api.rest`:

```
@adminResetToken = <token จากอีเมล Admin>
@userResetToken  = <token จากอีเมล User>
```

แล้วกด Send Request ที่ `### Reset Password (Admin)` / `### Reset Password (User)` ตามปกติ

> ⚠️ token ใช้ได้ **ครั้งเดียว** — ถ้ากด Forgot Password ซ้ำ token เก่าจะถูกแทนที่ด้วยอันใหม่ทันที ต้องเปิด
> Mailpit ไปดูอีเมลฉบับล่าสุดเสมอ

## Mailpit API (ทางลัดสำหรับ script/curl)

ไม่จำเป็นต้องเปิดเว็บก็ดึงเนื้อหาอีเมลได้ผ่าน REST API ของ Mailpit เอง:

```bash
# ดูรายการอีเมลล่าสุด
curl -s http://localhost:8025/api/v1/messages | python3 -m json.tool

# ดูเนื้อหาอีเมลฉบับใดฉบับหนึ่ง (เอา ID จาก messages ด้านบน)
curl -s http://localhost:8025/api/v1/message/<ID> | python3 -m json.tool
```

## Troubleshooting

- **เปิด `http://127.0.0.1:8025` ไม่ได้** → เช็คว่า container รันอยู่: `docker ps | grep mailpit`
- **Forgot Password ยังค้างนานเหมือนเดิม** → เช็คว่า `app` container ถูก recreate หลังแก้ `docker-compose.yml`
  แล้วจริง (`docker compose up -d app`) และเช็ค log ว่าไม่มี error ตอน start: `docker logs 69-s3-app --tail 30`
- **ไม่เห็นอีเมลใน Mailpit เลย** → เช็คว่า `config/plugins.js` mount เข้าไปในคอนเทนเนอร์จริง:
  `docker exec 69-s3-app cat /opt/app/config/plugins.js`

## ปิดใช้งาน / เอาออก

Mailpit เป็นเครื่องมือช่วย dev เท่านั้น ไม่กระทบ production logic ใดๆ ถ้าต้องการเอาออก:

1. ลบ service `mailpit` และ volume mount `config/plugins.js` ออกจาก `docker-compose.yml`
2. ลบไฟล์ `config/plugins.js`
3. `docker compose up -d app` (Strapi จะกลับไปใช้ provider `sendmail` แบบเดิม พยายามส่ง SMTP จริง)
