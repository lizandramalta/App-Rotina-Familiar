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
    func listFamilyApplause(range: FamilyDateRange, accessToken: String) async throws -> [FamilyApplauseSummary]
    func sendFamilyApplause(memberID: UUID, range: FamilyDateRange, accessToken: String) async throws
    func listReceivedFamilyApplause(accessToken: String) async throws -> [ReceivedFamilyApplause]
    func dismissFamilyApplause(id: UUID, accessToken: String) async throws
    func registerPushDevice(token: String, environment: String, accessToken: String) async throws
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

// Test doubles predating SPEC-009 CA-13–15 can opt in only when those flows are exercised.
extension FamilyRepository {
    func listFamilyApplause(range: FamilyDateRange, accessToken: String) async throws -> [FamilyApplauseSummary] { [] }
    func sendFamilyApplause(memberID: UUID, range: FamilyDateRange, accessToken: String) async throws { throw FamilyError.unavailable }
    func listReceivedFamilyApplause(accessToken: String) async throws -> [ReceivedFamilyApplause] { [] }
    func dismissFamilyApplause(id: UUID, accessToken: String) async throws { throw FamilyError.unavailable }
    func registerPushDevice(token: String, environment: String, accessToken: String) async throws { throw FamilyError.unavailable }
}

nonisolated protocol ProfilePhotoNormalizing: Sendable {
    /// Returns JPEG data with the longest side capped at 1600 px, at most 5 MB, without metadata.
    func normalize(_ data: Data) async throws -> Data
}
