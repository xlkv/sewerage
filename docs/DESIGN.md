# Turon — dizayn tizimi "Blueprint"

G'oya: xarita — xira, tinch fon; kanalizatsiya tarmog'i uning ustida muhandislik chizmasidek aniq va jonli ko'rinadi. Ilovaning o'ziga xosligi xaritadagi chizmalarda: lyuk qopqog'iga o'xshash kolodetslar va ichida oqim yuradigan quvurlar.

## 1. Tokenlar
| Token | Qiymat | Qayerda |
|---|---|---|
| brand | `#0F766E` (teal 700) | asosiy tugmalar, tanlov, logo |
| brandSoft | `#CCFBF1` | tonal tugmalar, tanlangan chip foni |
| ink | `#0F172A` | asosiy matn |
| muted | `#64748B` | ikkinchi darajali matn |
| line | `#E2E8F0` | ajratgichlar, chegaralar |
| bg | `#F8FAFC` | ekran foni |
| surface | `#FFFFFF` | kartalar, sheet |
| planned | `#64748B` (slate) | rejalashtirilgan |
| inProgress | `#F59E0B` (amber) | jarayonda |
| completed | `#10B981` (emerald) | tugallangan |
| danger | `#DC2626` | o'chirish, xato |

- Shrift: **Manrope** (OFL, `assets/fonts` ga joylanadi, internetsiz ishlaydi). Sarlavha 700, matn 500, raqamlar `tabular figures`.
- Radius: chip 999, tugma 14, karta 16, sheet 24. Soyalar yumshoq: `0 8 24 rgba(15,23,42,.08)`.
- Bo'shliq: 4 / 8 / 12 / 16 / 24.

## 2. Xarita
- **Xarita uslubi:** Yandex `setMapStyle` orqali ranglar xiralashtiriladi (saturation ≈ −0.8, biroz yorqinroq), POI ikonkalari yashiriladi, ko'cha nomlari qoladi. Natijada tarmoq rangi ajralib turadi.
- **Kolodets = lyuk qopqog'i (yuqoridan):** 44dp. Status rangidagi tashqi halqa (3dp), oq oraliq, ichida status rangidagi disk va ingichka konsentrik chiziq. Diskning o'rtasida oq qalin kod (`K-12`).
  - Rejalashtirilgan: tashqi halqa **punktir**, ya'ni hali qurilmagan.
  - Jarayonda: tashqi halqa to'liq, atrofida **pulsatsiya** (halqa 1→1.6 kattalashib, so'nib boradi, 1.6 s).
  - Tugallangan: to'liq halqa va pastki o'ngda kichik ✓ belgisi.
  - zoom < 14: 14dp nuqta, status rangida, oq chegara.
- **Quvur:** ikki qatlam — oq "g'ilof" (outline 2dp) va status rangidagi o'zak. Eni diametrga qarab: ≤110 → 4dp, ≤200 → 5dp, ≤315 → 6dp, katta → 8dp.
  - Rejalashtirilgan: punktir (8/6).
  - Jarayonda va tanlangan quvur: o'zak ustida **oqim animatsiyasi**: ochroq rangli qisqa chiziqchalar `from → to` yo'nalishida yuradi (`dashOffset` animatsiyasi).
  - Tugallangan: to'liq chiziq, statik strelkalar.
  - Tanlangan: qo'shimcha brand rangidagi yorug'lik (outline brand 40%).
- **Animatsiyalar xaritada:**
  - Yangi kolodets "tushadi": scale 0 → 1.15 → 1, 350 ms.
  - Yangi quvur A dan B ga qarab "chiziladi", 500 ms.
  - Tanlanganda kolodets 1 → 1.2 ga silliq kattalashadi.
- **Unumdorlik:** barcha xarita animatsiyalarini bitta `Ticker` boshqaradi (≤ 30 fps). Faqat ekranda ko'rinib turgan obyektlar animatsiya qilinadi (eng ko'pi 40 ta). Ilova fonda bo'lsa yoki animatsiya kerak bo'lmasa, Ticker to'xtaydi. Tizimda "animatsiyani kamaytirish" yoqilgan bo'lsa, animatsiya o'chadi.

## 3. Ekranlar
- **Yuqori panel (AppBar o'rniga):** xarita ustida suzuvchi yarim shaffof panel: ☰ (doira tugma), "Turon", o'ngda qatlam va filtr doira tugmalari.
- **Mini statistika kartasi:** panel ostida ixcham karta. Uch rangli progress chiziq (rejada / jarayonda / tugallangan metrlar) va jami `km`. Bosilsa yumshoq ochiladi: har status bo'yicha metr, quvur va kolodets soni. Raqamlar o'zgarganda sanab boradigan animatsiya bilan yangilanadi.
- **Qo'shish:** bitta "+" FAB. Bosilsa "Kolodets" va "Quvur" tugmalari ketma-ket chiqadi (speed dial), "+" esa "×" ga aylanadi.
- **Rejim banneri:** tepada suzuvchi pill, ichida ikonka, matn va "Bekor qilish". Yuqoridan sirpanib tushadi.
- **Kartochka (sheet):** tepasida status rangidagi ingichka chiziq. Katta kod (28sp, 800), status chip'i (rangli nuqta bilan). Metrikalar 2 ustunli plitkalarda: ikonka, qiymat, birlik. Ulangan quvurlar `K-1 ──▸ K-2` mini-diagrammasi bilan. Pastda tonal tugmalar qatori. Boshqa obyekt tanlansa, kontent 200 ms da almashadi (cross-fade + slide).
- **Formalar:** status — rangli nuqtali segment tanlagich. Raqamli maydonlarda birlik suffiksi (`m`, `mm`). Diametr chip'lari. Asosiy tugma butun kenglikda.
- **Login:** logo tomchisi to'lib boradigan animatsiya. Klaviatura tugmasi bosilganda biroz kichrayadi. PIN katakchasiga raqam kiritilganda "pop" animatsiyasi.
- **O'tishlar:** sahifalar orasida fade-through (`animations` paketi). Snackbar suzuvchi, yumaloq, ikonka bilan.
- **Bo'sh holatlar:** brandSoft doira ichida ikonka, qisqa matn va bitta tugma.

## 4. Amalga oshirilgan holati (Claude, 2026-10-19)
- Tokenlar va tema: `lib/core/theme.dart` (`AppColors`, `AppRadii`, `AppShadows`, `AppTheme`).
- Xarita: `PlatformViewType.Hybrid`. Oldingi TextureHybrid rejimida native kadrlar kamera qimirlamaguncha yangilanmasdi, bu tanlov halqasi bug'ining asl sababi edi; kamerani "turtish" yechimi olib tashlandi. Blueprint uslubi `setMapStyle` orqali (`applied=true`). Lyuk qopqog'i belgilari, diametrga qarab qalinlashadigan quvurlar, oqim, pulsatsiya, paydo bo'lish va chizilish animatsiyalari — `map_objects_layer.dart`. Barchasini 30 fps'lik bitta `Timer` boshqaradi, faqat animatsiya kerak bo'lganda va ilova faol bo'lganda ishlaydi. Ko'rinadigan hudud bo'yicha filtr yo'q, o'rniga 40 ta obyekt cheklovi.
- Ekran: suzuvchi panel, `NetworkStatsCard`, `SpeedDial`, qorong'i banner pill, yangi kartochkalar (`details_parts.dart`), login logo, bosqichlar o'tishi, PIN "pop" va klaviatura tugmasi bosilish animatsiyalari.
- Manrope: google/fonts `Manrope[wght].ttf` dan 400/500/600/700/800 statik nusxalar yasalgan (`assets/fonts`, OFL.txt bilan), tema va xarita belgilarida ishlatiladi.
- Qolgan ishlar: formalar va admin ekranlari hozircha faqat yangi tema bilan, alohida qayta chizilmagan.
