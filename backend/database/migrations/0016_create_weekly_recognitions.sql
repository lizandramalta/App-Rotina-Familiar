-- SPEC-020 Fase 1 / SCRUM-102: snapshot final e intenções únicas, schema privado.
alter table app.weekly_cycles add constraint weekly_cycles_family_id_id_key unique (family_id, id);
create index weekly_cycles_due_idx on app.weekly_cycles (ends_at, family_id);

create table app.weekly_highlights (
  id uuid primary key,
  family_id uuid not null,
  cycle_id uuid not null unique,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  time_zone text not null,
  reference_week date not null,
  is_transition boolean not null,
  processed_at timestamptz not null,
  winner_count integer not null check (winner_count >= 0),
  foreign key (family_id, cycle_id) references app.weekly_cycles (family_id, id) on delete cascade,
  unique (family_id, id),
  check (ends_at > starts_at and processed_at >= ends_at)
);

create table app.weekly_recognitions (
  id uuid primary key,
  family_id uuid not null,
  highlight_id uuid not null,
  member_id uuid not null,
  points integer not null check (points > 0),
  completed_tasks integer not null check (completed_tasks > 0),
  opened_at timestamptz,
  foreign key (family_id, highlight_id) references app.weekly_highlights (family_id, id) on delete cascade,
  foreign key (family_id, member_id) references app.members (family_id, id),
  unique (highlight_id, member_id)
);
create index weekly_recognitions_owner_idx on app.weekly_recognitions (family_id, member_id, highlight_id);

-- Uma intenção por reconhecimento, inclusive quando ainda não há dispositivo.
create table app.recognition_notification_deliveries (
  recognition_id uuid primary key references app.weekly_recognitions (id) on delete cascade,
  state text not null default 'pending' check (state in ('pending', 'acceptedByProvider', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  claim_id uuid,
  accepted_at timestamptz,
  last_error text
);
create index recognition_deliveries_pending_idx on app.recognition_notification_deliveries (available_at)
  where state = 'pending';

-- Reserva curta por família; falhas/leases vencidos podem ser retomados por outro worker.
create table app.weekly_highlight_jobs (
  family_id uuid primary key references app.families (id) on delete cascade,
  state text not null default 'pending' check (state in ('pending', 'failed')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  lease_until timestamptz,
  claim_id uuid,
  last_error text
);
create index weekly_highlight_jobs_pending_idx on app.weekly_highlight_jobs (available_at)
  where state = 'pending';

revoke all on app.weekly_highlights, app.weekly_recognitions,
  app.recognition_notification_deliveries, app.weekly_highlight_jobs from public, anon, authenticated;
