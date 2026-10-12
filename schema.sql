-- MarketFlow schema for Supabase. Run in SQL Editor as project owner.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'requester' check (role in ('admin','approver','buyer','warehouse','requester','viewer')),
  department text,
  created_at timestamptz not null default now()
);

create table if not exists public.procurement_requests (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  kind text not null check (kind in ('PR','PO')),
  category text not null default 'อื่น ๆ',
  amount numeric(14,2) not null check (amount > 0),
  status text not null default 'รออนุมัติ' check (status in ('รออนุมัติ','อนุมัติแล้ว','ไม่อนุมัติ','รอสั่งซื้อ','ยืนยันการสั่งซื้อแล้ว','รอตรวจรับ','ตรวจรับแล้ว')),
  requester text not null,
  requester_id uuid references auth.users(id),
  quantity integer not null default 1 check (quantity > 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.procurement_requests(id) on delete cascade,
  quantity_received integer not null check (quantity_received >= 0),
  notes text,
  received_by uuid references auth.users(id),
  received_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  request_id uuid references public.procurement_requests(id) on delete cascade,
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.current_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid()) $$;

alter table public.profiles enable row level security;
alter table public.procurement_requests enable row level security;
alter table public.receipts enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "profiles read staff" on public.profiles;
create policy "profiles read staff" on public.profiles for select to authenticated using (public.is_staff() and (id=auth.uid() or public.current_role()='admin'));
drop policy if exists "profiles update self or admin" on public.profiles;
create policy "profiles update self or admin" on public.profiles for update to authenticated using (id=auth.uid() or public.current_role()='admin') with check (id=auth.uid() or public.current_role()='admin');
drop policy if exists "request staff read" on public.procurement_requests;
create policy "request staff read" on public.procurement_requests for select to authenticated using (public.is_staff());
drop policy if exists "request staff create" on public.procurement_requests;
create policy "request staff create" on public.procurement_requests for insert to authenticated with check (public.is_staff() and requester_id=auth.uid());
drop policy if exists "request authorized update" on public.procurement_requests;
create policy "request authorized update" on public.procurement_requests for update to authenticated using (public.current_role() in ('admin','approver','buyer','warehouse')) with check (public.current_role() in ('admin','approver','buyer','warehouse'));
drop policy if exists "receipt staff read" on public.receipts;
create policy "receipt staff read" on public.receipts for select to authenticated using (public.is_staff());
drop policy if exists "warehouse receipt create" on public.receipts;
create policy "warehouse receipt create" on public.receipts for insert to authenticated with check (public.current_role() in ('admin','warehouse'));
drop policy if exists "notifications own or admin read" on public.notifications;
create policy "notifications own or admin read" on public.notifications for select to authenticated using (user_id=auth.uid() or public.current_role()='admin');
drop policy if exists "notifications own update" on public.notifications;
create policy "notifications own update" on public.notifications for update to authenticated using (user_id=auth.uid() or public.current_role()='admin');
drop policy if exists "audit admin read" on public.audit_logs;
create policy "audit admin read" on public.audit_logs for select to authenticated using (public.current_role()='admin');

-- Automatically create a requester profile when a user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles(id,full_name,role) values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'requester');
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists procurement_touch_updated_at on public.procurement_requests;
create trigger procurement_touch_updated_at before update on public.procurement_requests for each row execute procedure public.touch_updated_at();

-- IMPORTANT: new accounts default to requester. An admin must assign roles to staff
-- through a trusted administrative process. Never expose the service_role key in the client.
