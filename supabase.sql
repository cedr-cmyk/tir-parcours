-- Tir Parcours : table dédiée, à exécuter une fois dans Supabase > SQL Editor.
-- Ne touche à aucune table du Carnet de l'entraîneur.
create table if not exists public.parcours_items (
  owner      uuid   not null default auth.uid() references auth.users(id) on delete cascade,
  key        text   not null,              -- ex. « p-xxxx » parcours, « a-xxxx » archer, « s-xxxx » tir, « settings »
  kind       text   not null,
  updated_at bigint not null default 0,    -- horodatage de la dernière modification (ms)
  item       jsonb  not null,
  primary key (owner, key)
);

alter table public.parcours_items enable row level security;

-- Chaque compte ne voit et ne modifie que ses propres données.
drop policy if exists "parcours_items lecture"      on public.parcours_items;
drop policy if exists "parcours_items ajout"        on public.parcours_items;
drop policy if exists "parcours_items modification" on public.parcours_items;
drop policy if exists "parcours_items suppression"  on public.parcours_items;
create policy "parcours_items lecture"      on public.parcours_items for select using (auth.uid() = owner);
create policy "parcours_items ajout"        on public.parcours_items for insert with check (auth.uid() = owner);
create policy "parcours_items modification" on public.parcours_items for update using (auth.uid() = owner) with check (auth.uid() = owner);
create policy "parcours_items suppression"  on public.parcours_items for delete using (auth.uid() = owner);

-- =====================================================================
-- Espace archer (v0.4) : codes d'invitation et lien compte <-> fiche archer.
-- Tout reste propre à Tir Parcours : rien n'est partagé avec le Carnet,
-- seule la connexion (comptes Supabase) est commune.
-- =====================================================================
create table if not exists public.parcours_invitations (
  code        text primary key,
  coach       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  archer_key  text not null,              -- fiche archer de l'entraîneur (« a-xxxx »)
  archer_nom  text,
  created_at  timestamptz not null default now(),
  used_by     uuid references auth.users(id) on delete set null,
  used_at     timestamptz
);
alter table public.parcours_invitations enable row level security;
drop policy if exists "parcours_invitations entraineur" on public.parcours_invitations;
create policy "parcours_invitations entraineur" on public.parcours_invitations
  for all using (auth.uid() = coach) with check (auth.uid() = coach);

create table if not exists public.parcours_liens (
  coach        uuid not null references auth.users(id) on delete cascade,
  archer_user  uuid not null references auth.users(id) on delete cascade,
  archer_key   text not null,
  archer_nom   text,
  created_at   timestamptz not null default now(),
  primary key (coach, archer_user)
);
alter table public.parcours_liens enable row level security;
drop policy if exists "parcours_liens lecture"     on public.parcours_liens;
drop policy if exists "parcours_liens suppression" on public.parcours_liens;
create policy "parcours_liens lecture"     on public.parcours_liens for select using (auth.uid() = coach or auth.uid() = archer_user);
create policy "parcours_liens suppression" on public.parcours_liens for delete using (auth.uid() = coach or auth.uid() = archer_user);

-- L'archer saisit le code reçu : son compte est relié à sa fiche.
create or replace function public.parcours_utiliser_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare inv public.parcours_invitations;
begin
  if auth.uid() is null then raise exception 'Connectez-vous d''abord'; end if;
  select * into inv from public.parcours_invitations where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Code inconnu'; end if;
  if inv.coach = auth.uid() then raise exception 'C''est un code créé par vous-même'; end if;
  if inv.used_by is not null and inv.used_by <> auth.uid() then raise exception 'Code déjà utilisé'; end if;
  update public.parcours_invitations set used_by = auth.uid(), used_at = now() where code = inv.code;
  insert into public.parcours_liens (coach, archer_user, archer_key, archer_nom)
    values (inv.coach, auth.uid(), inv.archer_key, inv.archer_nom)
    on conflict (coach, archer_user) do update set archer_key = excluded.archer_key, archer_nom = excluded.archer_nom;
  return json_build_object('ok', true, 'archer', inv.archer_nom);
end $$;

-- L'archer lit SES résultats : seulement sa fiche, ses tirs (sans les scores des autres
-- ni les notes de l'entraîneur) et les parcours concernés. Lecture seule.
create or replace function public.parcours_mes_resultats()
returns json language plpgsql stable security definer set search_path = public as $$
declare res json;
begin
  select coalesce(json_agg(x), '[]'::json) into res from (
    select l.coach, l.archer_key, l.archer_nom,
      (select i.item from public.parcours_items i where i.owner = l.coach and i.key = l.archer_key) as archer,
      (select i.item from public.parcours_items i where i.owner = l.coach and i.key = 'settings') as settings,
      (select coalesce(json_agg(
          jsonb_set(jsonb_set(jsonb_set(i.item - 'note',
            '{scores}',    jsonb_build_object(substr(l.archer_key, 3), coalesce(i.item->'scores'->substr(l.archer_key, 3), '{}'::jsonb))),
            '{piq}',       jsonb_build_object(substr(l.archer_key, 3), coalesce(i.item->'piq'->substr(l.archer_key, 3), 'null'::jsonb))),
            '{archerIds}', jsonb_build_array(substr(l.archer_key, 3)))
        ), '[]'::json)
        from public.parcours_items i
        where i.owner = l.coach and i.kind = 's'
          and coalesce((i.item->>'deleted')::boolean, false) = false
          and i.item->'archerIds' ? substr(l.archer_key, 3)) as sessions,
      (select coalesce(json_agg(p.item), '[]'::json)
        from public.parcours_items p
        where p.owner = l.coach and p.kind = 'p'
          and p.key in (select 'p-' || (s.item->>'parcoursId') from public.parcours_items s
                        where s.owner = l.coach and s.kind = 's' and s.item->'archerIds' ? substr(l.archer_key, 3))) as parcours
    from public.parcours_liens l
    where l.archer_user = auth.uid()
  ) x;
  return res;
end $$;

revoke all on function public.parcours_utiliser_code(text) from public, anon;
revoke all on function public.parcours_mes_resultats()     from public, anon;
grant execute on function public.parcours_utiliser_code(text) to authenticated;
grant execute on function public.parcours_mes_resultats()     to authenticated;
