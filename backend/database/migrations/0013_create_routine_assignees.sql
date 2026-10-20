-- 0013 — Responsáveis padrão da rotina (SPEC-008 Fase 1 / SCRUM-43).
--
-- `assigneeIds` é um campo de configuração da própria rotina (dicionário de
-- campos da SPEC-008 §5.1), devolvido mesmo antes de qualquer ocorrência ser
-- materializada (ex.: início além do horizonte). `app.task_assignees` não
-- serve para isso: referencia `task_occurrences`, não a rotina. Esta tabela
-- segue exatamente o mesmo formato de `app.task_assignees` (0005) e alimenta
-- os responsáveis copiados para cada ocorrência nova em `materializeBatch`.

create table app.routine_assignees (
  family_id  uuid not null,
  routine_id uuid not null,
  member_id  uuid not null,
  primary key (routine_id, member_id),
  foreign key (family_id, routine_id)
    references app.routines (family_id, id) on delete restrict,
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete restrict
);

create index routine_assignees_member_idx
  on app.routine_assignees (family_id, member_id, routine_id);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
