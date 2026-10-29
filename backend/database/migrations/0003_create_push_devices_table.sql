-- 0003 — Registro de push do dispositivo, vinculado à sessão (SPEC-001, Fase 2).
--
-- CA-09 exige que a revogação explícita da sessão encerre também o registro de
-- push associado: um token de dispositivo que sobrevivesse ao logout seguiria
-- recebendo notificação de uma família da qual a instalação já saiu.
--
-- O vínculo é com a sessão, não com o membro: o mesmo membro pode ter sessões
-- em instalações diferentes ao longo do tempo, e o registro acompanha a sessão
-- que o criou. `on delete cascade` segue o descarte da sessão.
--
-- BA-19: schema privado `app`, sem privilégio para `anon`/`authenticated`.
create table if not exists app.push_devices (
  id           uuid        primary key,
  session_id   uuid        not null references app.sessions (id) on delete cascade,
  device_token text        not null,
  environment  text        not null check (environment in ('development', 'production')),
  revoked_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Índice parcial: as consultas de envio e a revogação do logout só olham para os
-- registros ainda ativos da sessão.
create index if not exists push_devices_session_idx
  on app.push_devices (session_id)
  where revoked_at is null;

-- Os objetos criados acima nascem sem acesso público; revogar de novo cobre
-- bancos onde privilégios foram concedidos fora destas migrations.
revoke all on all tables in schema app from anon, authenticated;
revoke all on all sequences in schema app from anon, authenticated;
