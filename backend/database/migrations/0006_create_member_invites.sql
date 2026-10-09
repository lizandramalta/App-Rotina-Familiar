-- 0006 — Convites de membro (SPEC-004, Fase 1 / SCRUM-30).
--
-- Cada emissão cria uma linha nova; reemitir invalida a anterior em vez de
-- sobrescrevê-la, preservando a trilha de quem emitiu e quando. Nenhum segredo
-- legível é persistido (BA-09): `token_hash` é SHA-256 do token opaco, de alta
-- entropia, e `password_verifier` é um verificador scrypt com sal próprio — a
-- senha é curta (6 caracteres), então um hash rápido não bastaria.
--
-- A tabela também serve ao ingresso (SPEC-005): `status` e `consumed_at` já
-- comportam o consumo único, sem exigir nova migration.
--
-- BA-19: tudo no schema privado `app`, sem privilégio para `anon`/`authenticated`.

create table if not exists app.member_invites (
  id                  uuid        primary key,
  family_id           uuid        not null,
  member_id           uuid        not null,
  issued_by_member_id uuid        not null,
  token_hash          text        not null unique,
  password_verifier   text        not null,
  status              text        not null default 'available'
                      check (status in ('available', 'invalidated', 'consumed')),
  created_at          timestamptz not null,
  invalidated_at      timestamptz,
  consumed_at         timestamptz,
  -- Toda referência a membro carrega a família: o banco recusa cruzar famílias.
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete cascade,
  foreign key (family_id, issued_by_member_id)
    references app.members (family_id, id) on delete cascade,
  -- O estado e seu carimbo de tempo andam juntos.
  check ((status = 'invalidated') = (invalidated_at is not null)),
  check ((status = 'consumed') = (consumed_at is not null))
);

-- Invariante "no máximo um convite utilizável por perfil" (RN46, CA-06): o banco
-- recusa um segundo `available`, de modo que a garantia não depende só do lock.
create unique index if not exists member_invites_one_available_per_member_idx
  on app.member_invites (member_id)
  where status = 'available';

create index if not exists member_invites_family_member_idx
  on app.member_invites (family_id, member_id);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
