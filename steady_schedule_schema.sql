create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer',
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists business_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text,
  is_public boolean not null default true,
  is_featured boolean not null default false,
  priority_level int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references business_profiles(id) on delete cascade,
  name text not null,
  duration_mins int not null default 30,
  price numeric(10,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid not null references business_profiles(id) on delete cascade,
  source text default 'starred',
  created_at timestamptz not null default now(),
  unique(user_id, business_id)
);

create table if not exists availability_slots (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references business_profiles(id) on delete cascade,
  slot_date date not null,
  slot_time time not null,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references business_profiles(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  service_id uuid references services(id) on delete set null,
  booking_date date not null,
  booking_time time not null,
  priority_flag text not null default 'standard',
  notes text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references business_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  amount numeric(10,2) not null,
  currency text not null default 'GBP',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists feature_upgrades (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references business_profiles(id) on delete cascade,
  tier text not null default 'priority',
  start_at timestamptz not null,
  end_at timestamptz not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;
alter table business_profiles enable row level security;
alter table services enable row level security;
alter table favorites enable row level security;
alter table availability_slots enable row level security;
alter table bookings enable row level security;
alter table reviews enable row level security;
alter table payments enable row level security;
alter table feature_upgrades enable row level security;

create policy "profiles read own" on profiles for select using (auth.uid() = id or auth.role() = 'service_role');
create policy "profiles update own" on profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "business public read" on business_profiles for select using (is_public = true or owner_id = auth.uid() or auth.role() = 'service_role');
create policy "business owner write" on business_profiles for insert with check (owner_id = auth.uid());
create policy "business owner update" on business_profiles for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "services public read" on services for select using (exists (select 1 from business_profiles b where b.id = business_id and (b.is_public = true or b.owner_id = auth.uid())));
create policy "services owner write" on services for insert with check (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));
create policy "services owner update" on services for update using (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid())) with check (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));

create policy "favorites own read" on favorites for select using (user_id = auth.uid());
create policy "favorites own insert" on favorites for insert with check (user_id = auth.uid());
create policy "favorites own delete" on favorites for delete using (user_id = auth.uid());

create policy "availability owner read" on availability_slots for select using (exists (select 1 from business_profiles b where b.id = business_id and (b.owner_id = auth.uid() or b.is_public = true)));
create policy "availability owner write" on availability_slots for insert with check (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));
create policy "availability owner update" on availability_slots for update using (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid())) with check (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));

create policy "bookings own read" on bookings for select using (user_id = auth.uid() or exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));
create policy "bookings own insert" on bookings for insert with check (user_id = auth.uid() or auth.role() = 'anon');
create policy "bookings own update" on bookings for update using (user_id = auth.uid() or exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid())) with check (user_id = auth.uid() or exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));

create policy "reviews public read" on reviews for select using (true);
create policy "reviews own insert" on reviews for insert with check (user_id = auth.uid());
create policy "reviews own update" on reviews for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "payments own read" on payments for select using (exists (select 1 from bookings b where b.id = booking_id and (b.user_id = auth.uid() or exists (select 1 from business_profiles bp where bp.id = b.business_id and bp.owner_id = auth.uid()))));

create policy "feature upgrades owner read" on feature_upgrades for select using (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));
create policy "feature upgrades owner write" on feature_upgrades for insert with check (exists (select 1 from business_profiles b where b.id = business_id and b.owner_id = auth.uid()));
