import Foundation

/// Typed destinations pushed onto the "Minhas tarefas" adult tab's `NavigationStack` (UF-05).
/// Carries only an id, never a full entity (MA-09/mobile-architecture.md §8).
nonisolated enum FamilyTaskRoute: Hashable {
    case create
    case detail(UUID)
    /// `scope` comes from MOD-003 when the task is a routine occurrence (UX-008 §4).
    case edit(UUID, scope: RoutineScope?)
}

/// Routes in the Family tab share one path so task details return to the member or list that opened them.
nonisolated enum FamilyNavigationRoute: Hashable {
    case member(UUID)
    case familyTasks
    case settingsHub
    case create
    case detail(UUID)
    case edit(UUID, scope: RoutineScope?)
}
