-- Run in Supabase SQL Editor before syncing the updated app.
alter table public.subtitle_lines
  add column if not exists cand_final text;

notify pgrst, 'reload schema';
