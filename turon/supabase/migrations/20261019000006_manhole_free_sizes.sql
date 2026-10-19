-- Kolodets balandligi/diametri: istalgan musbat qiymat (yuqori chegara yo'q)
alter table public.manholes drop constraint if exists manholes_height_m_check;
alter table public.manholes drop constraint if exists manholes_diameter_m_check;
alter table public.manholes alter column height_m type numeric(10,2), alter column diameter_m type numeric(10,2);
alter table public.manholes add constraint manholes_height_m_check check (height_m is null or height_m > 0);
alter table public.manholes add constraint manholes_diameter_m_check check (diameter_m is null or diameter_m > 0);
