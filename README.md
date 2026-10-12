# MarketFlow — Marketing & Procurement Dashboard

ต้นแบบระบบจัดการฝ่ายการตลาดและจัดซื้อ รองรับเว็บแอปและ Android ผ่าน Capacitor

## มีอะไรให้แล้ว
- Dashboard: งบประมาณ, ยอดรวม, งานรอดำเนินการ และรายการล่าสุด
- สร้าง PR/PO พร้อมหมวดหมู่ จำนวนเงิน จำนวนหน่วย และหมายเหตุ
- ค้นหาและกรองรายการ เปลี่ยนสถานะ PR/PO
- หน้าตรวจรับสินค้า (ต้นแบบการเปลี่ยนสถานะ)
- การแจ้งเตือนจากรายการรอดำเนินการ
- รายงานแยกสถานะและส่งออก CSV
- สมัคร/เข้าสู่ระบบด้วย Supabase Auth เมื่อกำหนดค่าฐานข้อมูล
- SQL schema พร้อม RLS, profiles, receipts, notifications และ audit_logs
- Responsive UI สำหรับมือถือ/เดสก์ท็อป

## สิ่งที่ต้องมี
- Node.js 20+ และ npm
- บัญชี Supabase (สำหรับฐานข้อมูลออนไลน์)
- Android Studio + Android SDK (สำหรับสร้าง APK)

## 1. ติดตั้งและรันเว็บแอป
```bash
npm install
cp .env.example .env
npm run dev
```
เปิด URL ที่ Vite แสดง เช่น `http://localhost:5173`

หากยังไม่กำหนด Supabase แอปจะเข้าโหมดตัวอย่าง ข้อมูลจะไม่ถูกบันทึกข้ามการรีเฟรช/อุปกรณ์

## 2. ตั้งค่าฐานข้อมูลออนไลน์ (Supabase)
1. สร้างโปรเจกต์ใน Supabase
2. เปิด SQL Editor แล้วรันไฟล์ `supabase/schema.sql`
3. ไปที่ Project Settings → API แล้วคัดลอก Project URL และ anon/publishable key ลงใน `.env`:
   ```
   VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
   ```
4. รีสตาร์ต `npm run dev`
5. สมัครบัญชีผ่านหน้าล็อกอิน ยืนยันอีเมลตามการตั้งค่า Supabase
6. โปรไฟล์ใหม่จะได้ role `requester` โดยค่าเริ่มต้น
7. กำหนดสิทธิ์ approver/buyer/warehouse/admin ผ่านกระบวนการที่เชื่อถือได้ของผู้ดูแลระบบก่อนใช้งานจริง

### ความปลอดภัยก่อน production
- ห้ามใส่ Supabase `service_role` key ในเว็บหรือแอป Android; ใช้เฉพาะ anon/publishable key
- SQL เปิด Row Level Security (RLS) และจำกัดสิทธิ์ตาม role เบื้องต้น
- ให้ผู้ดูแลตรวจทาน policies และกระบวนการกำหนด role ก่อนใช้งานกับข้อมูลจริง
- การเปลี่ยนสถานะใน UI นี้ยังไม่แยกขั้นตอนอนุมัติตาม role อย่างครบถ้วน; ควรย้าย workflow สำคัญไปใช้ RPC/Edge Function ที่ตรวจ role ฝั่งเซิร์ฟเวอร์
- ต้องเพิ่มระบบแจ้งเตือนจริง (เช่น trigger + Edge Function/อีเมล/Push), การแจ้งเตือนแบบเรียลไทม์, audit logging และการแนบเอกสาร ก่อน production
- ข้อมูลตัวอย่างไม่ใช่ข้อมูลจริง

## 3. สร้าง Android app ด้วย Capacitor
ติดตั้ง Android platform ครั้งแรก:
```bash
npm run build
npx cap add android
npx cap sync android
npx cap open android
```
จาก Android Studio เลือก Run เพื่อทดสอบ หรือ Build → Generate Signed Bundle / APK เพื่อเผยแพร่
หลังแก้เว็บแอป:
```bash
npm run android:sync
```
ต้องติดตั้ง Android Studio และ SDK ก่อนสร้าง APK

## โครงสร้างโปรเจกต์
```
marketflow_app/
├── src/
│   ├── lib/supabase.ts
│   ├── App.tsx
│   ├── main.tsx
│   └── styles.css
├── supabase/schema.sql
├── capacitor.config.ts
├── .env.example
├── package.json
└── README.md
```

## หมายเหตุสถานะการพัฒนา
ไฟล์นี้เป็น MVP starter ที่มีหน้า UI และ CRUD พื้นฐานสำหรับรายการ PR/PO พร้อม Supabase integration โครงสร้างฐานข้อมูล และเส้นทาง build Android ยังต้องตั้งค่า Supabase/Android SDK และทดสอบกับข้อมูลจริงก่อนใช้งานในองค์กร ไม่ได้มี APK ที่เซ็นแล้วแนบมาให้
