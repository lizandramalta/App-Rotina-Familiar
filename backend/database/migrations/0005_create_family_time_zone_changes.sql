-- 0005 — Mudança de fuso da família (SPEC-002, Fase 3).
--
-- Guarda a alteração programada para o próximo ciclo e o histórico das
-- aplicadas/substituídas (BA-13: "com auditoria"). O fuso vigente continua em
-- `app.families.timezone`; os limites efetivos, em `app.weekly_cycles`.
--
-- BA-19: tudo no schema privado `app`, sem privilégio para `anon`/`authenticated`.

create table if not exists app.family_time_zone_changes (
  id                    uuid        primary key,
  family_id             uuid        not null references app.families (id) on delete cascade,
  requested_by_member_id uuid       not null,
  from_time_zone        text        not null,
  to_time_zone          text        not null,
  application           text        not null check (application in ('IMMEDIATE', 'NEXT_CYCLE')),
  -- SCHEDULED: aguardando o encerramento do ciclo. APPLIED: já vigente.
  -- SUPERSEDED: trocada por uma solicitação posterior antes de valer.
  status                text        not null check (status in ('SCHEDULED', 'APPLIED', 'SUPERSEDED')),
  effective_at          timestamptz not null,
  requested_at          timestamptz not null,
  resolved_at           timestamptz,
  foreign key (family_id, requested_by_member_id)
    references app.members (family_id, id),
  check (from_time_zone <> to_time_zone)
);

-- No máximo uma alteração programada por família: o banco recusa a segunda
-- mesmo que o caso de uso falhe em substituir a anterior.
create unique index if not exists family_time_zone_changes_one_scheduled_idx
  on app.family_time_zone_changes (family_id)
  where status = 'SCHEDULED';

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
