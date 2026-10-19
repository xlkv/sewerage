# HLD — Kanalizatsiya tarmog'i xaritasi (Quvur & Kolodets)

## 1. Kontekst va maqsad
Dala va ofis xodimlari uchun Android ilova (telefon + planshet). Ilova ochilganda xarita chiqadi; unda kanalizatsiya **kolodetslari** (nuqta) va ularni bog'laydigan **quvurlar** (chiziq) chizilgan bo'ladi. Admin ularni chizadi/tahrirlaydi, oddiy foydalanuvchi faqat ko'radi. Quvur ikki kolodets tanlanganda uzunligi avtomatik hisoblanadi, lekin qo'lda tuzatish mumkin. Har bir obyekt statusi bor: **rejalashtirilgan / jarayonda / tugallangan**.

Hozir HLD (yuqori darajadagi dizayn) — tasdiqlangandan keyin LLD (jadval DDL, RLS, ekran/komponent darajasi, API) yoziladi.

## 2. Qabul qilingan qarorlar (savol-javobdan)
| Mavzu | Qaror |
|---|---|
| Platforma | Flutter, hozir faqat Android (telefon + planshet), keyin iOS imkoni ochiq |
| Backend | Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions) |
| Xarita | Yandex MapKit; sxema ↔ sputnik almashtirish tugmasi |
| Tarmoq turi | Faqat kanalizatsiya |
| Quvur geometriyasi | Har doim kolodets → kolodets, to'g'ri chiziq |
| Oqim yo'nalishi | Saqlanadi (`from → to`), xaritada strelka; admin yo'nalishni almashtira oladi |
| Avto hisob | Faqat quvur uzunligi (m), kolodets koordinatalaridan |
| Qo'lda tahrir | Qo'lda kiritilgan uzunlik saqlanadi, avto hisob uni bosib ketmaydi; "Avtoga qaytarish" tugmasi |
| Quvur maydonlari | Diametr (mm): standart ro'yxat (110, 160, 200, 250, 315, 400, 500) + erkin son; status; uzunlik |
| Kolodets maydonlari | Balandlik (m), diametr (m), usta (ro'yxatdan), status |
| Ustalar | Alohida ro'yxat (ism, telefon); admin boshqaradi; usta ilovaga kirmaydi |
| Raqamlash | Avto: kolodets `K-1, K-2…`, quvur `Q-1, Q-2…`; admin o'zgartira oladi |
| Kolodets qo'yish | Xaritaga bosib; keyin surib (drag) joyini to'g'irlash — ulangan quvurlar avto yangilanadi |
| O'chirish | Quvur ulangan kolodetsni o'chirish taqiqlanadi (avval quvurlar o'chiriladi) |
| Auth | Telefon raqam + 5 xonali parol (PIN). SMS yo'q. Foydalanuvchini faqat admin yaratadi |
| Rollar | `admin` — hamma huquq; `user` — faqat ko'rish (barcha maydonlar, shu jumladan usta) |
| Yangilanish | Realtime — o'zgarish boshqa qurilmalarda darhol ko'rinadi |
| Internet | Faqat online |
| Til | O'zbek (lotin) |
| Loyiha | Bitta umumiy xarita |
| Hajm | ~1000 gacha obyekt → hammasi bir so'rovda yuklanadi, klasterlash shart emas |
| 1-versiyada qo'shimcha | Status bo'yicha rang + filtr |

**1-versiyadan tashqari (keyinga):** offline, rasmlar, o'zgarishlar tarixi (audit), Excel/hisobot, iOS, ko'p til, loyihalarga ajratish, boshqa tarmoq turlari.

## 3. Arxitektura

```
┌──────────────────── Flutter ilova (Android: telefon/planshet) ────────────────────┐
│  UI (ekranlar)  ──►  State (Riverpod)  ──►  Repository qatlami  ──►  supabase_flutter │
│        │                                          ▲                                  │
│  Yandex MapKit (xarita, nuqta/chiziq/strelka)     │ Realtime stream                  │
└───────────────────────────────────────────────────┼──────────────────────────────────┘
                                                    │ HTTPS / WebSocket
┌─────────────────────────────── Supabase ──────────┴──────────────────────────────────┐
│ Auth (pseudo-email + parol)   Postgres + PostGIS (jadvallar, triggerlar, RLS)         │
│ Realtime (manholes, pipes)    Edge Functions (admin: user yaratish / PIN reset)       │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- **Biznes qoidalar bazada:** uzunlikni hisoblash, avto raqamlash, o'chirish taqiqi, huquqlar — Postgres trigger/constraint/RLS orqali. Ilova faqat UI; noto'g'ri klient ham ma'lumotni buzolmaydi.
- **Service-role kalit faqat Edge Function ichida**, ilovada hech qachon bo'lmaydi.

## 4. Ma'lumotlar modeli (konseptual — aniq DDL LLD da)
- **profiles** — `id` (auth.users), `full_name`, `phone`, `role` (admin|user), `is_active`.
- **masters** (ustalar) — `id`, `full_name`, `phone`, `is_active`.
- **manholes** (kolodetslar) — `id`, `code` (K-n), `location` (PostGIS point), `height_m`, `diameter_m`, `master_id → masters`, `status`, `note`, `created_by`, vaqt belgilari.
- **pipes** (quvurlar) — `id`, `code` (Q-n), `from_manhole_id`, `to_manhole_id` (from ≠ to), `diameter_mm`, `length_auto_m`, `length_manual_m` (nullable), `status`, `note`, vaqt belgilari. Ko'rsatiladigan uzunlik = `length_manual_m ?? length_auto_m`.
- **status** enum: `planned`, `in_progress`, `completed`.

Asosiy qoidalar:
1. Quvur yaratilganda / kolodets surilganda trigger `length_auto_m` ni `ST_Distance(geography)` bilan qayta hisoblaydi. `length_manual_m` ga tegilmaydi.
2. `pipes.from/to_manhole_id` FK `ON DELETE RESTRICT` → quvur ulangan kolodets o'chmaydi; ilova tushunarli xabar chiqaradi.
3. `code` — sequence orqali avto, admin o'zgartira oladi (unique).

## 5. Auth va rollar
- Supabase'ning minimal parol uzunligi 6, SMS-siz telefon provayder ham noqulay → **telefon raqam pseudo-email ga aylantiriladi** (`998901234567@<app-domain>`), parol esa PIN dan klientda deterministik hosil qilinadi (masalan `PIN + doimiy suffix`). Foydalanuvchi faqat telefon va 5 xonali PIN ko'radi.
- Admin foydalanuvchi yaratish / PIN tiklash / bloklash → **Edge Function** (`admin-users`), ichida chaqiruvchining `admin` ekanligi tekshiriladi.
- Foydalanuvchi o'z PIN ini o'zgartira oladi.
- **RLS:** barcha jadvallarda `SELECT` — faol (is_active) foydalanuvchilarga; `INSERT/UPDATE/DELETE` — faqat `is_admin()`.
- 5 xonali PIN = 100 000 kombinatsiya → Supabase Auth rate-limit yoqiladi; birinchi admin SQL orqali qo'lda yaratiladi.

## 6. Asosiy oqimlar
**Kolodets qo'shish (admin):** "Kolodets" rejimi → xaritaga bosish → forma (balandlik m, diametr m, usta, status; kod avto) → saqlash → Realtime orqali hammada paydo bo'ladi.

**Kolodetsni surish (admin):** tahrir rejimida kolodetsni uzoq bosib surish → tasdiqlash → `location` yangilanadi → trigger ulangan quvurlar uzunligini qayta hisoblaydi.

**Quvur chizish (admin):** "Quvur" rejimi → 1-kolodets (boshlanish) → 2-kolodets (tugash) → uzunlik avto ko'rsatiladi → diametr, status, kerak bo'lsa uzunlikni qo'lda tahrirlash → saqlash. Yo'nalish = tanlash tartibi.

**Ko'rish (hamma):** obyektga bosish → tafsilot kartochkasi (telefonda bottom sheet, planshetda o'ng panel). User uchun faqat o'qish.

**Filtr:** status bo'yicha yoqish/o'chirish. Ranglar: rejalashtirilgan — kulrang/ko'k, jarayonda — to'q sariq, tugallangan — yashil.

## 7. Ekranlar
1. Kirish (telefon + PIN)
2. Xarita (asosiy): obyektlar, filtr, sxema/sputnik, joriy joylashuv, admin uchun chizish asboblari
3. Kolodets kartochkasi / formasi
4. Quvur kartochkasi / formasi
5. Admin → Foydalanuvchilar (ro'yxat, qo'shish, role, bloklash, PIN reset)
6. Admin → Ustalar (ro'yxat, qo'shish/tahrir)
7. Profil (PIN o'zgartirish, chiqish)

Moslashuvchan layout: kenglik ≥ 600dp → planshet rejimi (xarita + yon panel), aks holda telefon (bottom sheet).

## 8. Xavflar / tekshirilishi kerak
- **Yandex MapKit litsenziyasi:** bepul rejimda kunlik limit va Yandex logotipi majburiy; tijoriy foydalanish shartlari va API key olish kerak. Flutter uchun rasmiy `yandex_maps_mapkit` paketi ishlatiladi (LLD da versiya aniqlanadi). Sputnik qatlami O'zbekistonda sifatini tekshirish kerak.
- **Uzunlik aniqligi:** telefon GPS ±3–10 m — shuning uchun qo'lda tahrir imkoni muhim.
- **5 xonali PIN xavfsizligi** — rate-limit va admin tomonidan bloklash bilan qoplanadi.

## 9. Keyingi qadam — LLD
HLD tasdiqlangandan keyin LLD da: aniq SQL migratsiyalar (jadval, enum, trigger, RLS, sequence), Edge Function kontrakti, Flutter papka tuzilmasi va paketlar, har ekran uchun widget/state tuzilmasi, xarita qatlamlari va chizish rejimi holat mashinasi, xato holatlari.

## 10. Tekshirish (HLD bo'yicha)
- Har bir bo'limni foydalanuvchi bilan ko'rib chiqish; 2-bo'limdagi qarorlar uning javoblariga mos ekanini tasdiqlash.
- LLD bosqichida: Supabase branch/loyihada migratsiyalarni qo'llash, RLS ni admin va user tokenlari bilan sinash, emulyator (telefon + planshet) da quvur chizish → uzunlik avto → kolodets surish → uzunlik yangilanishi → qo'lda uzunlik saqlanishi ssenariylarini o'tkazish.
