-- SPEC-009 CA-13–15: messages remain available independently of APNs.
create table app.family_applause (
  id uuid primary key,
  family_id uuid not null references app.families (id),
  sender_member_id uuid not null,
  recipient_member_id uuid not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  dismissed_at timestamptz,
  check (sender_member_id <> recipient_member_id),
  check (start_date <= end_date),
  foreign key (family_id, sender_member_id) references app.members (family_id, id),
  foreign key (family_id, recipient_member_id) references app.members (family_id, id)
);

create index family_applause_recipient_visible_idx
  on app.family_applause (family_id, recipient_member_id, created_at desc)
  where dismissed_at is null;

create index family_applause_range_idx
  on app.family_applause (family_id, start_date, end_date, recipient_member_id);

create table app.family_applause_push_outbox (
  id uuid primary key,
  applause_id uuid not null references app.family_applause (id),
  push_device_id uuid not null references app.push_devices (id),
  state text not null default 'pending' check (state in ('pending', 'acceptedByProvider', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  accepted_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (applause_id, push_device_id)
);

create index family_applause_push_pending_idx
  on app.family_applause_push_outbox (next_attempt_at, id)
  where state = 'pending';

create index family_applause_push_device_idx
  on app.family_applause_push_outbox (push_device_id);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
