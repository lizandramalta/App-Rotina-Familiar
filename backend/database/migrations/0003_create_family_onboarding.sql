-- 0003 — Onboarding do Criador (SPEC-002, Fase 1).
--
-- Acrescenta o que a criação atômica da família precisa: apelido e foto no
-- membro, a reserva de mídia (BA-16) e o ciclo semanal inicial (BA-13).
--
-- BA-19: tudo no schema privado `app`, sem privilégio para `anon`/`authenticated`.

-- Reserva de mídia. O binário vive no R2 privado; o banco guarda só a chave do
-- objeto e os metadados. A reserva `UPLOADING` precede o I/O para que o worker
-- consiga reconciliar objeto órfão (backend-architecture.md §13).
create table if not exists app.media_assets (
  id              uuid        primary key,
  family_id       uuid        not null,
  owner_member_id uuid        not null,
  object_key      text        not null unique,
  purpose         text        not null check (purpose in ('PROFILE_PHOTO', 'TASK_SIGNAL')),
  state           text        not null check (state in ('UPLOADING', 'READY', 'DELETING', 'DELETED', 'FAILED')),
  size_bytes      bigint,
  content_type    text,
  created_at      timestamptz not null default now(),
  linked_at       timestamptz,
  -- Toda mídia carrega a família do titular: o banco recusa cruzar famílias.
  foreign key (family_id, owner_member_id)
    references app.members (family_id, id) on delete cascade,
  unique (family_id, id)
);

create index if not exists media_assets_owner_idx
  on app.media_assets (family_id, owner_member_id);

-- Apelido (RN63) e foto de perfil. A FK composta garante que a foto pertence à
-- mesma família do membro.
alter table app.members
  add column if not exists nickname text,
  add column if not exists photo_media_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'members_photo_media_fk'
       and conrelid = 'app.members'::regclass
  ) then
    alter table app.members
      add constraint members_photo_media_fk
      foreign key (family_id, photo_media_id)
      references app.media_assets (family_id, id);
  end if;
end $$;

-- Ciclo semanal. Segunda a domingo no fuso da família (RN28); os ciclos de uma
-- família são contíguos e identificados pelo instante de início.
create table if not exists app.weekly_cycles (
  id             uuid        primary key,
  family_id      uuid        not null references app.families (id) on delete cascade,
  starts_at      timestamptz not null,
  ends_at        timestamptz not null,
  time_zone      text        not null,
  in_transition  boolean     not null default false,
  reference_week date        not null,
  created_at     timestamptz not null default now(),
  unique (family_id, starts_at),
  check (ends_at > starts_at)
);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
