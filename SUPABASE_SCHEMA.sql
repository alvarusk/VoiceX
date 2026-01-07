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
  current_index int default 0
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
