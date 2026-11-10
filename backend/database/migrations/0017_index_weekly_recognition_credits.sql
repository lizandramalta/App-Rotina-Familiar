-- SPEC-020 CA-01 / RNF10: localizar créditos válidos pelo intervalo absoluto do ciclo.
-- A PK de completion_credits já cobre o join por completion_id.
create index completions_family_completed_at_active_idx
  on app.completions (family_id, completed_at, id) where undone_at is null;
