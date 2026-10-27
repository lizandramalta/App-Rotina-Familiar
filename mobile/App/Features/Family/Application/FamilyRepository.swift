import Foundation

nonisolated protocol FamilyRepository: Sendable {
    func createFamily(_ command: CreateFamilyCommand, installationProof: String) async throws -> CreatedFamily
    func uploadProfilePhoto(_ jpeg: Data, accessToken: String) async throws -> String
    func setProfilePhoto(mediaID: String, accessToken: String) async throws
    func createMember(name: String, role: MemberRole, accessToken: String) async throws -> CreatedMember
    func issueInvite(memberID: UUID, accessToken: String) async throws -> MemberInvite
    /// Consumed by Tasks' assignee picker (MOD-001); not paginated further there — families are small.
    func listMembers(accessToken: String, cursor: String?) async throws -> FamilyMemberPage
    func getMemberDetail(memberID: UUID, accessToken: String) async throws -> FamilyMemberDetail
    func updateMemberName(memberID: UUID, name: String, accessToken: String) async throws -> FamilyMember
    func changeMemberRole(memberID: UUID, role: MemberRole, accessToken: String) async throws -> FamilyMember
    func removeMember(memberID: UUID, accessToken: String) async throws
    func leaveAdministration(accessToken: String) async throws -> FamilyMember
    func getFamilyOverview(range: FamilyDateRange?, accessToken: String) async throws -> FamilyOverview
    func listFamilyTasks(
        range: FamilyDateRange,
        memberID: UUID?,
        status: FamilyTaskStatusFilter,
        cursor: String?,
        accessToken: String
    ) async throws -> FamilyTaskPage
    func getWeeklyReport(referenceDate: String, accessToken: String) async throws -> WeeklyReportSnapshot

    func getFamily(accessToken: String) async throws -> FamilyProfile
    func updateFamilyName(_ name: String, accessToken: String) async throws -> FamilyProfile

    // MARK: - Settings and Time Zone (SPEC-002 Phase 3)
    func getFamilySettings(accessToken: String) async throws -> FamilySettings
    func previewFamilyTimeZoneChange(timeZoneID: String, application: TimeZoneApplication, accessToken: String) async throws -> TimeZoneChangePreview
    func changeFamilyTimeZone(timeZoneID: String, application: TimeZoneApplication, accessToken: String) async throws -> FamilySettings
}

nonisolated protocol ProfilePhotoNormalizing: Sendable {
    /// Returns JPEG data with the longest side capped at 1600 px, at most 5 MB, without metadata.
    func normalize(_ data: Data) async throws -> Data
}
