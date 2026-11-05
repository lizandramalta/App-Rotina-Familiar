-- SPEC-017 Fase 1 / SCRUM-88: aceite único de recompensa por missão concluída.
-- Snapshot sem FK viva para reward_items: retrato histórico do item no momento
-- do aceite, estável mesmo se o item de catálogo for removido depois (BA-15/RN53).
alter table app.missions
  add column accepted_reward_item_id uuid,
  add column accepted_reward_title text,
  add column accepted_reward_details text,
  add column accepted_reward_source text check (accepted_reward_source in ('predefined', 'custom')),
  add column accepted_reward_accepted_at timestamptz;

-- Todas nulas (sem aceite) ou todas preenchidas (details pode ser nulo: o item
-- pode não ter descrição).
alter table app.missions
  add constraint missions_accepted_reward_shape_check check (
    (accepted_reward_item_id is null and accepted_reward_title is null
      and accepted_reward_source is null and accepted_reward_accepted_at is null)
    or
    (accepted_reward_item_id is not null and accepted_reward_title is not null
      and accepted_reward_source is not null and accepted_reward_accepted_at is not null)
  );
