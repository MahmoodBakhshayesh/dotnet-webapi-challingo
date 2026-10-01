# Challingo — راه‌اندازی سریع

خلاصه یک‌صفحه‌ای. جزئیات کامل: [SETUP-GUIDE.md](./SETUP-GUIDE.md) · اسکریپت‌های deploy: [README.md](./README.md)

---

## اولین بار (پروژه جدید)

```powershell
# ویندوز — از cursor-scaffold
.\New-Project.ps1 -ProjectName Challingo

cd cursor-scaffold\dev-postgres
docker compose up -d
.\create-db.ps1 challingo

cd challingo-api
dotnet run --project Challingo.Api

cd ..\challingo-deploy
.\Set-PublishSettings.ps1 -Interactive
.\build-and-push-all.ps1
# پوشه server-files/ را روی VPS کپی کنید → ./server-up.sh
```

```bash
# مک / لینوکس (نیاز: brew install --cask powershell)
./install-api-template.sh
./new-project.sh -ProjectName Challingo

cd cursor-scaffold/dev-postgres && docker compose up -d && ./create-db.sh challingo
cd ../challingo/challingo-deploy
./set-publish-settings.sh -Interactive
./build-and-push-all.sh
```

راهنمای کامل مک: `cursor-scaffold/docs/en/MACOS.md`

---

## دستورات روزمره

| هدف | دستور |
|-----|--------|
| اجرای API | `dotnet run --project Challingo.Api` |
| اجرای worker | `dotnet run --project Challingo.Worker` |
| اجرای web | `npm run dev` در `challingo-web` |
| تنظیم publish | `.\Set-PublishSettings.ps1 -Interactive` / `./set-publish-settings.sh` |
| build و push همه | `.\build-and-push-all.ps1` / `./build-and-push-all.sh` |
| فقط sync env VPS | `.\sync-server-env.ps1` / `./sync-server-env.sh` |
| deploy روی VPS | `./server-up.sh` |
| بررسی سلامت | `./health-check.sh` |
| توقف stack | `./server-down.sh` |

---

## قوانین پیکربندی

```text
api.env   → زمان اجرا (API + worker): JWT، Postgres، RabbitMQ، SMS، Email، Serilog، Worker__*، RateLimit__/RequestTimeout__/Http__/Idempotency__
web.env   → زمان build: NEXT_PUBLIC_* (بعد از تغییر باید image وب rebuild شود)
          → sync-server-env.ps1 → server-files/.env → کانتینرهای VPS
```

**تغییر runtime** (SMS، Gmail، Rabbit، Google client ID، سطح log، rate limit): `api.env` → `sync-server-env.ps1` → `./server-up.sh`  
**تغییر URL عمومی وب یا Google client ID**: `web.env` → `build-and-push-web.ps1` → `./server-up.sh`

**مقاومت ترافیک** (پیش‌فرض در `api.env`): محدودیت نرخ سراسری + OTP، timeout درخواست، retry/circuit برای HttpClient خروجی (SMS)، و `Idempotency-Key` اختیاری (پیش‌فرض خاموش). جدول: [SETUP-GUIDE.md](./SETUP-GUIDE.md) §13.2.

---

## ورود با Google (خلاصه)

1. Google Cloud → OAuth **Web client** → origins (`http://localhost:3000` + دامنه production).
2. `web.env`: `NEXT_PUBLIC_GOOGLE_CLIENT_ID=…` → rebuild وب.
3. `api.env`: `Google__ClientId=…` (همان Web ID) → sync → `./server-up.sh`.
4. روی VPS: `docker exec challingo-api printenv Google__ClientId`

جزئیات: [SETUP-GUIDE.md](./SETUP-GUIDE.md) §7.3

---

## فعال‌سازی OTP تولید (SMS + ایمیل)

در **`api.env`**:

```env
RabbitMq__Enabled=true
Otp__DevMode=false
Otp__LogOnly=false
Email__Enabled=true
Email__SmtpUsername=...
Email__SmtpPassword=...
Worker__EnableEmailDelivery=true
Sms__Provider=SmsIr
Sms__SmsIrApiKey=...
Worker__EnableSmsOtpDelivery=true
```

سپس: `.\sync-server-env.ps1` → در صورت نیاز کپی `server-files/` → `./server-up.sh`

---

## پورت‌های پیش‌فرض

| سرویس | پورت host |
|--------|-----------|
| Postgres | `5434` |
| API | `8080` |
| Web | `3000` |
| Registry (VPS) | `8585` |

Dev محلی: Postgres `127.0.0.1:5434` · API (Kestrel) `5128` · Web `3000`

---

## عیب‌یابی

| علامت | راه‌حل |
|-------|--------|
| API روی startup می‌میرد | `docker logs challingo-api` — migrate/DB |
| 502 هنگام login | کانتینر API down — `docker ps`، `./server-up.sh` |
| 429 Too Many Requests | افزایش `RateLimit__GlobalPerMinute` یا `Auth__OtpRateLimitPerMinute` در `api.env` → sync → restart |
| Web به API در Docker نمی‌رسد | SSR از `API_INTERNAL_URL`؛ مرورگر از `NEXT_PUBLIC_API_URL` |
| timeout در push به registry | Docker Desktop → insecure-registries → `YOUR_VPS:8585` |
| خطای `$'\r'` روی VPS | `sed -i 's/\r$//' .env *.sh` |

---

## معماری (یک پروژه روی VPS)

```text
اینترنت → nginx (:443) → web :3000، api :8080
                ↓
         challingo-network
         postgres · api · web · worker · (rabbitmq)
```

Worker همان **`api.env`** را می‌خواند — فایل worker.env جداگانه نیست.
