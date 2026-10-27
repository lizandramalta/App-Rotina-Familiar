import Foundation

/// Typed destinations pushed onto the "Minhas tarefas" adult tab's `NavigationStack` (UF-05).
/// Carries only an id, never a full entity (MA-09/mobile-architecture.md §8).
nonisolated enum FamilyTaskRoute: Hashable {
    case create
    case detail(UUID)
    /// `scope` comes from MOD-003 when the task is a routine occurrence (UX-008 §4).
    case edit(UUID, scope: RoutineScope?)
}
