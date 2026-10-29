-- SCRUM-106 / SPEC-002 CA-01, CA-10: foto privada antes da família.
-- A tabela de mídia de membros conserva suas FKs e colunas obrigatórias.
create table if not exists app.onboarding_media (
  id uuid primary key,
  grant_id uuid not null references app.family_creation_grants (id) on delete restrict,
  object_key text not null unique,
  purpose text not null check (purpose = 'PROFILE_PHOTO'),
  state text not null check (state in ('UPLOADING', 'READY', 'DELETING', 'FAILED')),
  size_bytes bigint,
  content_type text,
  created_at timestamptz not null default now(),
  check (state <> 'READY' or (size_bytes is not null and content_type = 'image/jpeg'))
);

create index if not exists onboarding_media_grant_idx on app.onboarding_media (grant_id);
create index if not exists onboarding_media_cleanup_idx
  on app.onboarding_media (created_at, id)
  where state in ('UPLOADING', 'READY', 'DELETING', 'FAILED');

revoke all on app.onboarding_media from anon, authenticated;
