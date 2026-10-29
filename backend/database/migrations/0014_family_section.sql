-- SPEC-003 CA-06 / SPEC-013 CA-03–06 / SPEC-019 CA-04.
-- Keep removed members as credit/audit subjects while excluding them from active access.
alter table app.members add column if not exists removed_at timestamptz;

create index if not exists members_active_family_idx
  on app.members (family_id, created_at, id) where removed_at is null;

-- An evaluated or manually closed Kids signal remains available to administrators
-- for audit, but no longer appears in the current review queue.
alter table app.kids_signals
  add column if not exists decision text
    check (decision in ('confirmed', 'rejected', 'closedByManualCompletion')),
  add column if not exists decided_by_id uuid,
  add column if not exists decided_at timestamptz;

create index if not exists kids_signals_current_queue_idx
  on app.kids_signals (family_id, created_at, id)
  where discarded_at is null;

revoke all on all tables in schema app from anon, authenticated;
