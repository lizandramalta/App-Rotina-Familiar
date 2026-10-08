-- 0002 — Tabelas do módulo Access (SPEC-001, Fase 1).
--
-- Cobre a identidade Apple do Criador, o grant restrito de criação de família
-- (BA-21) e a sessão própria com tokens opacos (BA-10). Nenhum token bruto é
-- persistido: as colunas `*_hash` guardam SHA-256 do token opaco, e o `sub` da
-- Apple é guardado cifrado (AES-256-GCM) ao lado do seu hash de unicidade.
--
-- BA-19: tudo no schema privado `app`, sem privilégio para `anon`/`authenticated`.

-- Família. Esta spec não cria famílias (isso é SPEC-002); a tabela existe aqui
-- porque a sessão do Criador referencia uma família já vinculada à identidade.
create table if not exists app.families (
  id         uuid        primary key,
  name       text        not null,
  timezone   text        not null default 'America/Sao_Paulo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Identidade Apple do Criador. `apple_subject_hash` dá unicidade sem permitir
-- busca pelo `sub` em claro; `apple_subject_encrypted` permite reler o valor
-- quando necessário, sem deixá-lo legível no banco.
create table if not exists app.creator_identities (
  id                       uuid        primary key,
  apple_subject_hash       text        not null unique,
  apple_subject_encrypted  text        not null,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- Membro de uma família. `creator_identity_id` só é preenchido para o Criador.
create table if not exists app.members (
  id                  uuid        primary key,
  family_id           uuid        not null references app.families (id) on delete cascade,
  creator_identity_id uuid        references app.creator_identities (id) on delete restrict,
  role                text        not null check (role in ('administrator', 'member', 'kids')),
  is_family_creator   boolean     not null default false,
  display_name        text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  -- Alvo das FKs compostas das demais tabelas: toda referência a um membro
  -- carrega a família, de forma que o banco recusa cruzar famílias.
  unique (family_id, id)
);

-- Um Criador por família (invariante "Um Criador protegido").
create unique index if not exists members_one_creator_per_family_idx
  on app.members (family_id)
  where is_family_creator;

-- Uma identidade Apple vincula-se a no máximo um membro Criador.
create unique index if not exists members_creator_identity_idx
  on app.members (creator_identity_id)
  where creator_identity_id is not null;

-- Grant restrito de criação de família, emitido quando a identidade validada
-- ainda não tem família. Expira em 10 minutos (BA-21) e é de consumo único.
create table if not exists app.family_creation_grants (
  id                       uuid        primary key,
  creator_identity_id      uuid        not null references app.creator_identities (id) on delete cascade,
  grant_token_hash         text        not null unique,
  installation_proof_hash  text        not null,
  expires_at               timestamptz not null,
  consumed_at              timestamptz,
  revoked_at               timestamptz,
  created_at               timestamptz not null default now()
);

create index if not exists family_creation_grants_identity_idx
  on app.family_creation_grants (creator_identity_id)
  where consumed_at is null and revoked_at is null;

-- Sessão própria do membro. O refresh token é estável e sem prazo (BA-10); a
-- revogação é explícita, via `revoked_at`.
create table if not exists app.sessions (
  id                       uuid        primary key,
  family_id                uuid        not null,
  member_id                uuid        not null,
  refresh_token_hash       text        not null unique,
  installation_proof_hash  text        not null,
  revoked_at               timestamptz,
  revoked_reason           text,
  created_at               timestamptz not null default now(),
  last_seen_at             timestamptz not null default now(),
  foreign key (family_id, member_id)
    references app.members (family_id, id) on delete cascade
);

-- Invariante "Uma sessão ativa por perfil" (RN44, BA-10): o banco recusa uma
-- segunda sessão ativa, de modo que CA-05 não depende só do caso de uso.
create unique index if not exists sessions_one_active_per_member_idx
  on app.sessions (member_id)
  where revoked_at is null;

create index if not exists sessions_family_idx on app.sessions (family_id);

-- Access tokens de 15 minutos (BA-10). Vários podem coexistir na mesma sessão:
-- um refresh não invalida os anteriores ainda dentro da janela.
create table if not exists app.session_access_tokens (
  id         uuid        primary key,
  session_id uuid        not null references app.sessions (id) on delete cascade,
  token_hash text        not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists session_access_tokens_session_idx
  on app.session_access_tokens (session_id)
  where revoked_at is null;

-- Os objetos criados acima nascem sem acesso público; revogar de novo cobre
-- bancos onde privilégios foram concedidos fora destas migrations.
revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
