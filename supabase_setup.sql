-- FandomVerse: execute este script no SQL Editor do Supabase.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Fã',
  favorite_fandom text default '',
  bio text default '',
  updated_at timestamptz default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  caption text default '',
  category text not null default 'Fotos' check (category in ('Fotos','Edits','Fanart','Momentos')),
  image_url text not null,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(post_id,user_id)
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.likes enable row level security;

drop policy if exists "Profiles are public" on public.profiles;
create policy "Profiles are public" on public.profiles for select using (true);
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Posts are public" on public.posts;
create policy "Posts are public" on public.posts for select using (true);
drop policy if exists "Authenticated users publish" on public.posts;
create policy "Authenticated users publish" on public.posts for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Authors delete own posts" on public.posts;
create policy "Authors delete own posts" on public.posts for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "Likes are public" on public.likes;
create policy "Likes are public" on public.likes for select using (true);
drop policy if exists "Users add own likes" on public.likes;
create policy "Users add own likes" on public.likes for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Users remove own likes" on public.likes;
create policy "Users remove own likes" on public.likes for delete to authenticated using (auth.uid() = user_id);

-- Bucket público para leitura das imagens; upload limitado a usuários autenticados.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fandom-images','fandom-images',true,8388608,array['image/png','image/jpeg','image/webp','image/gif'])
on conflict (id) do update set public=true, file_size_limit=8388608,
allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif'];

drop policy if exists "Public can view fandom images" on storage.objects;
create policy "Public can view fandom images" on storage.objects for select using (bucket_id='fandom-images');
drop policy if exists "Users upload to own folder" on storage.objects;
create policy "Users upload to own folder" on storage.objects for insert to authenticated
with check (bucket_id='fandom-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users delete own images" on storage.objects;
create policy "Users delete own images" on storage.objects for delete to authenticated
using (bucket_id='fandom-images' and (storage.foldername(name))[1]=auth.uid()::text);
