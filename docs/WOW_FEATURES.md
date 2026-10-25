# Yangi imkoniyatlar (branch `feature/wow-ux`)

Asosiy versiya `main` branch'ida saqlangan. Bu branch'da quyidagilar qo'shildi; har biri emulyatorda sinab ko'rildi.

| # | Imkoniyat | Qayerdan ochiladi | Nima qiladi |
|---|---|---|---|
| 1 | **Oqim izi** | Kolodets kartochkasi → "Oqim izini ko'rsatish" | Kolodetsdan pastga oqadigan quvurlar teal, unga yuqoridan quyiladiganlari indigo rangda yorishadi, ustida oqim animatsiyasi yuradi. Kamera butun zanjirni ko'rsatadi. Legendada quvurlar soni, km va oxirgi kolodets (masalan, `→ K-19`) |
| 2 | **Ko'ndalang kesim** | Kolodets kartochkasi | Chuqurlik va diametrga mos chizma: yer sathi, shaxta, zinapoyalar, kiruvchi (chapda) va chiquvchi (o'ngda) quvurlar diametri bilan, ichida oqayotgan suv |
| 3 | **Rezina chiziq** | "+" → Quvur → 1-kolodets | 1-kolodetsdan xarita markazigacha punktir chiziq va uzunlik. Kolodetsga yaqinlashganda chiziq "magnit" bo'lib yopishadi, telefon titraydi va "K-19 ga ulash" tugmasi chiqadi |
| 4 | **Qidiruv** | Yuqori paneldagi 🔍 | `K-12`, `Q-3` yoki shunchaki `12` deb yozsangiz, kamera silliq uchib boradi va kartochka ochiladi |
| 5 | **Quvur yorliqlari** | Yaqin zoom (≥ 16) | Har bir quvur o'rtasida `312 m · Ø315` |
| 6 | **Statusni tez o'zgartirish** | Kartochkadagi status pill (admin) | Uch variant chiqadi. "Tugallangan" tanlansa, ✓ animatsiyasi o'ynaydi |
| 7 | **Qurilish taymlayni** | Menyu → Qurilish taymlayni | Pastda sana, slider va ▶. Tarmoq kunma-kun qanday qurilgani animatsiya bo'ladi: yangi kolodetslar paydo bo'ladi, quvurlar chiziladi, statuslar rangi o'zgaradi |
| 8 | **PDF hisobot** | Menyu → Hisobot (PDF) | KPI kartalar, status jadvali, tarmoqning vektor sxemasi (oqim strelkalari bilan), quvurlar va kolodetslar jadvallari. Share orqali Telegram, Gmail va Drive'ga yuboriladi |
| 9 | **Xarita ko'rinishi** | Yuqori paneldagi qatlam tugmasi | Sxema/Sputnik + Blueprint / Quyosh (yorqin, qalin chiziqlar, dala uchun) / Tun. Tanlov saqlanib qoladi |

## Baza
- Yangi `status_events` jadvali (`20261020000007_status_events.sql`). Trigger har bir yaratish, status o'zgarishi va o'chirishni yozib boradi. Faqat o'qish mumkin, yozishni faqat trigger qiladi. Mavjud obyektlar uchun boshlang'ich yozuvlar qo'shildi.
- Qarshida `demo` izohli namunaviy tarmoq: K-13 … K-19 va Q-5 … Q-10, 20 kunlik tarixi bilan. Kerak bo'lmasa, o'chirish uchun:
  `delete from pipes where note='demo'; delete from manholes where note='demo';`

## Texnik
- Yangi paketlar: `shared_preferences`, `pdf`, `printing`. `archive` versiyasi override qilindi (`image` 4.11 bilan mos bo'lishi uchun).
- Yangi fayllar: `network_graph.dart` (iz va taymlayn mantig'i, testlari bilan), `feature_providers.dart`, `map_overlays.dart`, `cross_section.dart`, `network_report.dart`.
- Tekshiruv: `flutter analyze` toza, 74 ta test o'tadi.

## Tekshirilmagan
- "Ulash" tugmasi bosilgandan keyingi forma: sinovdagi juftlik allaqachon ulangan edi.
- Planshet layouti.
- ✓ animatsiyasi kadrga tushmadi, status esa o'zgardi.

## KML / GeoJSON import (`turon/tool/`)
1. `python3 -I tool/kml_import.py fayl.kml|fayl.geojson out.json` — kolodetslar (nomlar aynan fayldagidek, takrorlansa ham), egri quvurlar (burilishlar `pipes.path` da), chiziq uchida kolodets bo'lmasa "Tugun-N" tuguni, simulyatsiya qilingan qurilish tarixi.
2. `python3 -I tool/kml_import_sql.py out.json import.sql --note "KML: Kh"` — bitta tranzaksiyali SQL.
3. `supabase db query --linked --project-ref puoplqftkoztzgzfzstn -f import.sql`
4. Yo'nalishlar keyin tuzatilgan fayl kelsa: pipes eksport → `tool/fix_directions.py asl.kml tuzatilgan.geojson export.json fix.sql` → shu SQL. Kod, status va tarix saqlanadi.

2026-10-21: `Kh` KML import qilindi (498 kolodets, 428 quvur, 97.6 km). `done_arrows.geojson` bo'yicha 47 chiziqdagi 224 quvur yo'nalishi tuzatildi.

## 2026-10-22: Windows va yangi taymlayn
- **Windows xaritasi:** `yandex_map_desktop` (Yandex JS API 2.1, WebView2) loyiha ichiga nusxalandi (`turon/packages/yandex_map_desktop`, v0.2.0) va kengaytirildi:
  - kursor ostidagi nuqta zoom'da joyida qoladi (avvalgi qadamning maqsad holatidan, proyeksiya orqali hisoblanadi, touchpad hodisalari jamlanadi);
  - faqat o'zgargan obyektlar yuboriladi (`upsert`/`remove`);
  - PNG belgilar (aylantirish, masshtab, matn, drag), CSS pulsatsiya;
  - kontur va punktirli chiziqlar, matnli pill'lar, kamera animatsiyasi davomiyligi, xarita turi va filtri.
- Ilova `NetworkLayer` interfeysi orqali ishlaydi: Android'da `MapObjectsLayerController` (MapKit), Windows'da `DesktopNetworkLayer`. Belgilar bir xil kod bilan chiziladi. Faqat quvur ichidagi oqim animatsiyasi Windows'da statik punktir.
- JS API kaliti: `env/dev.json` → `YANDEX_JS_KEY`.
- **Taymlayn = qurilish rejasi:** butun tarmoq bittadan chizib boriladi (kolodets → quvur o'sadi → kolodets). Tartib shimoli-g'arbdan boshlanadi va chiziqlar bo'ylab davom etadi. Har bir obyekt o'zining haqiqiy rangida chiqadi. Kamera bir qismga (~340 m) uchadi, uni quradi va keyingi qismga o'tadi. Oxirida butun tarmoqqa uzoqlashadi. Tezlik 1x/2x/4x/8x, standart 2x.

## 2026-10-25: Jamoa takliflari
- **Windows: kursor ostiga zoom.** `webview_windows` g'ildirak hodisasini (0,0) nuqta bilan yuboradi, shuning uchun zoom chap-yuqoriga ketardi. Endi g'ildirak va touchpad Flutter'da ushlanadi va `window.zoomAt(x, y)` orqali kursor ostidagi nuqta joyida qoladi (`yandex_map_desktop` 0.2.1). Windows'da hali sinalmagan.
- **Otmetkalar (Boltiq tizimi).** Kolodetsga ikkita qiymat qo'shildi: yer sathi (masalan +85.73) va quvur osti (masalan 82.73). Chuqurlik ulardan avtomatik hisoblanadi (bazadagi trigger). Ikkala qiymat ko'ndalang kesim chizmasida chiqadi. Quvur kartochkasida nishab ‰ ko'rsatiladi: (boshidagi quvur osti − oxiridagi quvur osti) / uzunlik.
- **Oraliq kolodets.** Kolodets kartochkasi → "Oraliq kolodets qo'shish" (admin): ulangan quvur tanlanadi va masofa kiritiladi (25/50/100 m yoki o'rtasi). Quvur ikkiga bo'linadi: egri chiziq nuqtalari saqlanadi, yangi kolodets quvur statusini oladi, uchastka a'zoligi ko'chadi. Bularning hammasini RPC `split_pipe` bitta tranzaksiyada bajaradi.
- **Uchastkalar.**
  - Yaratish: "+" → Uchastka. Boshidagi va oxiridagi kolodets tanlanadi, oradagi eng qisqa yo'l avtomatik qo'shiladi. Quvurni bosish uni qo'shadi yoki olib tashlaydi, yana kolodets bosilsa yo'l davom etadi. Keyin nomi, izoh, status va sanalar kiritiladi.
  - Kartochkada avtomatik hisoblanadi: uzunlik, quvurlar soni, kolodetslar soni va diametrlar bo'yicha taqsimot.
  - Fayllar: PNG, JPG yoki PDF, har biri 50 MB gacha. Ular yopiq `section-files` bucket'ida saqlanadi. Rasm ilova ichida ochiladi, PDF esa brauzerda yoki PDF ko'ruvchida.
  - Ro'yxat: Menyu → Uchastkalar. Quvur kartochkasida u qaysi uchastkaga tegishli ekani ko'rinadi.
- Baza: `20261025000009_sections_elevations.sql`.
