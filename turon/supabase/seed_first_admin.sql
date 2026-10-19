-- Birinchi admin (bir martalik, LLD 1.5)
-- 1. Dashboard -> Auth -> Add user:
--    email:    998XXXXXXXXX@users.turon.app
--    password: <PIN>#Turon   (masalan, PIN=12345 bo'lsa: 12345#Turon)
--    Auto confirm: ON
-- 2. Yaratilgan user UUID sini quyiga qo'yib ishga tushiring:

insert into public.profiles (id, full_name, phone, role)
values ('<uuid>', 'Ism', '998XXXXXXXXX', 'admin');
