-- =====================================================================
-- 22-206 公共采购与 AA —— Supabase 初始化脚本（宿舍口令版，室友不用注册）
-- 用法：Supabase 控制台 → SQL Editor → New query → 整段粘贴 → Run
-- 运行完，结果区会显示自动生成的「宿舍口令」，把它接在网址后面发给室友：
--     https://你的网址/#code=口令
-- 可以重复运行：不会删数据，也不会换口令。
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- 1. 表 ----------
create table if not exists public.settings (
  id     text  primary key,
  room   text  not null default '22-206',
  cur    text  not null default '$',
  roster jsonb not null default '["Simon","Gary","Harry","Yuluo"]'::jsonb
);

create table if not exists public.items (
  id         uuid primary key default gen_random_uuid(),
  no         integer not null,
  name       text    not null,
  area       text    not null default '其他',
  qty        integer not null default 1,
  priority   text    not null default '中',
  status     text    not null default '待购买',
  note       text    not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.rounds (
  id         uuid primary key default gen_random_uuid(),
  no         integer not null,
  created_at timestamptz not null default now(),
  bill_ids   uuid[]  not null default '{}',
  total      bigint  not null default 0,   -- 单位：分
  share      bigint  not null default 0,   -- 单位：分
  n          integer not null default 0,
  lines      jsonb   not null default '[]'::jsonb,
  transfers  jsonb   not null default '[]'::jsonb
);

create table if not exists public.bills (
  id         uuid primary key default gen_random_uuid(),
  no         integer not null,
  title      text    not null default '',
  date       date    not null default current_date,
  payer      text    not null,
  amount     numeric(12,2) not null check (amount > 0),
  items      integer[] not null default '{}',
  channel    text    not null default '',
  photo      text,
  round_id   uuid references public.rounds(id) on delete set null,   -- 删掉一轮结算，账单自动变回未结清
  created_at timestamptz not null default now()
);

insert into public.settings (id) values ('main') on conflict (id) do nothing;

-- ---------- 2. 宿舍口令：存在 API 访问不到的 private 架构里 ----------
create schema if not exists private;
revoke all on schema private from public;

create table if not exists private.room_secret (
  id   integer primary key check (id = 1),
  code text not null
);
insert into private.room_secret (id, code)
values (1, substr(encode(gen_random_bytes(6), 'hex'), 1, 8))
on conflict (id) do nothing;

-- 网页每次请求都带 x-room-code 请求头；这个函数比对它和库里存的口令
create or replace function public.room_ok() returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(
    (nullif(current_setting('request.headers', true), '')::json ->> 'x-room-code')
      = (select code from private.room_secret where id = 1),
    false
  );
$$;
revoke all on function public.room_ok() from public;
grant execute on function public.room_ok() to anon, authenticated;

-- 网页打开时用它确认口令对不对
create or replace function public.room_check() returns boolean
language sql stable
as $$ select public.room_ok() $$;

-- 一次请求把四张表都取回来（受下面的行级策略约束，口令不对就是空的）
create or replace function public.snapshot() returns jsonb
language sql stable
as $$
  select jsonb_build_object(
    'settings', (select to_jsonb(s) from public.settings s where s.id = 'main'),
    'items',    coalesce((select jsonb_agg(to_jsonb(i)) from public.items  i), '[]'::jsonb),
    'bills',    coalesce((select jsonb_agg(to_jsonb(b)) from public.bills  b), '[]'::jsonb),
    'rounds',   coalesce((select jsonb_agg(to_jsonb(r)) from public.rounds r), '[]'::jsonb)
  );
$$;
grant execute on function public.room_check() to anon, authenticated;
grant execute on function public.snapshot()   to anon, authenticated;

-- ---------- 3. 行级安全：口令对了才能读写 ----------
alter table public.settings enable row level security;
alter table public.items    enable row level security;
alter table public.bills    enable row level security;
alter table public.rounds   enable row level security;

do $$
declare t text;
begin
  foreach t in array array['settings','items','bills','rounds'] loop
    execute format('drop policy if exists "auth all" on public.%I', t);
    execute format('drop policy if exists "room code" on public.%I', t);
    execute format('create policy "room code" on public.%I for all to anon, authenticated using (public.room_ok()) with check (public.room_ok())', t);
  end loop;
end $$;

-- ---------- 4. 小票照片桶：公开可看（链接随机猜不到），限 5 MB 的图片 ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "receipts public read" on storage.objects;
drop policy if exists "receipts auth upload" on storage.objects;
drop policy if exists "receipts auth delete" on storage.objects;
drop policy if exists "receipts upload"      on storage.objects;
create policy "receipts public read" on storage.objects for select using (bucket_id = 'receipts');
create policy "receipts upload"      on storage.objects for insert to anon, authenticated with check (bucket_id = 'receipts');

-- ---------- 5. 显示口令 ----------
select code as "宿舍口令（接在网址后面：/#code=口令）" from private.room_secret where id = 1;
