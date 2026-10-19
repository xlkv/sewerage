# UX test hisoboti #2 — emulyator (Pixel 4, admin), 2026-10-19

analyze: 0 muammo · testlar: 59/59 ✅

## Tuzatilgani tasdiqlandi ✅
- Kolodets belgisi: status rangidagi doira, ichida kod (K-6), oq chegara.
- Uzunlik formati: `441.9 km`.
- Chap Drawer: Xarita, Foydalanuvchilar, Ustalar, Profil, Chiqish. AppBar'da faqat qatlam va filtr qoldi.
- Usta qo'shish: `+998` qat'iy, mask `+998 (90) 123-45-67`, maxsus klaviatura sheet ichida ochiladi, backspace mask belgilaridan o'tib to'g'ri o'chiradi.
- Ustani o'chirish: tasdiqlash oynasi chiqadi, usta bazadan va ro'yxatdan o'chadi.
- Ustalar bo'sh holati: ikonka va matn bor.
- Status filtri ochiladi, "Barchasi" tugmasi bor.

## Qolgan muammolar
| # | Daraja | Muammo | Taklif |
|---|---|---|---|
| 1 | Yuqori | Tanlov halqasi qoladi: kolodetsni bosib, keyin bo'sh joyni bossangiz yoki X ni bossangiz, kartochka yopiladi, lekin ko'k halqa belgida qolib ketadi | Selection `null` bo'lganda belgini oddiy bitmap bilan qayta chizish (diff'da tanlov o'zgarishini ham hisobga olish) |
| 2 | O'rta | Tanlangan kolodets ochilgan kartochka ostida qolib ketadi | Tanlanganda kamerani silliq siljitish: obyekt kartochkadan yuqoridagi ko'rinadigan qism markaziga kelsin |
| 3 | Past | Ustalar bo'sh holatida ikkita "Usta qo'shish" tugmasi (markazda va FAB) | Ro'yxat bo'sh bo'lsa, FAB'ni yashirish |
| 4 | Past | Sarlavha "Turon — Kanalizatsi..." bo'lib qirqiladi | AppBar'da faqat "Turon" |
| 5 | Tekshirish | Katta zoom'da sputnik qatlamiga o'tilganda xarita bo'sh ko'rinadi | Sputnik/gibrid qatlami haqiqatan yuklanishini tekshirish; zoom cheklovi yoki qatlam turini to'g'rilash |

## Yangilanish (Claude, agy'dan keyin)
- #1 tuzatildi. Asl sabab: native MapView kamera qimirlamaguncha yangi kadrni chizmaydi, shuning uchun eski (tanlangan) belgi va yangi qo'shilgan kolodetslar ko'rinmay qolardi. Yechim: obyektlar, tanlov yoki rejim o'zgarganda kamera 200 ms va 700 ms da ~1 m ga turtiladi (yo'nalish har gal almashadi), shu bilan birga `toUpdate` qismida belgi ham qayta chiziladi. Emulyatorda tasdiqlandi.
- #2 tuzatildi: tanlangan obyekt kartochkadan yuqoriga keladi.
- #5 (sputnik) — Yandex serverlari tomonidagi muammo bo'lishi mumkin, hozircha qoldirildi.

## Hali tekshirilmagan
Kolodetsni surish (drag), chiqish va PIN bilan qayta kirish, planshet layouti, oddiy `user` rolida tahrirlash tugmalari yo'qligi.

## Ma'lumot
Bazada: K-5, K-6, K-8 va Q-1 (sizniki). Sinovda yaratgan "Test Usta"ni o'chirdim.
