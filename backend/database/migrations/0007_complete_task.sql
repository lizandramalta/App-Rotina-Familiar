-- 0007 — Conclusão transacional de tarefa (SPEC-010 Fase 1 / SCRUM-40).
--
-- A auditoria existente já preserva mudanças da ocorrência. Esta migration só
-- amplia o vocabulário imutável do evento para registrar a conclusão distinta
-- de uma edição, sem alterar registros históricos.

alter table app.task_events
  drop constraint if exists task_events_event_type_check;

alter table app.task_events
  add constraint task_events_event_type_check
  check (event_type in ('created', 'edited', 'deleted', 'completed'));
