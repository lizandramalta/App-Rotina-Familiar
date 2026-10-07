-- 0001 — Base do schema privado do produto.
--
-- BA-19: o Supabase é usado estritamente como PostgreSQL gerenciado. As tabelas
-- do produto ficam no schema `app`, que nunca é exposto pela Data API (PostREST).
-- Os papéis públicos `anon` e `authenticated` não têm nenhum privilégio aqui: a
-- autorização é feita pela aplicação, conforme backend-architecture.md §6.
--
-- As tabelas de produto (families, members, task_templates, ...) entram nas
-- migrations das SPECs que as introduzem, não nesta.

create schema if not exists app;

revoke all on schema app from anon, authenticated;
revoke all on all tables in schema app from anon, authenticated;
revoke all on all routines in schema app from anon, authenticated;

-- Objetos criados depois desta migration também nascem sem acesso público.
alter default privileges in schema app revoke all on tables from anon, authenticated;
alter default privileges in schema app revoke all on routines from anon, authenticated;
