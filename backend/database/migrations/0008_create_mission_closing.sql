-- 0008 — Fechamento de missões, participações e badges (SPEC-014 Fase 1 / SCRUM-66).
--
-- `app.missions` e `app.mission_tasks` já existem (0005). O estado da missão é
-- derivado de `completed_at` (nulo = inProgress), então não há coluna de status
-- a manter em sincronia. Participações e badges são concessões persistidas,
-- escritas somente por `CloseEligibleMissions` na transação da família.

create table app.mission_participations (
  family_id   uuid        not null,
  mission_id  uuid        not null,
  member_id   uuid        not null,
  recorded_at timestamptz not null,
  primary key (mission_id, member_id),
  foreign key (family_id, mission_id)
    references app.missions (family_id, id) on delete restrict,
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete restrict
);

create index mission_participations_member_idx
  on app.mission_participations (family_id, member_id, recorded_at, mission_id);

create table app.badges (
  code         text     primary key check (code in ('bronze', 'silver', 'gold', 'diamond')),
  min_missions smallint not null unique check (min_missions > 0)
);

insert into app.badges (code, min_missions) values
  ('bronze', 5),
  ('silver', 10),
  ('gold', 25),
  ('diamond', 50);

create table app.member_badges (
  id         uuid        primary key,
  family_id  uuid        not null,
  member_id  uuid        not null,
  badge_code text        not null references app.badges (code) on delete restrict,
  awarded_at timestamptz not null,
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete restrict,
  unique (member_id, badge_code),
  unique (member_id, id)
);

create table app.badge_participations (
  member_badge_id uuid not null,
  mission_id      uuid not null,
  member_id       uuid not null,
  primary key (member_badge_id, mission_id),
  foreign key (member_id, member_badge_id)
    references app.member_badges (member_id, id) on delete cascade,
  foreign key (mission_id, member_id)
    references app.mission_participations (mission_id, member_id) on delete cascade
);
