-- SPEC-011 Fase 1 / SCRUM-56: audit a reopening as a distinct task event.
alter table app.task_events
  drop constraint if exists task_events_event_type_check;

alter table app.task_events
  add constraint task_events_event_type_check
  check (event_type in ('created', 'edited', 'deleted', 'completed', 'reopened'));
