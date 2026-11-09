-- =====================================================================
--  Projet Immobilier : schéma initial (MVP)
--  À coller dans Supabase > SQL Editor, puis cliquer sur "Run".
--  Le script peut être relancé sans erreur sur une base vide.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Types énumérés
-- ---------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('bailleur', 'locataire');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.listing_type as enum ('chambre', 'studio', 'appartement', 'maison', 'duplex');
exception when duplicate_object then null; end $$;

do $$ begin
  -- 'suspendu' : annonce masquée automatiquement après plusieurs signalements.
  create type public.listing_status as enum ('disponible', 'loue', 'retire', 'suspendu');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.visit_status as enum ('en_attente', 'acceptee', 'refusee', 'annulee');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.report_reason as enum (
    'arnaque', 'deja_loue', 'fausses_photos', 'prix_trompeur', 'contenu_inapproprie', 'autre'
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2. Profils (1 ligne par utilisateur inscrit)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  phone       text,                       -- au format +2376XXXXXXXX
  full_name   text,
  role        public.user_role,           -- null tant que l'utilisateur n'a pas choisi
  whatsapp    text,                       -- si différent du numéro principal
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Création automatique du profil quand un compte est créé (via OTP SMS).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, case when new.phone is null or new.phone = '' then null
                       when left(new.phone, 1) = '+' then new.phone
                       else '+' || new.phone end)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 3. Logements (annonces)
-- ---------------------------------------------------------------------
create table if not exists public.listings (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references public.profiles (id) on delete cascade,
  title          text not null check (char_length(title) between 5 and 120),
  description    text check (char_length(description) <= 3000),
  type           public.listing_type not null default 'chambre',
  price_monthly  integer not null check (price_monthly > 0),            -- loyer mensuel en FCFA
  deposit        integer not null default 0 check (deposit >= 0),       -- caution en FCFA
  advance_months smallint not null default 0 check (advance_months between 0 and 24), -- mois d'avance exigés
  bedrooms       smallint check (bedrooms between 0 and 20),
  city           text not null check (char_length(city) between 2 and 60),
  neighborhood   text not null check (char_length(neighborhood) between 2 and 80),
  latitude       double precision check (latitude between -90 and 90),
  longitude      double precision check (longitude between -180 and 180),
  -- Commodités : liste de codes (voir lib/utils/amenities.dart) :
  -- forage, compteur_eneo, camwater, parking, gardien, meuble, cuisine_interne,
  -- douche_interne, carrelage, plafond, barriere, groupe_electrogene
  amenities      text[] not null default '{}',
  status         public.listing_status not null default 'disponible',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists listings_search_idx
  on public.listings (status, lower(city), lower(neighborhood), price_monthly);
create index if not exists listings_owner_idx on public.listings (owner_id);
create index if not exists listings_amenities_idx on public.listings using gin (amenities);

-- Photos d'un logement (les fichiers sont dans le bucket Storage "listing-photos")
create table if not exists public.listing_photos (
  id            uuid primary key default gen_random_uuid(),
  listing_id    uuid not null references public.listings (id) on delete cascade,
  storage_path  text not null,      -- ex : "<owner_id>/<listing_id>/1699999999.jpg"
  position      smallint not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists listing_photos_listing_idx on public.listing_photos (listing_id, position);

-- ---------------------------------------------------------------------
-- 4. Messagerie : une conversation = un locataire + un bailleur + un logement
-- ---------------------------------------------------------------------
create table if not exists public.conversations (
  id               uuid primary key default gen_random_uuid(),
  listing_id       uuid not null references public.listings (id) on delete cascade,
  tenant_id        uuid not null references public.profiles (id) on delete cascade,
  landlord_id      uuid not null references public.profiles (id) on delete cascade,
  last_message     text,
  last_message_at  timestamptz,
  created_at       timestamptz not null default now(),
  unique (listing_id, tenant_id),
  check (tenant_id <> landlord_id)
);
create index if not exists conversations_tenant_idx on public.conversations (tenant_id, last_message_at desc);
create index if not exists conversations_landlord_idx on public.conversations (landlord_id, last_message_at desc);

create table if not exists public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_id        uuid not null references public.profiles (id) on delete cascade,
  body             text not null check (char_length(body) between 1 and 2000),
  created_at       timestamptz not null default now(),
  read_at          timestamptz
);
create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at);

-- ---------------------------------------------------------------------
-- 5. Demandes de visite
-- ---------------------------------------------------------------------
create table if not exists public.visit_requests (
  id            uuid primary key default gen_random_uuid(),
  listing_id    uuid not null references public.listings (id) on delete cascade,
  tenant_id     uuid not null references public.profiles (id) on delete cascade,
  proposed_at   timestamptz not null,
  message       text check (char_length(message) <= 500),
  status        public.visit_status not null default 'en_attente',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists visit_requests_listing_idx on public.visit_requests (listing_id);
create index if not exists visit_requests_tenant_idx on public.visit_requests (tenant_id);

-- ---------------------------------------------------------------------
-- 6. Signalements d'annonces
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings (id) on delete cascade,
  reporter_id  uuid not null references public.profiles (id) on delete cascade,
  reason       public.report_reason not null,
  details      text check (char_length(details) <= 1000),
  handled      boolean not null default false,   -- à cocher par l'admin dans le tableau de bord
  created_at   timestamptz not null default now(),
  unique (listing_id, reporter_id)               -- un seul signalement par personne et par annonce
);

-- =====================================================================
-- 7. Fonctions utilitaires et déclencheurs
-- =====================================================================

-- Met à jour automatiquement la colonne updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists listings_updated_at on public.listings;
create trigger listings_updated_at before update on public.listings
  for each row execute function public.set_updated_at();

drop trigger if exists visit_requests_updated_at on public.visit_requests;
create trigger visit_requests_updated_at before update on public.visit_requests
  for each row execute function public.set_updated_at();

-- Rôle de l'utilisateur connecté (utilisé dans les politiques RLS)
create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Un bailleur ne peut pas lui-même réactiver une annonce suspendue
create or replace function public.protect_suspended_listing()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    if old.status = 'suspendu' and new.status <> 'suspendu' then
      raise exception 'Annonce suspendue suite à des signalements : contactez le support.';
    end if;
    if new.status = 'suspendu' and old.status <> 'suspendu' then
      raise exception 'Statut non autorisé.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists listings_protect_suspended on public.listings;
create trigger listings_protect_suspended before update on public.listings
  for each row execute function public.protect_suspended_listing();

-- Suspension automatique : 3 signalements non traités => annonce masquée
create or replace function public.auto_suspend_reported_listing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.reports
        where listing_id = new.listing_id and handled = false) >= 3 then
    -- Fonction "security definer" : elle s'exécute avec les droits de son
    -- propriétaire, donc le trigger de protection ci-dessus la laisse passer.
    update public.listings set status = 'suspendu'
      where id = new.listing_id and status = 'disponible';
  end if;
  return new;
end;
$$;

drop trigger if exists reports_auto_suspend on public.reports;
create trigger reports_auto_suspend after insert on public.reports
  for each row execute function public.auto_suspend_reported_listing();

-- Met à jour l'aperçu de la conversation à chaque nouveau message
create or replace function public.touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
     set last_message = left(new.body, 120),
         last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation after insert on public.messages
  for each row execute function public.touch_conversation();

-- Ouvre (ou retrouve) la conversation entre le locataire connecté et le
-- bailleur d'un logement. Appelée depuis l'app : supabase.rpc('get_or_create_conversation')
create or replace function public.get_or_create_conversation(p_listing_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_conv  uuid;
begin
  if auth.uid() is null then
    raise exception 'Connexion requise';
  end if;

  select owner_id into v_owner from public.listings
   where id = p_listing_id and status = 'disponible';
  if v_owner is null then
    raise exception 'Logement introuvable ou indisponible';
  end if;
  if v_owner = auth.uid() then
    raise exception 'Vous êtes le bailleur de ce logement';
  end if;

  insert into public.conversations (listing_id, tenant_id, landlord_id)
  values (p_listing_id, auth.uid(), v_owner)
  on conflict (listing_id, tenant_id) do nothing;

  select id into v_conv from public.conversations
   where listing_id = p_listing_id and tenant_id = auth.uid();
  return v_conv;
end;
$$;

-- Marque comme lus tous les messages reçus dans une conversation
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.messages m
     set read_at = now()
    from public.conversations c
   where m.conversation_id = p_conversation_id
     and c.id = m.conversation_id
     and auth.uid() in (c.tenant_id, c.landlord_id)
     and m.sender_id <> auth.uid()
     and m.read_at is null;
$$;

-- =====================================================================
-- 8. Sécurité : Row Level Security (RLS)
--    Sans politique explicite, PERSONNE ne peut lire ni écrire une table.
-- =====================================================================
alter table public.profiles       enable row level security;
alter table public.listings       enable row level security;
alter table public.listing_photos enable row level security;
alter table public.conversations  enable row level security;
alter table public.messages       enable row level security;
alter table public.visit_requests enable row level security;
alter table public.reports        enable row level security;

-- --- profiles ---------------------------------------------------------
drop policy if exists "profils lisibles par les connectés" on public.profiles;
create policy "profils lisibles par les connectés" on public.profiles
  for select to authenticated using (true);

drop policy if exists "chacun modifie son profil" on public.profiles;
create policy "chacun modifie son profil" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- --- listings ---------------------------------------------------------
-- Tout le monde (même non connecté) voit les annonces disponibles ;
-- le bailleur voit aussi toutes ses propres annonces.
drop policy if exists "annonces visibles" on public.listings;
create policy "annonces visibles" on public.listings
  for select to anon, authenticated
  using (status = 'disponible' or owner_id = auth.uid());

drop policy if exists "bailleur crée ses annonces" on public.listings;
create policy "bailleur crée ses annonces" on public.listings
  for insert to authenticated
  with check (owner_id = auth.uid() and public.current_user_role() = 'bailleur');

drop policy if exists "bailleur modifie ses annonces" on public.listings;
create policy "bailleur modifie ses annonces" on public.listings
  for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "bailleur supprime ses annonces" on public.listings;
create policy "bailleur supprime ses annonces" on public.listings
  for delete to authenticated using (owner_id = auth.uid());

-- --- listing_photos ---------------------------------------------------
drop policy if exists "photos visibles avec l'annonce" on public.listing_photos;
create policy "photos visibles avec l'annonce" on public.listing_photos
  for select to anon, authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id));  -- RLS de listings s'applique

drop policy if exists "bailleur gère ses photos" on public.listing_photos;
create policy "bailleur gère ses photos" on public.listing_photos
  for all to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid()))
  with check (exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid()));

-- --- conversations ----------------------------------------------------
-- Création uniquement via la fonction get_or_create_conversation().
drop policy if exists "participants voient la conversation" on public.conversations;
create policy "participants voient la conversation" on public.conversations
  for select to authenticated
  using (auth.uid() in (tenant_id, landlord_id));

-- --- messages ---------------------------------------------------------
drop policy if exists "participants lisent les messages" on public.messages;
create policy "participants lisent les messages" on public.messages
  for select to authenticated
  using (exists (
    select 1 from public.conversations c
     where c.id = conversation_id and auth.uid() in (c.tenant_id, c.landlord_id)));

drop policy if exists "participants envoient des messages" on public.messages;
create policy "participants envoient des messages" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and read_at is null
    and exists (
      select 1 from public.conversations c
       where c.id = conversation_id and auth.uid() in (c.tenant_id, c.landlord_id)));

-- --- visit_requests ---------------------------------------------------
drop policy if exists "visites visibles par locataire et bailleur" on public.visit_requests;
create policy "visites visibles par locataire et bailleur" on public.visit_requests
  for select to authenticated
  using (
    tenant_id = auth.uid()
    or exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid()));

drop policy if exists "locataire demande une visite" on public.visit_requests;
create policy "locataire demande une visite" on public.visit_requests
  for insert to authenticated
  with check (
    tenant_id = auth.uid()
    and status = 'en_attente'
    and exists (select 1 from public.listings l
                 where l.id = listing_id and l.status = 'disponible' and l.owner_id <> auth.uid()));

-- Le locataire peut annuler sa demande ; le bailleur peut l'accepter ou la refuser.
drop policy if exists "locataire annule sa visite" on public.visit_requests;
create policy "locataire annule sa visite" on public.visit_requests
  for update to authenticated
  using (tenant_id = auth.uid())
  with check (tenant_id = auth.uid() and status in ('en_attente', 'annulee'));

drop policy if exists "bailleur répond à la visite" on public.visit_requests;
create policy "bailleur répond à la visite" on public.visit_requests
  for update to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid()))
  with check (status in ('acceptee', 'refusee')
              and exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = auth.uid()));

-- --- reports ----------------------------------------------------------
-- Les signalements sont traités par l'admin depuis le tableau de bord Supabase.
drop policy if exists "chacun signale" on public.reports;
create policy "chacun signale" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and handled = false);

drop policy if exists "chacun voit ses signalements" on public.reports;
create policy "chacun voit ses signalements" on public.reports
  for select to authenticated using (reporter_id = auth.uid());

-- Droits sur colonnes : un utilisateur ne peut modifier que certains champs
-- (le numéro de téléphone vérifié par SMS ne peut donc pas être changé)
revoke update on public.profiles from authenticated;
grant update (full_name, role, whatsapp) on public.profiles to authenticated;

revoke update on public.visit_requests from authenticated;
grant update (status) on public.visit_requests to authenticated;

-- Les fonctions RPC sont réservées aux utilisateurs connectés
revoke execute on function public.get_or_create_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_conversation(uuid) to authenticated;
revoke execute on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- =====================================================================
-- 9. Stockage des photos (bucket public en lecture)
--    Chemin imposé : <id_du_bailleur>/<id_du_logement>/<fichier>.jpg
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-photos', 'listing-photos', true, 1048576, array['image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "photos lisibles par tous" on storage.objects;
create policy "photos lisibles par tous" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'listing-photos');

drop policy if exists "bailleur envoie ses photos" on storage.objects;
create policy "bailleur envoie ses photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-photos'
              and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "bailleur supprime ses photos" on storage.objects;
create policy "bailleur supprime ses photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- 10. Temps réel (chat)
-- =====================================================================
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null; end $$;
