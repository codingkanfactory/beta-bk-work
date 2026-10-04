-- POIN TATIBSI multi-school schema
-- Run this in Supabase SQL Editor before using beta1_supabase.html.

create extension if not exists pgcrypto;

create table if not exists schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school_code text,
  address text default '',
  principal_name text default '',
  principal_nip text default '',
  guru_bk_name text default '',
  guru_bk_nip text default '',
  school_phone text default '',
  school_email text default '',
  logo_url text default '',
  created_at timestamptz not null default now()
);

alter table public.schools add column if not exists school_code text;
update public.schools
set school_code = upper(btrim(school_code))
where school_code is not null and btrim(school_code) <> '';

do $$
declare
  school_row record;
  generated_code text;
begin
  for school_row in
    select id from public.schools where school_code is null or btrim(school_code) = ''
  loop
    loop
      generated_code := 'SCH-' || upper(encode(gen_random_bytes(5), 'hex'));
      exit when not exists (
        select 1 from public.schools where upper(btrim(school_code)) = generated_code
      );
    end loop;
    update public.schools set school_code = generated_code where id = school_row.id;
  end loop;
end $$;

alter table public.schools alter column school_code set not null;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'schools_school_code_canonical_check'
      and conrelid = 'public.schools'::regclass
  ) then
    alter table public.schools add constraint schools_school_code_canonical_check
      check (school_code = upper(btrim(school_code)));
  end if;
end $$;
create unique index if not exists schools_school_code_key on public.schools (school_code);
-- A trusted administrator can distribute the generated codes with:
-- select id, name, school_code from public.schools order by name;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text default '',
  email text default '',
  created_at timestamptz not null default now()
);

create table if not exists school_members (
  school_id uuid not null references schools(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'bk' check (role in ('owner', 'bk', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (school_id, user_id)
);

create table if not exists students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,
  uid text not null,
  nisn text not null,
  kelas text default '',
  phone text default '',
  address text default '',
  username text default '',
  namapemilik text default '',
  points integer not null default 100,
  poin integer not null default 0,
  jenis_kasus text default '',
  tanggal_kasus text default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default '',
  last_updated bigint,
  updated_by text default '',
  unique (school_id, nisn)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'students_school_id_id_key'
      and conrelid = 'public.students'::regclass
  ) then
    alter table public.students add constraint students_school_id_id_key unique (school_id, id);
  end if;
end $$;

create table if not exists student_credentials (
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid primary key,
  password text not null,
  updated_at bigint,
  foreign key (school_id, student_id) references students(school_id, id) on delete cascade
);

create table if not exists classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,
  wali_kelas text default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default '',
  unique (school_id, name)
);

create table if not exists case_types (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,
  points integer not null,
  description text default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default '',
  unique (school_id, name)
);

create table if not exists cases (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  uid uuid,
  name text default '',
  case_type text default '',
  details text default '',
  points_deducted integer not null default 0,
  initial_points integer not null default 100,
  final_points integer not null default 100,
  penulis_kasus text default '',
  date text default '',
  timestamp bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default ''
);

create table if not exists warning_letters (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid,
  student_name text default '',
  student_uid text default '',
  student_kelas text default '',
  sp_type text default '',
  violation_points integer default 0,
  current_points integer default 100,
  issued_date text default '',
  issued_by text default '',
  visible_to_user boolean not null default false,
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default ''
);

create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  title text not null,
  content text not null,
  event_name text default '',
  start_date text default '',
  end_date text default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default ''
);

create table if not exists school_settings (
  id uuid primary key references schools(id) on delete cascade,
  school_id uuid unique not null references schools(id) on delete cascade,
  school_name text default '',
  school_address text default '',
  principal_name text default '',
  principal_nip text default '',
  guru_bk_name text default '',
  guru_bk_nip text default '',
  school_phone text default '',
  school_email text default '',
  updated_at bigint,
  updated_by text default ''
);

create table if not exists sp_thresholds (
  id uuid primary key references schools(id) on delete cascade,
  school_id uuid unique not null references schools(id) on delete cascade,
  sp1 integer not null default 30,
  sp2 integer not null default 60,
  sp3 integer not null default 90,
  updated_at bigint,
  updated_by text default ''
);

create table if not exists backup_history (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  filename text not null,
  file_size text default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  created_by text default '',
  summary jsonb default '{}'::jsonb
);

create index if not exists students_school_idx on students(school_id);
create index if not exists cases_school_timestamp_idx on cases(school_id, timestamp desc);
create index if not exists warning_letters_school_idx on warning_letters(school_id);
create index if not exists backup_history_school_idx on backup_history(school_id, created_at desc);

create or replace function public.is_school_member(target_school uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from school_members where school_id = target_school and user_id = auth.uid());
$$;

create or replace function public.can_manage_school(target_school uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from school_members where school_id = target_school and user_id = auth.uid() and role in ('owner', 'bk'));
$$;

create or replace function public.lookup_school_by_code(p_school_code text)
returns table(id uuid, name text)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select s.id, s.name
  from public.schools s
  where s.school_code = upper(btrim(coalesce(p_school_code, '')))
  limit 1;
$$;

revoke all on function public.lookup_school_by_code(text) from public;
grant execute on function public.lookup_school_by_code(text) to anon, authenticated;

create or replace function public.claim_school_membership(p_school_code text, p_full_name text default null)
returns table(school_id uuid, school_name text)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  current_email text := coalesce(auth.jwt() ->> 'email', '');
  selected_school public.schools%rowtype;
  safe_name text := nullif(btrim(coalesce(p_full_name, '')), '');
begin
  if current_user_id is null then
    raise exception 'Silakan login setelah memverifikasi email.' using errcode = '28000';
  end if;

  select * into selected_school
  from public.schools
  where school_code = upper(btrim(coalesce(p_school_code, '')))
  limit 1;

  if selected_school.id is null then
    raise exception 'Kode sekolah tidak ditemukan. Periksa kembali kode dari sekolah.' using errcode = 'P0002';
  end if;

  insert into public.profiles (id, full_name, email)
  values (current_user_id, coalesce(safe_name, nullif(current_email, ''), 'Admin'), current_email)
  on conflict (id) do update
    set full_name = coalesce(nullif(excluded.full_name, ''), public.profiles.full_name),
        email = coalesce(nullif(excluded.email, ''), public.profiles.email);

  insert into public.school_members (school_id, user_id, role)
  values (selected_school.id, current_user_id, 'bk')
  on conflict (school_id, user_id) do nothing;

  return query select selected_school.id, selected_school.name;
end;
$$;

revoke all on function public.claim_school_membership(text, text) from public, anon;
grant execute on function public.claim_school_membership(text, text) to authenticated;

-- Preserve existing credentials, then remove them from member-readable student rows.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'students' and column_name = 'password'
  ) then
    execute $migration$
      insert into public.student_credentials (school_id, student_id, password)
      select school_id, id, password from public.students
      where nullif(password, '') is not null
      on conflict (student_id) do update
        set school_id = excluded.school_id, password = excluded.password
    $migration$;
    alter table public.students drop column password;
  end if;
end $$;

alter table student_credentials enable row level security;
drop policy if exists credential_read on student_credentials;
drop policy if exists credential_write on student_credentials;
create policy credential_read on student_credentials for select to authenticated
  using (public.can_manage_school(school_id));
create policy credential_write on student_credentials for all to authenticated
  using (public.can_manage_school(school_id)) with check (public.can_manage_school(school_id));

-- Apply the same isolation rule to every tenant table.
do $$
declare table_name text;
begin
  foreach table_name in array array['students','classes','case_types','cases','warning_letters','announcements','school_settings','sp_thresholds','backup_history'] loop
    execute format('alter table %I enable row level security', table_name);
    execute format('drop policy if exists tenant_read on %I', table_name);
    execute format('drop policy if exists tenant_write on %I', table_name);
    execute format('create policy tenant_read on %I for select to authenticated using (public.is_school_member(school_id))', table_name);
    execute format('create policy tenant_write on %I for all to authenticated using (public.can_manage_school(school_id)) with check (public.can_manage_school(school_id))', table_name);
  end loop;
end $$;

alter table school_members enable row level security;
drop policy if exists member_read on school_members;
create policy member_read on school_members for select to authenticated using (user_id = auth.uid() or public.can_manage_school(school_id));

-- Protect account and tenant metadata as well.
alter table schools enable row level security;
drop policy if exists school_read on schools;
create policy school_read on schools for select to authenticated using (public.is_school_member(id));

alter table profiles enable row level security;
drop policy if exists profile_read on profiles;
create policy profile_read on profiles for select to authenticated using (id = auth.uid());
