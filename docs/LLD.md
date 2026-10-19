# LLD — "Turon" (kanalizatsiya quvur va kolodets xaritasi)

Asos: [HLD.md](HLD.md). Bu hujjat — kod yozishdan oldingi aniq dizayn: baza sxemasi, huquqlar, Edge Function kontrakti, Flutter tuzilmasi, holatlar va xatolar.

## 0. Qo'shimcha qarorlar
| Mavzu | Qaror |
|---|---|
| Ilova nomi | **Turon** |
| Paket ID | `uz.turon.app` (ishchi; o'zgartirish mumkin) |
| Supabase | Yangi loyiha (bepul tarif), region — Frankfurt (`eu-central-1`, O'zbekistonga eng yaqin) |
| State | Riverpod 2.x (codegen'siz) |
| Xarita SDK | `yandex_maps_mapkit_lite` (rasmiy Yandex Flutter plugin, lite — nuqta/chiziq/drag yetarli) |
| Konfiguratsiya | `--dart-define`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `YANDEX_MAPKIT_KEY` |
| Yandex kalit | Hali yo'q → siz developer.tech.yandex.ru dan "MapKit Mobile SDK" kalitini olasiz |

---

## 1. Baza sxemasi (Supabase Postgres)

### 1.1 Migratsiya `0001_init.sql`
```sql
create extension if not exists postgis with schema extensions;

create type public.app_role    as enum ('admin', 'user');
create type public.work_status as enum ('planned', 'in_progress', 'completed');

-- Foydalanuvchi profili (auth.users bilan 1:1)
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null check (length(trim(full_name)) between 2 and 100),
  phone      text not null unique check (phone ~ '^998[0-9]{9}$'),
  role       public.app_role not null default 'user',
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ustalar (ilovaga kirmaydi)
create table public.masters (
  id         uuid primary key default gen_random_uuid(),
  full_name  text not null check (length(trim(full_name)) between 2 and 100),
  phone      text check (phone is null or phone ~ '^998[0-9]{9}$'),
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create sequence public.manhole_code_seq;
create sequence public.pipe_code_seq;

-- Kolodetslar
create table public.manholes (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique default ('K-' || nextval('public.manhole_code_seq')),
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  location    extensions.geography(Point, 4326)
              generated always as (extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography) stored,
  height_m    numeric(5,2) check (height_m > 0 and height_m <= 20),
  diameter_m  numeric(4,2) check (diameter_m > 0 and diameter_m <= 5),
  master_id   uuid references public.masters(id) on delete set null,
  status      public.work_status not null default 'planned',
  note        text check (note is null or length(note) <= 1000),
  created_by  uuid references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Quvurlar (from → to = oqim yo'nalishi)
create table public.pipes (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique default ('Q-' || nextval('public.pipe_code_seq')),
  from_manhole_id  uuid not null references public.manholes(id) on delete restrict,
  to_manhole_id    uuid not null references public.manholes(id) on delete restrict,
  diameter_mm      integer not null check (diameter_mm between 50 and 2000),
  length_auto_m    numeric(8,2) not null default 0,   -- trigger to'ldiradi
  length_manual_m  numeric(8,2) check (length_manual_m is null or (length_manual_m > 0 and length_manual_m <= 10000)),
  status           public.work_status not null default 'planned',
  note             text check (note is null or length(note) <= 1000),
  created_by       uuid references auth.users(id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint pipes_not_self check (from_manhole_id <> to_manhole_id)
);

-- Bir juft kolodets orasida faqat bitta quvur (yo'nalishdan qat'i nazar)
create unique index pipes_unique_pair
  on public.pipes (least(from_manhole_id, to_manhole_id), greatest(from_manhole_id, to_manhole_id));
create index pipes_from_idx on public.pipes(from_manhole_id);
create index pipes_to_idx   on public.pipes(to_manhole_id);
```

### 1.2 Triggerlar `0002_triggers.sql`
```sql
-- updated_at
create function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger trg_profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger trg_masters_touch  before update on public.masters  for each row execute function public.touch_updated_at();
create trigger trg_manholes_touch before update on public.manholes for each row execute function public.touch_updated_at();
create trigger trg_pipes_touch    before update on public.pipes    for each row execute function public.touch_updated_at();

-- Ikki kolodets orasidagi masofa (metr, 2 xona)
create function public.calc_pipe_length(a uuid, b uuid) returns numeric
language sql stable set search_path = public, extensions as $$
  select round(st_distance(m1.location, m2.location)::numeric, 2)
  from manholes m1, manholes m2 where m1.id = a and m2.id = b
$$;

-- Quvur yaratilganda / uchlari o'zgarganda — avto uzunlik
create function public.pipes_set_length() returns trigger language plpgsql as $$
begin
  new.length_auto_m := coalesce(public.calc_pipe_length(new.from_manhole_id, new.to_manhole_id), 0);
  return new;
end $$;
create trigger trg_pipes_length
  before insert or update of from_manhole_id, to_manhole_id on public.pipes
  for each row execute function public.pipes_set_length();

-- Kolodets surilganda — ulangan quvurlar avto uzunligi (length_manual_m ga tegilmaydi)
create function public.manholes_recalc_pipes() returns trigger language plpgsql as $$
begin
  update public.pipes p
     set length_auto_m = public.calc_pipe_length(p.from_manhole_id, p.to_manhole_id)
   where p.from_manhole_id = new.id or p.to_manhole_id = new.id;
  return null;
end $$;
create trigger trg_manholes_moved
  after update of lat, lng on public.manholes
  for each row when (old.lat is distinct from new.lat or old.lng is distinct from new.lng)
  execute function public.manholes_recalc_pipes();
```
> `length_auto_m` ni klient yuborsa ham trigger qayta yozadi (insert'da). Update'da klient bu maydonni yubormasligi kerak — repository faqat ruxsat etilgan maydonlarni jo'natadi; qo'shimcha himoya sifatida column-level grant (1.3).

### 1.3 Huquqlar (RLS) `0003_rls.sql`
```sql
create function public.is_active_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active)
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and is_active and role = 'admin')
$$;

alter table public.profiles enable row level security;
alter table public.masters  enable row level security;
alter table public.manholes enable row level security;
alter table public.pipes    enable row level security;

-- profiles: o'zini ko'radi; admin hammani ko'radi. Yozish faqat Edge Function (service role) orqali.
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

-- masters, manholes, pipes: faol foydalanuvchi o'qiydi, admin yozadi
create policy masters_select  on public.masters  for select to authenticated using (public.is_active_user());
create policy masters_write   on public.masters  for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy manholes_select on public.manholes for select to authenticated using (public.is_active_user());
create policy manholes_write  on public.manholes for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy pipes_select    on public.pipes    for select to authenticated using (public.is_active_user());
create policy pipes_write     on public.pipes    for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- length_auto_m ni klient to'g'ridan-to'g'ri o'zgartira olmasin
revoke update (length_auto_m) on public.pipes from authenticated;

-- anon hech narsa ko'rmaydi
revoke all on public.profiles, public.masters, public.manholes, public.pipes from anon;
```

### 1.4 Realtime `0004_realtime.sql`
```sql
alter publication supabase_realtime add table public.manholes, public.pipes, public.masters;
```
Realtime RLS'ga bo'ysunadi — bloklangan foydalanuvchi o'zgarishlarni olmaydi.

### 1.5 Birinchi admin (bir martalik)
1. Dashboard → Auth → Add user: email `998XXXXXXXXX@users.turon.app`, parol = `derivePassword(PIN)` (5-bo'lim), "Auto confirm" ✔.
2. SQL: `insert into profiles(id, full_name, phone, role) values ('<uuid>', 'Ism', '998XXXXXXXXX', 'admin');`

---

## 2. Edge Function `admin-users`

`POST /functions/v1/admin-users`, `Authorization: Bearer <user JWT>`.

Ichki tartib: JWT dan foydalanuvchini aniqlash → `profiles` da `role='admin' and is_active` tekshiruvi (aks holda **403**) → service-role client bilan amal.

| `action` | Body | Natija |
|---|---|---|
| `create` | `{phone, full_name, pin, role}` | `auth.admin.createUser({email: pseudoEmail(phone), password: derivePassword(pin), email_confirm: true})` + `profiles` insert. Xato bo'lsa yaratilgan auth user o'chiriladi (rollback). → `{user_id}` |
| `reset_pin` | `{user_id, pin}` | `auth.admin.updateUserById(id, {password})` → `{ok:true}` |
| `set_active` | `{user_id, is_active}` | `profiles.is_active` + `ban_duration` (`'876000h'` / `'none'`) — bloklanganning tokeni yangilanmaydi |
| `update` | `{user_id, full_name?, role?}` | `profiles` update. Admin o'zini `user` qila olmaydi va o'zini bloklay olmaydi (**409**) |

Validatsiya: `phone` = `^998\d{9}$`, `pin` = `^\d{5}$`, `role ∈ {admin,user}`. Javob xatolari: `400 invalid_input`, `403 forbidden`, `409 phone_exists | self_change`, `500 internal`.

---

## 3. Auth tafsilotlari (klient)
- `normalizePhone("+998 90 123-45-67") → "998901234567"`; noto'g'ri bo'lsa forma xatosi.
- `pseudoEmail(phone) = "$phone@users.turon.app"`.
- `derivePassword(pin) = "$pin#Turon"` (Supabase min 6 belgi talabini qondirish uchun; xavfsizlik PIN + rate-limit + bloklashga tayanadi). Edge Function va klientda **bir xil** funksiya.
- Kirish: `signInWithPassword(email, password)` → `profiles` dan o'z profilini o'qish → `is_active=false` bo'lsa chiqarib yuborish.
- PIN o'zgartirish: eski PIN bilan qayta `signInWithPassword` (tekshiruv) → `auth.updateUser(password: derivePassword(newPin))`.
- Supabase Dashboard: Email provider ON, "Confirm email" OFF, public sign-up **OFF**, sign-in rate-limit pasaytiriladi (masalan 10 / 5 daqiqa / IP).

---

## 4. Flutter ilova

### 4.1 Paketlar
`supabase_flutter`, `flutter_riverpod`, `go_router`, `yandex_maps_mapkit_lite`, `geolocator`, `freezed` + `freezed_annotation` + `json_serializable` + `build_runner`, `intl`. Testlar: `flutter_test`, `mocktail`.

### 4.2 Papka tuzilmasi
```
lib/
  main.dart                    # Env o'qish, Supabase.initialize, MapKit init, ProviderScope
  app.dart                     # MaterialApp.router, tema, uz lokal
  core/
    env.dart                   # String.fromEnvironment(...)
    router.dart                # go_router + auth redirect
    theme.dart                 # status ranglari shu yerda
    auth_utils.dart            # normalizePhone, pseudoEmail, derivePassword
    errors.dart                # PostgrestException → o'zbekcha xabar
    responsive.dart            # isTablet(context) => width >= 600
  data/
    models/                    # work_status.dart, profile.dart, master.dart, manhole.dart, pipe.dart (freezed)
    repositories/              # auth_repo, manhole_repo, pipe_repo, master_repo, admin_users_repo
  features/
    auth/                      # login_screen.dart
    map/
      map_screen.dart          # xarita + toolbar + panel/sheet
      map_mode.dart            # holat mashinasi (4.4)
      map_controller.dart      # Notifier: mode, selection, filtr, qatlam
      map_objects_layer.dart   # Manhole/Pipe → Yandex map objects
      filter_sheet.dart
    manhole/                   # manhole_details.dart, manhole_form.dart
    pipe/                      # pipe_details.dart, pipe_form.dart
    admin/users/               # users_screen.dart, user_form.dart
    admin/masters/             # masters_screen.dart, master_form.dart
    profile/                   # profile_screen.dart (PIN o'zgartirish, chiqish)
  shared/widgets/              # adaptive_panel.dart, status_chip.dart, confirm_dialog.dart
```

### 4.3 Modellar
```dart
enum WorkStatus { planned, in_progress, completed }   // label: Rejalashtirilgan / Jarayonda / Tugallangan

Manhole { id, code, lat, lng, heightM?, diameterM?, masterId?, status, note?, updatedAt }
Pipe    { id, code, fromManholeId, toManholeId, diameterMm, lengthAutoM, lengthManualM?, status, note, updatedAt }
        get lengthM => lengthManualM ?? lengthAutoM;  get isManual => lengthManualM != null;
Master  { id, fullName, phone?, isActive }
Profile { id, fullName, phone, role, isActive }   get isAdmin => role == admin && isActive;
```
`location` ustuni klientga olinmaydi (`lat/lng` yetarli).

### 4.4 Providerlar
| Provider | Turi | Vazifa |
|---|---|---|
| `supabaseProvider` | Provider | `Supabase.instance.client` |
| `authSessionProvider` | StreamProvider | `onAuthStateChange` |
| `currentProfileProvider` | FutureProvider | o'z profili; `isAdmin` shu yerdan |
| `manholesProvider` | StreamProvider<Map<String, Manhole>> | `.from('manholes').stream(primaryKey:['id'])` — boshlang'ich yuklash + realtime |
| `pipesProvider` | StreamProvider<Map<String, Pipe>> | xuddi shunday |
| `mastersProvider` | StreamProvider<List<Master>> | xuddi shunday |
| `statusFilterProvider` | StateProvider<Set<WorkStatus>> | default — hammasi |
| `mapLayerProvider` | StateProvider<MapLayer> | `scheme` / `satellite` |
| `mapControllerProvider` | NotifierProvider<MapState> | rejim + tanlangan obyekt |
| `adminUsersProvider` | FutureProvider | admin ekranida ro'yxat (`profiles` select) |

~1000 obyekt → filtrlash klientda.

### 4.5 Xarita rejimlari (holat mashinasi)
```
MapMode = View
        | AddManhole
        | AddPipe(from: null)          // 1-kolodetsni kutmoqda
        | AddPipe(from: id)            // 2-kolodetsni kutmoqda
        | MoveManhole(id, newLatLng?)
```
| Holat | Hodisa | Natija |
|---|---|---|
| View | kolodets/quvurga bosish | `selection` = obyekt → kartochka |
| View | bo'sh joyga bosish | `selection = null` |
| View (admin) | "+ Kolodets" | AddManhole |
| AddManhole | xaritaga bosish | Manhole formasi (lat/lng bilan) → saqlash → View |
| View (admin) | "+ Quvur" | AddPipe(null) |
| AddPipe(null) | kolodetsga bosish | AddPipe(id), kolodets ajratib ko'rsatiladi |
| AddPipe(a) | boshqa kolodets `b` | Pipe formasi: from=a, to=b, uzunlik oldindan klientda Haversine bilan ko'rsatiladi (saqlangach bazadagi qiymat) → saqlash → View |
| AddPipe(a) | o'sha kolodets `a` | tanlov bekor → AddPipe(null) |
| AddPipe(a) | `a–b` orasida quvur bor | snackbar "Bu kolodetslar allaqachon ulangan" |
| Kolodets kartochkasi (admin) | "Joyini o'zgartirish" | MoveManhole(id) — placemark draggable |
| MoveManhole | drag tugadi | newLatLng saqlanadi, "Saqlash / Bekor" paneli |
| MoveManhole | Saqlash | `update lat,lng` → trigger quvurlarni qayta hisoblaydi → View |
| Har qanday | "Bekor" / Back | View |

Rejim bannerlari: "Kolodets qo'yish uchun xaritaga bosing", "Boshlanish kolodetsini tanlang", "Tugash kolodetsini tanlang".

### 4.6 Xarita qatlamlari
- **Kolodets** — `PlacemarkMapObject`: status rangidagi doira (ikonka bitmapi status bo'yicha keshlanadi), zoom ≥ 15 da `code` yozuvi. Tanlanganda kattaroq + oq chegara.
- **Quvur** — `PolylineMapObject` (2 nuqta), status rangi, eni 4dp (tanlanganda 7dp). Yo'nalish strelkasi — chiziq o'rtasida kichik placemark, `from→to` azimutiga burilgan (`RotationType.rotate`).
- Filtrdan o'tmagan obyektlar chizilmaydi. Quvur filtrdan o'tsa-yu kolodetsi o'tmasa ham quvur chiziladi.
- Diff-yangilash: `MapObjectCollection` ichida id → object xaritasi; stream o'zgarganda faqat o'zgarganlar qayta chiziladi.
- Sxema/Sputnik: `map.mapType` almashtiriladi. Boshlang'ich kamera: obyektlar bo'lsa — barchasini qamrab olgan bbox, yo'q bo'lsa — joriy GPS, u ham bo'lmasa — Toshkent.
- Ranglar: rejalashtirilgan `#607D8B`, jarayonda `#FB8C00`, tugallangan `#43A047`.

### 4.7 Formalar va validatsiya
**Kolodets:** kod (avto, admin tahrirlaydi, unique) · balandlik m (0–20, 2 xona) · diametr m (0–5, 2 xona) · usta (faol ustalardan dropdown, ixtiyoriy) · status · izoh.

**Quvur:** kod · boshlanish → tugash (o'qish uchun + "Yo'nalishni almashtirish" tugmasi = from/to swap) · diametr mm (chip'lar 110/160/200/250/315/400/500 + "Boshqa" → son 50–2000) · uzunlik: avto qiymat ko'rsatiladi; "Qo'lda kiritish" switch → maydon; switch o'chirilsa `length_manual_m = null` ("Avtoga qaytarish") · status · izoh.

Kartochkada uzunlik yonida belgi: "avto" yoki "qo'lda (avto: 48.3 m)".

**O'chirish:** tasdiqlash dialogi. Kolodets o'chirishda baza `23503` qaytarsa → "Avval bu kolodetsga ulangan N ta quvurni o'chiring".

### 4.8 Moslashuvchan UI
- `width >= 600` (planshet): `Row[ Expanded(xarita), 380dp yon panel ]` — kartochka/forma panelda.
- Telefon: xarita to'liq ekran + `DraggableScrollableSheet` (kartochka), formalar to'liq ekranli sahifa.
- Admin menyusi: `NavigationDrawer` — Xarita, Foydalanuvchilar, Ustalar, Profil. User'da faqat Xarita va Profil.

### 4.9 Xatolarni ko'rsatish (`core/errors.dart`)
| Kod | Xabar |
|---|---|
| `23503` | Bog'langan quvurlar bor — avval ularni o'chiring |
| `23505` (code) | Bu raqam band |
| `23505` (pipes_unique_pair) | Bu kolodetslar allaqachon ulangan |
| `23514` | Kiritilgan qiymat ruxsat etilgan oraliqda emas |
| `42501` / 403 | Sizda bu amal uchun ruxsat yo'q |
| Auth `invalid_credentials` | Telefon yoki parol noto'g'ri |
| Tarmoq xatosi | Internet aloqasi yo'q. Qayta urinib ko'ring |

Realtime uzilsa — xarita tepasida "Ulanish yo'q" chipi; qayta ulanganda stream o'zi tiklanadi.

---

## 5. Amalga oshirish tartibi
1. Supabase loyiha yaratish, migratsiyalar 0001–0004, birinchi admin.
2. Edge Function `admin-users` + deploy.
3. Flutter skelet: env, Supabase init, router, login, profil.
4. Xarita (Yandex kalit kerak): obyektlarni ko'rsatish, ranglar, filtr, sxema/sputnik.
5. Tafsilot kartochkalari + adaptiv panel.
6. Admin: kolodets qo'shish/tahrirlash/surish/o'chirish.
7. Admin: quvur chizish/tahrirlash/o'chirish, yo'nalish, qo'lda uzunlik.
8. Admin: foydalanuvchilar va ustalar ekranlari.
9. Sinov (6-bo'lim), release APK.

## 6. Tekshirish
- **Baza (SQL):** 2 kolodets + quvur → `length_auto_m` ≈ kutilgan masofa; kolodetsni surish → qayta hisoblanadi; `length_manual_m` saqlanib qoladi; ulangan kolodetsni o'chirish → `23503`; bir juftga ikkinchi quvur → `23505`; o'z-o'ziga quvur → `23514`.
- **RLS:** user JWT bilan `insert/update/delete` → rad; `select` → ishlaydi; bloklangan user → bo'sh natija; anon → rad.
- **Edge Function:** user JWT bilan chaqiruv → 403; admin bilan create → login ishlaydi; reset_pin → eski PIN ishlamaydi; set_active false → kira olmaydi.
- **Flutter unit:** `normalizePhone`, `derivePassword`, holat mashinasi o'tishlari, xato xaritalash.
- **Qo'lda (emulyator telefon + planshet):** ikki qurilmada kirish → birida kolodets qo'shish → ikkinchisida darhol paydo bo'lishi; quvur chizish → uzunlik; kolodets surish → uzunlik yangilanishi; filtr; sxema/sputnik; user rolida tahrir tugmalari yo'qligi.

## 7. Ochiq masalalar
- Yandex MapKit kaliti va litsenziya shartlari (tijoriy foydalanish) — sizdan.
- `yandex_maps_mapkit_lite` API (drag, mapType, rotatsiya) — 4-qadamda paket versiyasi bilan tasdiqlanadi; `@users.turon.app` pseudo-email Supabase validatsiyasidan o'tishi 1-qadamda tekshiriladi.
