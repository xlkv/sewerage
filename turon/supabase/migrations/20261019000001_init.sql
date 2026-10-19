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
