import Foundation

/// Typed destinations pushed onto the Missions tab's `NavigationStack` (UX-014 §4). Shared by the
/// adult and Kids tab hosts — Kids never pushes `.create`/`.edit`, so no separate route type exists.
nonisolated enum MissionRoute: Hashable {
    case detail(UUID)
    case create
    case edit(UUID)
    /// A linked task tapped from TEL-021, reusing `TaskDetailView` (TEL-012/TEL-041 are one view).
    case taskDetail(UUID)
    /// `TaskDetailView`'s own "Editar" button, reached from `.taskDetail` — reused as-is rather
    /// than wired as a dead end, since `canManageTask` only depends on `role`, not on how the
    /// screen was reached.
    case taskEdit(UUID)
}
