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
| [test-reset-password.sh](test-reset-password.sh) | สคริปต์ทดสอบ full flow ผ่าน CLI ล้วนๆ (ดึง token จาก Mailpit API เอง) |

## วิธีใช้งาน

### 0. เปิด container (ทำครั้งเดียว / ทุกครั้งที่ `docker compose up`)

```bash
docker compose up -d
```

Mailpit จะถูกสร้างและ start มาพร้อมกับ `app`/`db`/`admin` โดยอัตโนมัติ (ไม่ต้องสั่งแยก)

จากนี้เลือกได้ 2 วิธี — **ใช้แบบไหนก็ได้** แล้วแต่สถานการณ์ (วิธี A เห็นอีเมลจริงเหมือนใช้งานจริง, วิธี B เร็ว
และไม่ต้องออกจาก terminal เลย)

---

### วิธี A — ผ่านหน้าเว็บ (UI)

**1. ยิง Forgot Password ตามปกติ**

ใช้ `api.rest` (หรือ `api.rest.simple`) ยิง request ตามปกติ:

- `### Forgot Password (Admin)` → `POST /admin/forgot-password`
- `### Forgot Password (User)` → `POST /api/auth/forgot-password`

ทั้งสองจะตอบกลับเร็ว (ไม่ค้างแล้ว)

**2. เปิดดูอีเมลที่ Mailpit**

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

**3. ยิง Reset Password ต่อ**

ใส่ token ที่ copy มาใน `api.rest`:

```
@adminResetToken = <token จากอีเมล Admin>
@userResetToken  = <token จากอีเมล User>
```

แล้วกด Send Request ที่ `### Reset Password (Admin)` / `### Reset Password (User)` ตามปกติ

> ⚠️ token ใช้ได้ **ครั้งเดียว** — ถ้ากด Forgot Password ซ้ำ token เก่าจะถูกแทนที่ด้วยอันใหม่ทันที ต้องเปิด
> Mailpit ไปดูอีเมลฉบับล่าสุดเสมอ

---

### วิธี B — CLI ล้วนๆ (ไม่ต้องเปิด browser เลย)

ใช้สคริปต์ [test-reset-password.sh](test-reset-password.sh) ที่ทำครบทั้ง flow ในคำสั่งเดียว:

```bash
./test-reset-password.sh admin
./test-reset-password.sh user
```

**สิ่งที่สคริปต์ทำให้อัตโนมัติ:**
1. ยิง `Forgot Password`
2. Poll Mailpit search API (`curl http://localhost:8025/api/v1/search?query=to:<email>`) จนกว่าอีเมลใหม่จะมาถึง
3. ดึงเนื้อหาอีเมลล่าสุด แกะ `code=<token>` ออกมาด้วย `grep -oP`
4. ยิง `Reset Password` ต่อทันที พร้อม pretty-print ผลลัพธ์

**ถ้าอยากตั้งรหัสผ่านใหม่จริง** ใส่ argument ที่ 2 (ไม่ใส่ = ใช้รหัสเดิมจาก `.env` แค่ทดสอบ flow เฉยๆ):
```bash
./test-reset-password.sh admin "NewPassword123!"
```

#### Mailpit API แบบ manual (เผื่ออยากดึงเองหรือ debug สคริปต์)

```bash
# ค้นอีเมลถึง email หนึ่งๆ (เรียงใหม่สุดก่อน)
curl -s "http://localhost:8025/api/v1/search?query=to:russell123@gmail.com" | python3 -m json.tool

# ดูเนื้อหาอีเมลฉบับใดฉบับหนึ่ง (เอา ID จากผลค้นด้านบน)
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
