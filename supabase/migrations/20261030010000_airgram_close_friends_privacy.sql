-- Add private close-friends membership and enforce story audience boundaries.
create table if not exists public.airgram_close_friends (
  owner_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(owner_id, friend_id),
  check(owner_id <> friend_id)
);
alter table public.airgram_close_friends enable row level security;
grant select, insert, delete on public.airgram_close_friends to authenticated;
create policy "airgram close friends private" on public.airgram_close_friends for select to authenticated using(owner_id=(select auth.uid()));
create policy "airgram close friends add self" on public.airgram_close_friends for insert to authenticated with check(owner_id=(select auth.uid()));
create policy "airgram close friends remove self" on public.airgram_close_friends for delete to authenticated using(owner_id=(select auth.uid()));
drop policy if exists "airgram stories visible" on public.airgram_stories;
create policy "airgram stories visible" on public.airgram_stories for select to authenticated using (
 expires_at > now() and (
  author_id = (select auth.uid()) or audience = 'public'
  or (audience = 'followers' and exists (
   select 1 from public.airgram_follows f where f.follower_id=(select auth.uid()) and f.followed_id=author_id and f.status='accepted'
  ))
  or (audience = 'close_friends' and exists (
   select 1 from public.airgram_close_friends cf where cf.owner_id=author_id and cf.friend_id=(select auth.uid())
  ))
 )
);
