import Foundation

nonisolated protocol MissionRepository: Sendable {
    func createMission(_ command: CreateMissionCommand, accessToken: String) async throws -> Mission
    /// Projeção canônica do detalhe (SPEC-016 §5.1) — Kids sem participações nem situação de resgate.
    func mission(id: UUID, accessToken: String) async throws -> MissionDetail
    /// Coleções `inProgress`/`completed` com progresso canônico (SPEC-016 §5.1) — todos os perfis.
    func missions(accessToken: String) async throws -> MissionCollections
    /// `taskIds` enviado substitui o conjunto inteiro; campos omitidos são preservados pelo servidor.
    func updateMission(_ command: UpdateMissionCommand, accessToken: String) async throws -> Mission
    /// MOD-007 — tarefas da família elegíveis para vínculo, qualquer status. Administrador apenas.
    func taskOptions(query: String?, cursor: String?, accessToken: String) async throws -> MissionTaskOptionPage
    /// `POST /v1/missions/{missionId}/reward-acceptance` (SPEC-017 §5.1). Administrador only; returns
    /// the accepted snapshot. Throws `RewardAcceptanceError` — never retried automatically (§5.2).
    func acceptReward(missionID: UUID, rewardItemID: UUID, accessToken: String) async throws -> AcceptedMissionReward
}
