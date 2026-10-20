-- SPEC-015 Fase 1 / SCRUM-80: catálogo coletivo e itens da família.
-- IDs fixos mantêm os seis itens predefinidos estáveis entre ambientes.

create table app.reward_items (
  id               uuid        primary key,
  family_id        uuid        references app.families (id) on delete cascade,
  created_by_id    uuid,
  title            text        not null,
  normalized_title text,
  details          text,
  source           text        not null check (source in ('predefined', 'custom')),
  sort_order       smallint,
  created_at       timestamptz not null,
  foreign key (family_id, created_by_id)
    references app.members (family_id, id) on delete restrict,
  constraint reward_items_source_shape_check check (
    (source = 'predefined' and family_id is null and created_by_id is null
      and normalized_title is null and sort_order between 1 and 6)
    or
    (source = 'custom' and family_id is not null and created_by_id is not null
      and normalized_title is not null and sort_order is null)
  ),
  constraint reward_items_details_length_check check (
    details is null or char_length(details) <= 255
  )
);

create unique index reward_items_custom_title_unique_idx
  on app.reward_items (family_id, normalized_title)
  where source = 'custom';

create unique index reward_items_predefined_order_unique_idx
  on app.reward_items (sort_order)
  where source = 'predefined';

create index reward_items_custom_family_created_idx
  on app.reward_items (family_id, created_at, id)
  where source = 'custom';

insert into app.reward_items (id, title, source, sort_order, created_at) values
  ('b2811e28-9ad3-4000-8000-000000000001', 'Escolher o filme da noite', 'predefined', 1, '2026-10-10T00:00:00Z'),
  ('b2811e28-9ad3-4000-8000-000000000002', 'Escolher o jantar em família', 'predefined', 2, '2026-10-10T00:00:00Z'),
  ('b2811e28-9ad3-4000-8000-000000000003', 'Noite de jogos em família', 'predefined', 3, '2026-10-10T00:00:00Z'),
  ('b2811e28-9ad3-4000-8000-000000000004', 'Sobremesa especial', 'predefined', 4, '2026-10-10T00:00:00Z'),
  ('b2811e28-9ad3-4000-8000-000000000005', 'Piquenique ou passeio no parque', 'predefined', 5, '2026-10-10T00:00:00Z'),
  ('b2811e28-9ad3-4000-8000-000000000006', 'Escolher uma atividade em família', 'predefined', 6, '2026-10-10T00:00:00Z');

revoke all on app.reward_items from anon, authenticated;
