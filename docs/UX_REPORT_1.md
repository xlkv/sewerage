# UX test hisoboti #1 — emulyator (Pixel 4, admin), 2026-10-19

## Ishlaydi ✅
- Kolodets qo'shish: `1,5` (vergul) qabul qilindi, bo'sh diametr → `null`. "Oraliqda emas" xatosi yo'qoldi.
- iOS uslubidagi bottom sheet: tutqich, snap (past/o'rta/yuqori), surish silliq.
- Quvur chizish: K-7 → K-6 tanlandi, avto uzunlik ko'rsatildi, "Yo'nalishni almashtirish" bor, saqlandi (Q-2), kartochkada yo'nalish va "Avto" belgisi.
- Admin: Foydalanuvchilar va Ustalar ekranlari ochiladi, qidiruv bor.
- Bo'sh qoldirilgan kod → avto `K-n`, `Q-n`.

## Muammolar
| # | Daraja | Muammo | Taklif |
|---|---|---|---|
| 1 | Yuqori | Saqlangan kolodets/quvur xaritada 3–5 s kechikib paydo bo'ladi (realtime kutiladi) | Saqlangandan keyin javobni darhol lokal holatga qo'shish (optimistic), realtime keyin tasdiqlaydi |
| 2 | O'rta | AppBar'da 6 ta ikonka — sarlavha "Turon..." bo'lib qirqiladi | Ustalar, Foydalanuvchilar, Profil, Chiqish → chap Drawer'ga; AppBar'da faqat qatlam + filtr |
| 3 | O'rta | Uzunlik `441911.0 m` ko'rinishida | ≥ 1000 m → `441.9 km`, < 1000 m → `48.3 m` (barcha joyda) |
| 4 | O'rta | Admin o'z hisobida "Bloklash" tugmasini ko'radi | O'z hisobida Bloklash va rolni o'zgartirishni yashirish |
| 5 | O'rta | To'liq ochilgan kartochkada pastda katta bo'sh joy | Yuqori snap balandligini kontentga moslash |
| 6 | Past | Oldindan ko'rsatilgan uzunlik (273 788 m) saqlangandan keyingisidan (274 133 m) farq qiladi | Oldindan ko'rsatishda `≈` belgisi yoki bir xil geodezik formula |
| 7 | Past | Kod maydonida "Bo'sh qolsa avto" izohi ko'rinmaydi | helperText qilib ko'rsatish |
| 8 | Past | "+ + Usta qo'shish" — ikonka va matnda ikki marta plyus | Matndan "+" ni olib tashlash (Foydalanuvchilarda ham) |
| 9 | Past | Quvur formasida "K-7 → K-6" ikki qatorga bo'linadi | Bir qatorda chip'lar: [K-7] → [K-6] |
| 10 | Past | Xarita yozuvlari inglizcha | MapKit tilini `uz_UZ` qilish (ishlamasa `ru_RU`) |
| 11 | Past | Ustalar bo'sh holati quruq | Ikonka + "Hali usta qo'shilmagan" + "Usta qo'shish" tugmasi |
| 12 | Texnik | 2 ta test yiqiladi (`step4_test.dart`: Image tekshiruvi noto'g'ri, Users/Masters widget testi provider'siz) | Testlarni tuzatish |

## Tekshirilmagan
Kolodets belgisi ichidagi nom (zoom ≥ 14), kolodetsni surish, filtr, sputnik qatlami, chiqish va PIN bilan kirish, planshet layouti.

## Ma'lumot
Bazada 17:58 da yaratilgan K-5, K-6, Q-1 AQShda turibdi (emulyatorning GPS joylashuvi u yerda). Shuning uchun ilova ochilganda xarita AQShni ko'rsatadi. Sinov paytida yaratilgan K-7 va Q-2 o'chirildi.
