import Foundation

/// Typed destinations pushed onto the "Minhas tarefas" adult tab's `NavigationStack` (UF-05).
/// Carries only an id, never a full entity (MA-09/mobile-architecture.md §8).
nonisolated enum FamilyTaskRoute: Hashable {
    case create
    case detail(UUID)
    case edit(UUID)
}
