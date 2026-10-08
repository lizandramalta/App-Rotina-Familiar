-- 0005 — Tarefas únicas (SPEC-007, fases 1 e 2 / SCRUM-35).
--
-- O modelo separa template e ocorrência: uma tarefa única ganha um template e
-- uma ocorrência, sem rotina. As tabelas de missão/sinalização são fundações
-- sem rotas neste recorte, necessárias para as proteções transacionais de
-- edição e exclusão previstas na SPEC-007.

create table app.task_templates (
  id          uuid        primary key,
  family_id   uuid        not null references app.families (id) on delete restrict,
  title       text        not null,
  weight      smallint    not null check (weight between 1 and 3),
  note        text,
  deleted_at  timestamptz,
  created_at  timestamptz not null,
  updated_at  timestamptz not null,
  unique (family_id, id)
);

create table app.task_occurrences (
  id             uuid        primary key,
  family_id      uuid        not null,
  task_template_id uuid      not null,
  routine_id     uuid,
  origin_key     text        not null,
  original_date  date        not null,
  scheduled_date date        not null,
  title          text        not null,
  weight         smallint    not null check (weight between 1 and 3),
  note           text,
  status         text        not null check (status in ('pending', 'awaitingConfirmation', 'completed')),
  deleted_at     timestamptz,
  created_at     timestamptz not null,
  updated_at     timestamptz not null,
  foreign key (family_id, task_template_id)
    references app.task_templates (family_id, id) on delete restrict,
  unique (family_id, id),
  unique (task_template_id, origin_key)
);

create index task_occurrences_family_active_idx
  on app.task_occurrences (family_id, scheduled_date, id)
  where deleted_at is null;

create table app.task_assignees (
  family_id uuid not null,
  task_id   uuid not null,
  member_id uuid not null,
  primary key (task_id, member_id),
  foreign key (family_id, task_id)
    references app.task_occurrences (family_id, id) on delete restrict,
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete restrict
);

create index task_assignees_member_idx on app.task_assignees (family_id, member_id, task_id);

create table app.completions (
  id              uuid        primary key,
  family_id       uuid        not null,
  task_id         uuid        not null,
  performed_by_id uuid        not null,
  completed_at    timestamptz not null,
  undone_at       timestamptz,
  undone_by_id    uuid,
  foreign key (family_id, task_id)
    references app.task_occurrences (family_id, id) on delete restrict,
  foreign key (family_id, performed_by_id)
    references app.members (family_id, id) on delete restrict,
  foreign key (family_id, undone_by_id)
    references app.members (family_id, id) on delete restrict
);

create unique index completions_one_current_per_task_idx
  on app.completions (task_id) where undone_at is null;

create table app.completion_credits (
  completion_id uuid     not null references app.completions (id) on delete restrict,
  family_id     uuid     not null,
  member_id     uuid     not null,
  weight        smallint not null check (weight between 1 and 3),
  primary key (completion_id, member_id),
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete restrict
);

create table app.missions (
  id           uuid        primary key,
  family_id    uuid        not null references app.families (id) on delete restrict,
  title        text        not null,
  note         text,
  completed_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (family_id, id)
);

create table app.mission_tasks (
  family_id uuid not null,
  mission_id uuid not null,
  task_id    uuid not null,
  primary key (mission_id, task_id),
  foreign key (family_id, mission_id)
    references app.missions (family_id, id) on delete restrict,
  foreign key (family_id, task_id)
    references app.task_occurrences (family_id, id) on delete restrict
);

create index mission_tasks_task_idx on app.mission_tasks (family_id, task_id, mission_id);

create table app.kids_signals (
  id             uuid        primary key,
  family_id      uuid        not null,
  task_id        uuid        not null,
  signaled_by_id uuid        not null,
  photo_media_id uuid,
  discarded_at   timestamptz,
  created_at     timestamptz not null default now(),
  foreign key (family_id, task_id)
    references app.task_occurrences (family_id, id) on delete restrict,
  foreign key (family_id, signaled_by_id)
    references app.members (family_id, id) on delete restrict
);

create unique index kids_signals_one_current_per_task_idx
  on app.kids_signals (task_id) where discarded_at is null;

create table app.task_events (
  id         uuid        primary key,
  family_id  uuid        not null,
  task_id    uuid        not null,
  actor_id   uuid        not null,
  event_type text        not null check (event_type in ('created', 'edited', 'deleted')),
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null,
  foreign key (family_id, task_id)
    references app.task_occurrences (family_id, id) on delete restrict,
  foreign key (family_id, actor_id)
    references app.members (family_id, id) on delete restrict
);

create index task_events_task_idx on app.task_events (family_id, task_id, created_at);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
