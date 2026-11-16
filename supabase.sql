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
