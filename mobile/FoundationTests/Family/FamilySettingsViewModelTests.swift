import Foundation
@testable import FamilyRoutine
import Testing

@MainActor
struct FamilySettingsViewModelTests {
    private let adminSession = ActiveFamilySession(
        memberID: UUID(),
        familyID: UUID(),
        role: .administrator,
        isFamilyCreator: true
    )

    private let memberSession = ActiveFamilySession(
        memberID: UUID(),
        familyID: UUID(),
        role: .member,
        isFamilyCreator: false
    )

    private let kidSession = ActiveFamilySession(
        memberID: UUID(),
        familyID: UUID(),
        role: .kid,
        isFamilyCreator: false
    )

    private let sampleSettings = FamilySettings(
        timeZoneID: "America/Sao_Paulo",
        scheduledTimeZoneChange: nil,
        limits: CycleLimits(
            startsAt: "2026-10-19T03:00:00.000Z",
            endsAt: "2026-10-26T03:00:00.000Z",
            timeZoneID: "America/Sao_Paulo",
            isTransition: false
        )
    )

    private let settingsWithScheduledChange = FamilySettings(
        timeZoneID: "America/Sao_Paulo",
        scheduledTimeZoneChange: ScheduledTimeZoneChange(
            timeZoneID: "America/Manaus",
            effectiveAt: "2026-10-26T03:00:00.000Z"
        ),
        limits: CycleLimits(
            startsAt: "2026-10-19T03:00:00.000Z",
            endsAt: "2026-10-26T03:00:00.000Z",
            timeZoneID: "America/Sao_Paulo",
            isTransition: false
        )
    )

    @Test("SPEC-002 CA-05 non-admin member or kid is denied access immediately without calling repository")
    func nonAdminAccessDenied() async {
        let spy = FamilyRepositorySpy()
        let memberVM = FamilySettingsViewModel(
            repository: spy,
            session: memberSession,
            accessTokenProvider: { "token" }
        )
        await memberVM.loadSettings()
        #expect(memberVM.state == .accessDenied)
        let getCalls = await spy.getSettingsCalls
        #expect(getCalls == 0)

        let kidVM = FamilySettingsViewModel(
            repository: spy,
            session: kidSession,
            accessTokenProvider: { "token" }
        )
        await kidVM.loadSettings()
        #expect(kidVM.state == .accessDenied)
    }

    @Test("SPEC-002 CA-05 repository 403 maps to accessDenied state")
    func actionNotAllowedMapsToAccessDenied() async {
        let spy = FamilyRepositorySpy(settingsResult: .failure(FamilyError.actionNotAllowed))
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        #expect(vm.state == .accessDenied)
    }

    @Test("SPEC-002 CA-05 admin loads confirmed family settings successfully")
    func adminLoadsSettings() async {
        let spy = FamilyRepositorySpy(settingsResult: .success(sampleSettings))
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        #expect(vm.state == .loaded(sampleSettings))
        #expect(vm.currentSettings == sampleSettings)
        #expect(vm.isTimeZoneCurrent("America/Sao_Paulo") == true)
        #expect(vm.isTimeZoneCurrent("America/Manaus") == false)
    }

    @Test("SPEC-002 CA-05 cannot select current time zone or scheduled time zone")
    func cannotSelectCurrentOrScheduledTimeZone() async {
        let spy = FamilyRepositorySpy(settingsResult: .success(settingsWithScheduledChange))
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()

        #expect(vm.isTimeZoneDisabled("America/Sao_Paulo") == true)
        #expect(vm.isTimeZoneDisabled("America/Manaus") == true)
        #expect(vm.isTimeZoneDisabled("America/Rio_Branco") == false)

        vm.selectTimeZone("America/Sao_Paulo")
        #expect(vm.selectedTimeZoneID == nil)
        #expect(vm.canRequestPreview == false)

        vm.selectTimeZone("America/Manaus")
        #expect(vm.selectedTimeZoneID == nil)
        #expect(vm.canRequestPreview == false)

        vm.selectTimeZone("America/Rio_Branco")
        #expect(vm.selectedTimeZoneID == "America/Rio_Branco")
        #expect(vm.canRequestPreview == true)
    }

    @Test("SPEC-002 CA-06/CA-07 requesting preview opens confirmation sheet with preview data")
    func requestPreviewSuccess() async {
        let spy = FamilyRepositorySpy(settingsResult: .success(sampleSettings))
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        vm.selectTimeZone("America/Manaus")
        #expect(vm.isConfirmationPresented == false)

        await vm.requestPreview()

        #expect(vm.isConfirmationPresented == true)
        #expect(vm.preview?.proposedTimeZoneID == "America/Manaus")
        #expect(vm.preview?.application == .immediate)
        let previewCalls = await spy.previewCalls
        #expect(previewCalls == 1)
        let lastTarget = await spy.lastPreviewTimeZoneID
        #expect(lastTarget == "America/Manaus")
    }

    @Test("SPEC-002 CA-06 confirming immediate application updates confirmed settings and clears selection")
    func confirmImmediateChange() async {
        let updatedSettings = FamilySettings(
            timeZoneID: "America/Manaus",
            scheduledTimeZoneChange: nil,
            limits: CycleLimits(
                startsAt: "2026-10-19T03:00:00.000Z",
                endsAt: "2026-10-26T04:00:00.000Z",
                timeZoneID: "America/Manaus",
                isTransition: true
            )
        )
        let spy = FamilyRepositorySpy(
            settingsResult: .success(sampleSettings),
            changeTimeZoneResults: [.success(updatedSettings)]
        )
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        vm.selectTimeZone("America/Manaus")
        await vm.requestPreview()

        await vm.confirmChange()

        #expect(vm.isConfirmationPresented == false)
        #expect(vm.selectedTimeZoneID == nil)
        #expect(vm.currentSettings?.timeZoneID == "America/Manaus")
        #expect(vm.currentSettings?.limits.isTransition == true)
        let changeCalls = await spy.changeTimeZoneCalls
        #expect(changeCalls == 1)
        let lastApp = await spy.lastChangeApplication
        #expect(lastApp == .immediate)
    }

    @Test("SPEC-002 CA-07 confirming nextCycle application updates scheduled change and keeps current fuso")
    func confirmNextCycleChange() async {
        let scheduledSettings = FamilySettings(
            timeZoneID: "America/Sao_Paulo",
            scheduledTimeZoneChange: ScheduledTimeZoneChange(
                timeZoneID: "America/Manaus",
                effectiveAt: "2026-10-26T03:00:00.000Z"
            ),
            limits: CycleLimits(
                startsAt: "2026-10-19T03:00:00.000Z",
                endsAt: "2026-10-26T03:00:00.000Z",
                timeZoneID: "America/Sao_Paulo",
                isTransition: false
            )
        )
        let spy = FamilyRepositorySpy(
            settingsResult: .success(sampleSettings),
            changeTimeZoneResults: [.success(scheduledSettings)]
        )
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        vm.selectTimeZone("America/Manaus")
        await vm.requestPreview()
        await vm.updateApplicationMode(.nextCycle)

        await vm.confirmChange()

        #expect(vm.isConfirmationPresented == false)
        #expect(vm.selectedTimeZoneID == nil)
        #expect(vm.currentSettings?.timeZoneID == "America/Sao_Paulo")
        #expect(vm.currentSettings?.scheduledTimeZoneChange?.timeZoneID == "America/Manaus")
        let lastApp = await spy.lastChangeApplication
        #expect(lastApp == .nextCycle)
    }

    @Test("SPEC-002 CA-09 cancelling confirmation dismisses modal and preserves selection in form")
    func cancelPreservesSelection() async {
        let spy = FamilyRepositorySpy(settingsResult: .success(sampleSettings))
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        vm.selectTimeZone("America/Manaus")
        await vm.requestPreview()
        #expect(vm.isConfirmationPresented == true)

        vm.cancelConfirmation()

        #expect(vm.isConfirmationPresented == false)
        #expect(vm.selectedTimeZoneID == "America/Manaus")
        let changeCalls = await spy.changeTimeZoneCalls
        #expect(changeCalls == 0)
    }

    @Test("SPEC-002 CA-09 network error on confirmation keeps sheet and selection intact for retry")
    func confirmationErrorPreservesState() async {
        let spy = FamilyRepositorySpy(
            settingsResult: .success(sampleSettings),
            changeTimeZoneResults: [.failure(FamilyError.network)]
        )
        let vm = FamilySettingsViewModel(
            repository: spy,
            session: adminSession,
            accessTokenProvider: { "token" }
        )

        await vm.loadSettings()
        vm.selectTimeZone("America/Manaus")
        await vm.requestPreview()

        await vm.confirmChange()

        #expect(vm.isConfirmationPresented == true)
        #expect(vm.selectedTimeZoneID == "America/Manaus")
        #expect(vm.errorMessage != nil)
        #expect(vm.currentSettings?.timeZoneID == "America/Sao_Paulo")
    }
}
