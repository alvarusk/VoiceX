-- Projects
create table if not exists projects (
  project_id text primary key,
  owner_user_id uuid not null,
  title text not null,
  folder text default '',
  archived boolean default false,
  created_at_ms bigint not null,
  updated_at_ms bigint not null,
  base_ass_path text not null,
  export_mode text default 'CLEAN_TRANSLATION_ONLY',
  strict_export boolean default true,
  current_index int default 0,
  auto_play_line boolean default false
);

-- Project files (base/engines/video)
create table if not exists project_files (
  file_id text primary key,
  project_id text not null references projects(project_id) on delete cascade,
  owner_user_id uuid not null,
  engine text not null,
  ass_path text not null,
  imported_at_ms bigint not null,
  dialogue_count int default 0,
  unmatched_count int default 0,
  unique(project_id, engine)
);

-- Subtitle lines
create table if not exists subtitle_lines (
  line_id text primary key,
  project_id text not null references projects(project_id) on delete cascade,
  owner_user_id uuid not null,
  dialogue_index int not null,
  events_row_index int not null,
  start_ms int not null,
  end_ms int not null,
  style text,
  name text,
  effect text,
  source_text text,
  romanization text,
  gloss text,
  dialogue_prefix text not null,
  leading_tags text default '',
  has_vector_drawing boolean default false,
  original_text text not null,
  cand_gpt text,
  cand_claude text,
  cand_gemini text,
  cand_deepseek text,
  cand_voice text,
  selected_source text,
  selected_text text,
  reviewed boolean default false,
  doubt boolean default false,
  updated_at_ms bigint not null,
  unique(project_id, dialogue_index)
);

-- Selection events (opcional)
create table if not exists selection_events (
  event_id bigint generated always as identity primary key,
  project_id text not null references projects(project_id) on delete cascade,
  owner_user_id uuid not null,
  line_id text not null references subtitle_lines(line_id) on delete cascade,
  chosen_source text not null,
  chosen_text text not null,
  at_ms bigint not null,
  method text not null
);

-- Storage bucket (settings/meta/files)
-- prefs/users/<owner_user_id>/settings.json guarda ajustes por usuario
insert into storage.buckets (id, name, public)
values ('voicex', 'voicex', false)
on conflict (id) do nothing;

-- RLS + grants for cloud sync tables.
-- The app uses the authenticated user's JWT and upserts rows by owner_user_id.
alter table public.projects enable row level security;
alter table public.project_files enable row level security;
alter table public.subtitle_lines enable row level security;
alter table public.selection_events enable row level security;

grant select, insert, update, delete on table public.projects to authenticated;
grant select, insert, update, delete on table public.project_files to authenticated;
grant select, insert, update, delete on table public.subtitle_lines to authenticated;
grant select, insert, update, delete on table public.selection_events to authenticated;

drop policy if exists "projects_select_own" on public.projects;
drop policy if exists "projects_select_owner" on public.projects;
create policy "projects_select_own"
on public.projects
for select
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "projects_insert_own" on public.projects;
drop policy if exists "projects_insert_owner" on public.projects;
create policy "projects_insert_own"
on public.projects
for insert
to authenticated
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "projects_update_own" on public.projects;
drop policy if exists "projects_update_owner" on public.projects;
create policy "projects_update_own"
on public.projects
for update
to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "projects_delete_own" on public.projects;
drop policy if exists "projects_delete_owner" on public.projects;
create policy "projects_delete_own"
on public.projects
for delete
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "project_files_select_own" on public.project_files;
drop policy if exists "project_files_select_owner" on public.project_files;
drop policy if exists "project_files_select_on_owner" on public.project_files;
create policy "project_files_select_own"
on public.project_files
for select
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "project_files_insert_own" on public.project_files;
drop policy if exists "project_files_insert_owner" on public.project_files;
drop policy if exists "project_files_insert_on_owner" on public.project_files;
create policy "project_files_insert_own"
on public.project_files
for insert
to authenticated
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "project_files_update_own" on public.project_files;
drop policy if exists "project_files_update_owner" on public.project_files;
drop policy if exists "project_files_update_on_owner" on public.project_files;
create policy "project_files_update_own"
on public.project_files
for update
to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "project_files_delete_own" on public.project_files;
drop policy if exists "project_files_delete_owner" on public.project_files;
drop policy if exists "project_files_delete_on_owner" on public.project_files;
create policy "project_files_delete_own"
on public.project_files
for delete
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "subtitle_lines_select_own" on public.subtitle_lines;
drop policy if exists "subtitle_lines_select_owner" on public.subtitle_lines;
drop policy if exists "subtitle_lines_select_on_owner" on public.subtitle_lines;
create policy "subtitle_lines_select_own"
on public.subtitle_lines
for select
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "subtitle_lines_insert_own" on public.subtitle_lines;
drop policy if exists "subtitle_lines_insert_owner" on public.subtitle_lines;
drop policy if exists "subtitle_lines_insert_on_owner" on public.subtitle_lines;
create policy "subtitle_lines_insert_own"
on public.subtitle_lines
for insert
to authenticated
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "subtitle_lines_update_own" on public.subtitle_lines;
drop policy if exists "subtitle_lines_update_owner" on public.subtitle_lines;
drop policy if exists "subtitle_lines_update_on_owner" on public.subtitle_lines;
create policy "subtitle_lines_update_own"
on public.subtitle_lines
for update
to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "subtitle_lines_delete_own" on public.subtitle_lines;
drop policy if exists "subtitle_lines_delete_owner" on public.subtitle_lines;
drop policy if exists "subtitle_lines_delete_on_owner" on public.subtitle_lines;
create policy "subtitle_lines_delete_own"
on public.subtitle_lines
for delete
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "selection_events_select_own" on public.selection_events;
drop policy if exists "selection_events_select_owner" on public.selection_events;
drop policy if exists "selection_events_select_on_owner" on public.selection_events;
create policy "selection_events_select_own"
on public.selection_events
for select
to authenticated
using ((select auth.uid()) = owner_user_id);

drop policy if exists "selection_events_insert_own" on public.selection_events;
drop policy if exists "selection_events_insert_owner" on public.selection_events;
drop policy if exists "selection_events_insert_on_owner" on public.selection_events;
create policy "selection_events_insert_own"
on public.selection_events
for insert
to authenticated
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "selection_events_update_own" on public.selection_events;
drop policy if exists "selection_events_update_owner" on public.selection_events;
drop policy if exists "selection_events_update_on_owner" on public.selection_events;
create policy "selection_events_update_own"
on public.selection_events
for update
to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);

drop policy if exists "selection_events_delete_own" on public.selection_events;
drop policy if exists "selection_events_delete_owner" on public.selection_events;
drop policy if exists "selection_events_delete_on_owner" on public.selection_events;
create policy "selection_events_delete_own"
on public.selection_events
for delete
to authenticated
using ((select auth.uid()) = owner_user_id);

-- Storage policies for the private "voicex" bucket.
-- Uploads use upsert(), so select + update are required in addition to insert.
grant select, insert, update, delete on table storage.objects to authenticated;

drop policy if exists "voicex authenticated insert" on storage.objects;
drop policy if exists "voicex authenticated upload" on storage.objects;
drop policy if exists "voicex insert own" on storage.objects;
drop policy if exists "voicex write" on storage.objects;
drop policy if exists "voicex_objects_select_own" on storage.objects;
drop policy if exists "voicex read" on storage.objects;
drop policy if exists "voicex read own" on storage.objects;
create policy "voicex_objects_select_own"
on storage.objects
for select
to authenticated
using (bucket_id = 'voicex' and owner_id = (select auth.uid()::text));

drop policy if exists "voicex_objects_insert_bucket" on storage.objects;
drop policy if exists "voicex authenticated upload (owned)" on storage.objects;
create policy "voicex_objects_insert_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'voicex' and owner_id = (select auth.uid()::text));

drop policy if exists "voicex_objects_update_own" on storage.objects;
drop policy if exists "voicex update" on storage.objects;
drop policy if exists "voicex update own" on storage.objects;
create policy "voicex_objects_update_own"
on storage.objects
for update
to authenticated
using (bucket_id = 'voicex' and owner_id = (select auth.uid()::text))
with check (bucket_id = 'voicex' and owner_id = (select auth.uid()::text));

drop policy if exists "voicex_objects_delete_own" on storage.objects;
drop policy if exists "voicex delete" on storage.objects;
drop policy if exists "voicex delete own" on storage.objects;
create policy "voicex_objects_delete_own"
on storage.objects
for delete
to authenticated
using (bucket_id = 'voicex' and owner_id = (select auth.uid()::text));
