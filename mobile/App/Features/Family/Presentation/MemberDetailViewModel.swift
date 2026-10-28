import Foundation
import Observation
import SwiftUI

/// TEL-032 — current day or Sunday–Saturday member tasks, with permitted administrative actions.
@MainActor
@Observable
final class MemberDetailViewModel {
    enum Period: String, CaseIterable { case day, week }
    enum KidsNameUpdateResult { case saved, failed, reconciliationRequired, noLongerEligible }
    enum Failure: Equatable {
        case notAllowed
        case notFound
        case network
    }

    private(set) var detail: FamilyMemberDetail?
    private(set) var isLoading = false
    private(set) var failure: Failure?
    private(set) var isSaving = false
    private(set) var managementFailed = false
    private(set) var isRemoved = false
    private(set) var period: Period = .day

    enum InviteFailure: Equatable {
        case rateLimited
        /// The outcome is unknown: no credentials are shown and the next attempt is a reissue (SPEC-004 CA-07).
        case uncertain
        case unavailable
        case notAllowed
    }

    /// `true` once an issuance was attempted or may have happened; the next one is then a reissue (CA-02, CA-07).
    private(set) var hasPreviousInvite: Bool
    private(set) var isIssuingInvite = false
    /// Credentials live only here, until the native share sheet is dismissed (CA-08).
    private(set) var transientInvite: MemberInvite?
    private(set) var inviteFailure: InviteFailure?
    private(set) var wasShareCancelled = false
    let taskViewModel: FamilyTasksViewModel
    private let todayRange: FamilyDateRange
    private let weekRange: FamilyDateRange

    private let memberID: UUID
    private let session: ActiveFamilySession
    private let familyRepository: any FamilyRepository
    private let accessTokenProvider: @MainActor () -> String?

    init(
        memberID: UUID,
        session: ActiveFamilySession,
        familyRepository: any FamilyRepository,
        accessTokenProvider: @escaping @MainActor () -> String?,
        hasPreviousInvite: Bool = false,
        familyCreatedAt: String? = nil,
        timeZoneID: String = FamilyCreationValidation.defaultTimeZoneID,
        now: Date = .now
    ) {
        self.hasPreviousInvite = hasPreviousInvite
        self.memberID = memberID
        self.session = session
        self.familyRepository = familyRepository
        self.accessTokenProvider = accessTokenProvider
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)
        let todayDate = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: todayDate)
        let sunday = calendar.date(byAdding: .day, value: -(weekday - 1), to: todayDate) ?? todayDate
        let saturday = calendar.date(byAdding: .day, value: 6, to: sunday) ?? todayDate
        let lastDay = calendar.dateInterval(of: .month, for: todayDate)?.end.addingTimeInterval(-1) ?? todayDate
        todayRange = FamilyDateRange(startDate: today, endDate: today)
        weekRange = FamilyDateRange(
            startDate: max(formatter.string(from: sunday), familyCreatedAt ?? formatter.string(from: sunday)),
            endDate: formatter.string(from: min(saturday, lastDay))
        )
        self.taskViewModel = FamilyTasksViewModel(
            range: todayRange,
            memberID: memberID,
            role: session.role,
            familyCreatedAt: familyCreatedAt,
            timeZoneID: timeZoneID,
            familyRepository: familyRepository,
            accessTokenProvider: accessTokenProvider
        )
    }

    var isCreator: Bool { detail?.isFamilyCreator ?? false }

    var canManage: Bool {
        session.role == .administrator && (detail?.capabilities.manageMembers ?? false)
    }

    /// Hidden for non-managers and for the Creator, who never receives an invite (SPEC-004 CA-03, CA-04).
    var canIssueInvite: Bool { canManage && !isCreator && detail?.id != session.memberID }
    var canManageTarget: Bool { canManage && !isCreator && detail?.id != session.memberID }
    var canEditKidsName: Bool { canManageTarget && detail?.role == .kid }

    func selectPeriod(_ selected: Period) async {
        guard selected != period else { return }
        await taskViewModel.applyRange(selected == .day ? todayRange : weekRange)
        if !taskViewModel.failed { period = selected }
    }

    func updateKidsName(_ name: String) async -> KidsNameUpdateResult {
        guard canEditKidsName, let token = accessTokenProvider() else { return .noLongerEligible }
        do {
            let updated = try await familyRepository.updateMemberName(
                memberID: memberID, name: name, accessToken: token
            )
            apply(updated)
            return .saved
        } catch {
            guard let current = await reconcileMember() else { return .reconciliationRequired }
            guard current.role == .kid else { return .noLongerEligible }
            return current.name == name ? .saved : .failed
        }
    }

    func reconcileKidsName() async -> FamilyMemberDetail? {
        await reconcileMember()
    }

    private func reconcileMember() async -> FamilyMemberDetail? {
        guard let token = accessTokenProvider() else { return nil }
        do {
            let current = try await familyRepository.getMemberDetail(memberID: memberID, accessToken: token)
            detail = current
            return current
        } catch { return nil }
    }
    var allowedRoles: [MemberRole] {
        guard let detail else { return [] }
        let candidates: [MemberRole] = detail.role == .kid
            ? [.member]
            : [.administrator, .member]
        return candidates.filter { $0 != detail.role }
    }

    func changeRole(_ role: MemberRole) async {
        guard canManageTarget, allowedRoles.contains(role), !isSaving, let token = accessTokenProvider() else { return }
        isSaving = true
        managementFailed = false
        defer { isSaving = false }
        do {
            let member = try await familyRepository.changeMemberRole(memberID: memberID, role: role, accessToken: token)
            apply(member)
        } catch {
            managementFailed = true
            await load()
        }
    }

    func remove() async {
        guard canManageTarget, !isSaving, let token = accessTokenProvider() else { return }
        isSaving = true
        managementFailed = false
        defer { isSaving = false }
        do {
            try await familyRepository.removeMember(memberID: memberID, accessToken: token)
            detail = nil
            isRemoved = true
        } catch {
            managementFailed = true
            await load()
        }
    }

    private func apply(_ member: FamilyMember) {
        guard let old = detail else { return }
        detail = FamilyMemberDetail(
            id: member.id, name: member.name, role: member.role,
            isFamilyCreator: member.isFamilyCreator, createdAt: old.createdAt,
            capabilities: old.capabilities
        )
    }

    /// Single message handed to the native share sheet (SPEC-004 E-01).
    var shareMessage: String? {
        transientInvite.map {
            String(format: String(localized: "memberInvite.share.message"), $0.link, $0.password)
        }
    }

    var inviteErrorMessage: LocalizedStringKey? {
        switch inviteFailure {
        case .rateLimited: "memberInvite.error.rateLimited"
        case .uncertain: "memberInvite.error.uncertain"
        case .unavailable: "memberInvite.error.unavailable"
        case .notAllowed: "memberInvite.error.notAllowed"
        case nil: nil
        }
    }

    var errorMessage: LocalizedStringKey? {
        switch failure {
        case .notAllowed: "family.member.detail.error_not_allowed"
        case .notFound: "family.member.detail.error_not_found"
        case .network: "family.members.error_network"
        case nil: nil
        }
    }

    /// Only a transient failure (network) keeps the last confirmed detail (UX-003 §6); 403 and 404 clear it.
    func load() async {
        guard !isLoading else { return }
        failure = nil
        guard let token = accessTokenProvider() else {
            failure = .network
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await familyRepository.getMemberDetail(memberID: memberID, accessToken: token)
            await taskViewModel.load()
        } catch FamilyError.actionNotAllowed {
            // Access was refused: stale content of a member the viewer may no longer see must not stay on screen.
            detail = nil
            failure = .notAllowed
        } catch FamilyError.rejected {
            // 404: the member no longer exists, so stale data must not stay on screen.
            detail = nil
            failure = .notFound
        } catch {
            failure = .network
        }
    }

    /// First issuance: a direct tap, with no confirmation step (CA-01).
    func issueFirstInvite() async {
        await issueInvite()
    }

    /// Reissue after the conscious confirmation of TEL-034 (CA-02).
    func confirmReissue() async {
        await issueInvite()
    }

    /// Called when the native share sheet closes. The credentials are discarded either way and cannot be shared
    /// again without a reissue (CA-08).
    func onShareDismissed(completed: Bool) {
        guard transientInvite != nil else { return }
        transientInvite = nil
        hasPreviousInvite = true
        wasShareCancelled = !completed
    }

    func clearInviteFailure() {
        inviteFailure = nil
    }

    private func issueInvite() async {
        guard canIssueInvite, !isIssuingInvite else { return }
        inviteFailure = nil
        wasShareCancelled = false
        guard let token = accessTokenProvider() else {
            inviteFailure = .notAllowed
            return
        }

        isIssuingInvite = true
        defer { isIssuingInvite = false }
        do {
            transientInvite = try await familyRepository.issueInvite(memberID: memberID, accessToken: token)
            hasPreviousInvite = true
        } catch FamilyError.rateLimited {
            inviteFailure = .rateLimited
        } catch FamilyError.actionNotAllowed {
            inviteFailure = .notAllowed
        } catch FamilyError.rejected {
            inviteFailure = .unavailable
        } catch {
            // 503, timeout, lost connection or unreadable body: the invite may exist, so the next try is a reissue.
            hasPreviousInvite = true
            inviteFailure = .uncertain
        }
    }
}
