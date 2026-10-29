-- 0007 — Ingresso por convite (SPEC-005, Fase 1 / SCRUM-32).
--
-- `invite_join_recoveries` guarda, por dez minutos desde o commit do ingresso, o
-- envelope criptografado (AES-256-GCM, chave fora do banco) com as credenciais
-- da sessão recém-aberta, para recuperar uma resposta perdida sem consumir o
-- convite outra vez (BA-11). O segredo da tentativa e a prova da instalação
-- aparecem apenas como hash; a senha do convite nunca entra aqui.
--
-- `invite_attempt_log` sustenta o limite de tentativas (RN46, RNF21, BA-23): a
-- senha tem 30 bits de entropia, então a proteção vem do verificador lento e
-- deste limite. Guarda somente o hash do identificador limitado, nunca o token
-- ou o endereço de origem em claro.
--
-- BA-19: tudo no schema privado `app`, sem privilégio para `anon`/`authenticated`.

create table if not exists app.invite_join_recoveries (
  attempt_id              uuid        primary key,
  invite_id               uuid        not null references app.member_invites (id) on delete cascade,
  session_id              uuid        not null references app.sessions (id) on delete cascade,
  attempt_secret_hash     text        not null,
  installation_proof_hash text        not null,
  envelope                text        not null,
  created_at              timestamptz not null,
  expires_at              timestamptz not null
);

create index if not exists invite_join_recoveries_session_idx
  on app.invite_join_recoveries (session_id);

create index if not exists invite_join_recoveries_expires_idx
  on app.invite_join_recoveries (expires_at);

create table if not exists app.invite_attempt_log (
  id           bigint      generated always as identity primary key,
  scope        text        not null check (scope in ('invite', 'origin')),
  subject_hash text        not null,
  attempted_at timestamptz not null
);

create index if not exists invite_attempt_log_lookup_idx
  on app.invite_attempt_log (scope, subject_hash, attempted_at);

revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
