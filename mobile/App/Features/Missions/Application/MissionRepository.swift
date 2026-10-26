import Foundation

nonisolated protocol MissionRepository: Sendable {
    func createMission(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission
    func mission(id: UUID, accessToken: String) async throws -> Mission
    /// Leitura mínima paginada (SPEC-014 §5.2) — todos os perfis, Kids em projeção simplificada.
    func missions(cursor: String?, accessToken: String) async throws -> MissionPage
    /// `taskIds` enviado substitui o conjunto inteiro; campos omitidos são preservados pelo servidor.
    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission
    /// MOD-007 — tarefas da família elegíveis para vínculo, qualquer status. Administrador apenas.
    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage
}
