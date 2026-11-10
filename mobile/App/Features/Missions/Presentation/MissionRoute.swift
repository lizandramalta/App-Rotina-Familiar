import Foundation

/// Typed destinations pushed onto the Missions tab's `NavigationStack` (UX-014 §4). Shared by the
/// adult and Kids tab hosts — Kids never pushes `.create`/`.edit`, so no separate route type exists.
nonisolated enum MissionRoute: Hashable {
    case detail(UUID)
    case create
    case edit(UUID)
    /// TEL-023 (SPEC-015 Fase 1) — catálogo de recompensas, visível apenas a Administrador.
    case rewardItems
    /// A linked task tapped from TEL-021, reusing `TaskDetailView` (TEL-012/TEL-041 are one view).
    case taskDetail(UUID)
    /// `TaskDetailView`'s own "Editar" button, reached from `.taskDetail` — reused as-is rather
    /// than wired as a dead end, since `canManageTask` only depends on `role`, not on how the
    /// screen was reached.
    case taskEdit(UUID, scope: RoutineScope?)
    /// TEL-024 (SPEC-017 Fase 2) — Administrador only, from a redeemable TEL-021. The title is
    /// display context for the wheel header; every decision is revalidated by the server.
    case rewardWheel(UUID, missionTitle: String)
    /// TEL-023 opened from TEL-024 in consult mode: no add action (UX-017 §5.2, decisão R-4).
    case rewardItemsConsult
}
