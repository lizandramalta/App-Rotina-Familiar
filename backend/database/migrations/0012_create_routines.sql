-- 0012 — Rotinas (SPEC-008 Fase 1 / SCRUM-43).
--
-- Configuração de recorrência: frequências fixas (1/7/14/21/28 dias), início
-- livre, sem data final. Reaproveita app.task_templates para título/peso/
-- observação (mesmo padrão de tarefa única) e app.task_occurrences para as
-- ocorrências materializadas. `generated_until` é o cursor de materialização
-- (última data civil já coberta, em lotes — ver RoutineRepositoryPort).

create table app.routines (
  id               uuid        primary key,
  family_id        uuid        not null,
  task_template_id uuid        not null,
  frequency_days   smallint    not null check (frequency_days in (1, 7, 14, 21, 28)),
  start_date       date        not null,
  is_active        boolean     not null default true,
  generated_until  date,
  deactivated_at   timestamptz,
  created_at       timestamptz not null,
  updated_at       timestamptz not null,
  foreign key (family_id, task_template_id)
    references app.task_templates (family_id, id) on delete restrict,
  unique (family_id, id)
);

create index routines_family_active_idx
  on app.routines (family_id, id)
  where deactivated_at is null;

-- A coluna já existe desde 0005 (SPEC-007); só faltava a rotina para validar.
alter table app.task_occurrences
  add constraint task_occurrences_routine_fk
  foreign key (family_id, routine_id)
  references app.routines (family_id, id) on delete restrict;

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
