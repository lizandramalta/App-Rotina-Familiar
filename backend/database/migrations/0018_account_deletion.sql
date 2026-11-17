-- 0018 — Exclusão de conta (SPEC-022) e guarda do token Apple (SPEC-001 Fase 4).
--
-- `members.deleted_at` marca a conta excluída de um perfil não-Criador: a linha
-- permanece como referência histórica anonimizada (sem nome, apelido ou foto) e
-- `removed_at` também é preenchido, de modo que todas as projeções que já
-- apresentam "Membro removido" tratam a conta excluída da mesma forma (RN69).
alter table app.members
  add column if not exists deleted_at timestamptz;

-- Refresh token Apple cifrado (AES-256-GCM, BA-40), substituído a cada login e
-- usado somente para revogação quando o Criador exclui a conta (RN44, RF73).
alter table app.creator_identities
  add column if not exists apple_refresh_token_encrypted text;

-- Fila pós-commit de revogação na Apple. Não referencia família nem identidade:
-- ambas já foram apagadas quando a intenção é processada (RN70, RNF28). O token
-- cifrado existe só até a revogação ou o esgotamento das tentativas.
create table if not exists app.apple_token_revocations (
  id               uuid        primary key,
  token_encrypted  text        not null,
  token_type_hint  text        not null check (token_type_hint in ('refresh_token', 'access_token')),
  attempts         integer     not null default 0,
  next_attempt_at  timestamptz not null default now(),
  claim_id         uuid,
  claimed_until    timestamptz,
  last_error       text,
  created_at       timestamptz not null default now()
);

create index if not exists apple_token_revocations_due_idx
  on app.apple_token_revocations (next_attempt_at);

-- Fila pós-commit de apagamento de objetos no R2. Recebe as chaves das mídias de
-- um perfil excluído ou de uma família excluída; nenhuma chamada ao R2 ocorre
-- dentro da transação da exclusão (BA-40).
create table if not exists app.media_object_deletions (
  id               uuid        primary key,
  object_key       text        not null unique,
  attempts         integer     not null default 0,
  next_attempt_at  timestamptz not null default now(),
  claim_id         uuid,
  claimed_until    timestamptz,
  last_error       text,
  created_at       timestamptz not null default now()
);

create index if not exists media_object_deletions_due_idx
  on app.media_object_deletions (next_attempt_at);

revoke all on app.apple_token_revocations from anon, authenticated;
revoke all on app.media_object_deletions from anon, authenticated;
