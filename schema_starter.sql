create table public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text unique,
  category text,
  description text,
  address_line1 text,
  address_line2 text,
  city text,
  region text,
  postcode text,
  phone text,
  website text,
  email text,
  latitude numeric,
  longitude numeric,
  payment_link text,
  invoice_visibility boolean not null default true,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.place_ratings (
  id uuid primary key default gen_random_uuid(),
  business_profile_id uuid not null references public.business_profiles(id) on delete cascade,
  rating numeric(2,1) not null check (rating >= 0 and rating <= 5),
  review_count integer not null default 0,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  business_profile_id uuid not null references public.business_profiles(id) on delete cascade,
  client_name text,
  invoice_number text,
  invoice_url text,
  status text not null default 'unpaid',
  amount numeric(12,2),
  currency text default 'GBP',
  issued_at timestamptz,
  due_at timestamptz,
  created_at timestamptz not null default now()
);

create index on public.place_ratings (business_profile_id);
create index on public.invoices (business_profile_id);
