-- AIRGRAM social foundation. Applied to the connected Supabase project.
-- All tables are additive and use the airgram_ prefix.
create extension if not exists pgcrypto;

create table if not exists public.airgram_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check (username ~ '^[a-zA-Z0-9_.]{3,30}$'),
 display_name text not null default '' check (char_length(display_name)<=80),
 bio text not null default '' check (char_length(bio)<=300),
 avatar_url text,
 is_private boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.airgram_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade,
 caption text not null default '' check (char_length(caption)<=2200),
 alt_text text not null default '' check (char_length(alt_text)<=1000),
 visibility text not null default 'public' check (visibility in ('public','followers','private')),
 status text not null default 'published' check (status in ('draft','scheduled','published','archived')),
 scheduled_at timestamptz,
 pinned_position smallint check (pinned_position between 1 and 3),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.airgram_post_media (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.airgram_posts(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 storage_path text not null,
 media_type text not null check (media_type in ('image','video')),
 position smallint not null check (position between 1 and 20),
 width integer, height integer, duration_seconds numeric(8,2),
 created_at timestamptz not null default now(), unique(post_id,position)
);
create table if not exists public.airgram_follows (
 follower_id uuid not null references auth.users(id) on delete cascade,
 followed_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'accepted' check(status in ('pending','accepted')),
 created_at timestamptz not null default now(),
 primary key(follower_id,followed_id), check(follower_id<>followed_id)
);
create table if not exists public.airgram_likes (
 user_id uuid not null references auth.users(id) on delete cascade,
 post_id uuid not null references public.airgram_posts(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,post_id)
);
create table if not exists public.airgram_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.airgram_posts(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade,
 parent_id uuid references public.airgram_comments(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 2200),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.airgram_saves (
 user_id uuid not null references auth.users(id) on delete cascade,
 post_id uuid not null references public.airgram_posts(id) on delete cascade,
 collection_name text not null default 'Saved' check(char_length(collection_name)<=60),
 created_at timestamptz not null default now(), primary key(user_id,post_id)
);
create table if not exists public.airgram_stories (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade,
 storage_path text not null,
 media_type text not null check(media_type in ('image','video','text')),
 caption text not null default '' check(char_length(caption)<=500),
 audience text not null default 'followers' check(audience in ('public','followers','close_friends')),
 expires_at timestamptz not null default(now()+interval '24 hours'),
 created_at timestamptz not null default now()
);
create table if not exists public.airgram_story_views (
 story_id uuid not null references public.airgram_stories(id) on delete cascade,
 viewer_id uuid not null references auth.users(id) on delete cascade,
 viewed_at timestamptz not null default now(), primary key(story_id,viewer_id)
);
create table if not exists public.airgram_conversations (
 id uuid primary key default gen_random_uuid(),
 kind text not null default 'direct' check(kind in ('direct','group','room')),
 title text check(char_length(title)<=100),
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.airgram_conversation_members (
 conversation_id uuid not null references public.airgram_conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check(role in ('owner','admin','member')),
 joined_at timestamptz not null default now(), primary key(conversation_id,user_id)
);
create table if not exists public.airgram_messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.airgram_conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null default '' check(char_length(body)<=10000),
 media_path text,
 message_type text not null default 'text' check(message_type in ('text','image','video','file','voice','system')),
 reply_to uuid references public.airgram_messages(id) on delete set null,
 expires_at timestamptz, edited_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.airgram_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references auth.users(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,
 kind text not null check(kind in ('follow','like','comment','mention','message','story_view','live')),
 entity_id uuid, is_read boolean not null default false, created_at timestamptz not null default now()
);
create table if not exists public.airgram_blocks (
 blocker_id uuid not null references auth.users(id) on delete cascade,
 blocked_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id<>blocked_id)
);
create table if not exists public.airgram_reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references auth.users(id) on delete cascade,
 target_user_id uuid references auth.users(id) on delete set null,
 post_id uuid references public.airgram_posts(id) on delete cascade,
 reason text not null check(char_length(reason) between 3 and 500),
 status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now(), check(target_user_id is not null or post_id is not null)
);
create table if not exists public.airgram_drafts (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 draft_type text not null default 'post' check(draft_type in ('post','reel','story')),
 payload jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);

do $$
declare t text;
begin
 foreach t in array array['airgram_profiles','airgram_posts','airgram_post_media','airgram_follows','airgram_likes','airgram_comments','airgram_saves','airgram_stories','airgram_story_views','airgram_conversations','airgram_conversation_members','airgram_messages','airgram_notifications','airgram_blocks','airgram_reports','airgram_drafts'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop;
end $$;

create index if not exists airgram_posts_feed_idx on public.airgram_posts(status,visibility,created_at desc);
create index if not exists airgram_posts_author_idx on public.airgram_posts(author_id,created_at desc);
create index if not exists airgram_comments_post_idx on public.airgram_comments(post_id,created_at);
create index if not exists airgram_messages_conversation_idx on public.airgram_messages(conversation_id,created_at desc);
create index if not exists airgram_stories_expiry_idx on public.airgram_stories(expires_at);
create index if not exists airgram_notifications_recipient_idx on public.airgram_notifications(recipient_id,is_read,created_at desc);

-- Policies below are intentionally authenticated-only; data access remains owner/member scoped.
create policy "airgram profiles readable" on public.airgram_profiles for select to authenticated using(true);
create policy "airgram profile owner insert" on public.airgram_profiles for insert to authenticated with check(id=(select auth.uid()));
create policy "airgram profile owner update" on public.airgram_profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy "airgram published posts readable" on public.airgram_posts for select to authenticated using((status='published' and visibility='public') or author_id=(select auth.uid()) or (status='published' and visibility='followers' and exists(select 1 from public.airgram_follows f where f.follower_id=(select auth.uid()) and f.followed_id=author_id and f.status='accepted')));
create policy "airgram post owner insert" on public.airgram_posts for insert to authenticated with check(author_id=(select auth.uid()));
create policy "airgram post owner update" on public.airgram_posts for update to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy "airgram post owner delete" on public.airgram_posts for delete to authenticated using(author_id=(select auth.uid()));
create policy "airgram media visible with post" on public.airgram_post_media for select to authenticated using(exists(select 1 from public.airgram_posts p where p.id=post_id));
create policy "airgram media owner insert" on public.airgram_post_media for insert to authenticated with check(owner_id=(select auth.uid()) and exists(select 1 from public.airgram_posts p where p.id=post_id and p.author_id=(select auth.uid())));
create policy "airgram media owner delete" on public.airgram_post_media for delete to authenticated using(owner_id=(select auth.uid()));
create policy "airgram follows visible to participants" on public.airgram_follows for select to authenticated using(follower_id=(select auth.uid()) or followed_id=(select auth.uid()));
create policy "airgram follow as self" on public.airgram_follows for insert to authenticated with check(follower_id=(select auth.uid()));
create policy "airgram unfollow as self" on public.airgram_follows for delete to authenticated using(follower_id=(select auth.uid()));
create policy "airgram follow response" on public.airgram_follows for update to authenticated using(followed_id=(select auth.uid())) with check(followed_id=(select auth.uid()));
create policy "airgram likes visible" on public.airgram_likes for select to authenticated using(true);
create policy "airgram like as self" on public.airgram_likes for insert to authenticated with check(user_id=(select auth.uid()));
create policy "airgram unlike as self" on public.airgram_likes for delete to authenticated using(user_id=(select auth.uid()));
create policy "airgram comments visible with post" on public.airgram_comments for select to authenticated using(exists(select 1 from public.airgram_posts p where p.id=post_id));
create policy "airgram comment as self" on public.airgram_comments for insert to authenticated with check(author_id=(select auth.uid()));
create policy "airgram comment owner update" on public.airgram_comments for update to authenticated using(author_id=(select auth.uid())) with check(author_id=(select auth.uid()));
create policy "airgram comment owner delete" on public.airgram_comments for delete to authenticated using(author_id=(select auth.uid()));
create policy "airgram saves private" on public.airgram_saves for select to authenticated using(user_id=(select auth.uid()));
create policy "airgram save as self" on public.airgram_saves for insert to authenticated with check(user_id=(select auth.uid()));
create policy "airgram unsave as self" on public.airgram_saves for delete to authenticated using(user_id=(select auth.uid()));
create policy "airgram stories visible" on public.airgram_stories for select to authenticated using(expires_at>now() and (audience='public' or author_id=(select auth.uid()) or exists(select 1 from public.airgram_follows f where f.follower_id=(select auth.uid()) and f.followed_id=author_id and f.status='accepted')));
create policy "airgram story owner insert" on public.airgram_stories for insert to authenticated with check(author_id=(select auth.uid()));
create policy "airgram story owner delete" on public.airgram_stories for delete to authenticated using(author_id=(select auth.uid()));
create policy "airgram story views participants" on public.airgram_story_views for select to authenticated using(viewer_id=(select auth.uid()) or exists(select 1 from public.airgram_stories s where s.id=story_id and s.author_id=(select auth.uid())));
create policy "airgram story view as self" on public.airgram_story_views for insert to authenticated with check(viewer_id=(select auth.uid()));
create policy "airgram conversation members read" on public.airgram_conversations for select to authenticated using(exists(select 1 from public.airgram_conversation_members m where m.conversation_id=id and m.user_id=(select auth.uid())));
create policy "airgram conversation creator" on public.airgram_conversations for insert to authenticated with check(created_by=(select auth.uid()));
create policy "airgram member list visible to members" on public.airgram_conversation_members for select to authenticated using(exists(select 1 from public.airgram_conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid())));
create policy "airgram creator adds members" on public.airgram_conversation_members for insert to authenticated with check(exists(select 1 from public.airgram_conversations c where c.id=conversation_id and c.created_by=(select auth.uid())));
create policy "airgram member leaves" on public.airgram_conversation_members for delete to authenticated using(user_id=(select auth.uid()));
create policy "airgram messages visible to members" on public.airgram_messages for select to authenticated using(exists(select 1 from public.airgram_conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid())));
create policy "airgram message send as member" on public.airgram_messages for insert to authenticated with check(sender_id=(select auth.uid()) and exists(select 1 from public.airgram_conversation_members m where m.conversation_id=conversation_id and m.user_id=(select auth.uid())));
create policy "airgram message edit own" on public.airgram_messages for update to authenticated using(sender_id=(select auth.uid())) with check(sender_id=(select auth.uid()));
create policy "airgram message delete own" on public.airgram_messages for delete to authenticated using(sender_id=(select auth.uid()));
create policy "airgram notifications private" on public.airgram_notifications for select to authenticated using(recipient_id=(select auth.uid()));
create policy "airgram notifications mark read" on public.airgram_notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
create policy "airgram notifications insert actor" on public.airgram_notifications for insert to authenticated with check(actor_id=(select auth.uid()));
create policy "airgram blocks private" on public.airgram_blocks for select to authenticated using(blocker_id=(select auth.uid()));
create policy "airgram block as self" on public.airgram_blocks for insert to authenticated with check(blocker_id=(select auth.uid()));
create policy "airgram unblock as self" on public.airgram_blocks for delete to authenticated using(blocker_id=(select auth.uid()));
create policy "airgram reports private" on public.airgram_reports for select to authenticated using(reporter_id=(select auth.uid()));
create policy "airgram report as self" on public.airgram_reports for insert to authenticated with check(reporter_id=(select auth.uid()));
create policy "airgram drafts private" on public.airgram_drafts for all to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('airgram-media','airgram-media',false,104857600,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','audio/mpeg','audio/mp4'])
on conflict(id) do nothing;
create policy "airgram media read authenticated" on storage.objects for select to authenticated using(bucket_id='airgram-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "airgram media upload own folder" on storage.objects for insert to authenticated with check(bucket_id='airgram-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "airgram media update own folder" on storage.objects for update to authenticated using(bucket_id='airgram-media' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='airgram-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "airgram media delete own folder" on storage.objects for delete to authenticated using(bucket_id='airgram-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
