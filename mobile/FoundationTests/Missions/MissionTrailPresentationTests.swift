import Foundation
@testable import FamilyRoutine
import Testing

/// SPEC-016 CA-08 / UX-016 UX-10 to UX-12: node tone/icon and the secondary line of TEL-021.
struct MissionTrailPresentationTests {
    private let ptBR = Locale(identifier: "pt_BR")
    private let isa = MissionTaskAssignee(memberID: UUID(), displayName: "Isa")
    private let theo = MissionTaskAssignee(memberID: UUID(), displayName: "Theo")
    private let renata = MissionTaskAssignee(memberID: UUID(), displayName: "Renata")
    private let removed = MissionTaskAssignee(memberID: nil, displayName: "Membro removido")

    private func task(
        _ status: TaskStatus,
        date: String? = "2026-10-10",
        assignees: [MissionTaskAssignee] = []
    ) -> MissionLinkedTask {
        MissionLinkedTask(id: UUID(), title: "Faxina da sala", status: status, scheduledDate: date, assignees: assignees)
    }

    @Test("UX-11: completed is blue with a check, whether solo or group")
    func completedIsAlwaysBlue() {
        #expect(MissionTrailNodeAppearance(task: task(.completed, assignees: [isa])) == .init(tone: .completed, icon: .check))
        #expect(MissionTrailNodeAppearance(task: task(.completed, assignees: [isa, theo])) == .init(tone: .completed, icon: .check))
    }

    @Test("UX-11: not completed is pink in a group (2+) and green when solo (0 or 1)")
    func pendingToneFollowsAssigneeCount() {
        #expect(MissionTrailNodeAppearance(task: task(.pending, assignees: [isa, theo])).tone == .group)
        #expect(MissionTrailNodeAppearance(task: task(.pending, assignees: [isa])).tone == .solo)
        #expect(MissionTrailNodeAppearance(task: task(.pending)).tone == .solo)
        #expect(MissionTrailNodeAppearance(task: task(.pending, assignees: [isa])).icon == .star)
    }

    @Test("UX-12: awaiting confirmation keeps the rule color with a clock, never the check")
    func awaitingUsesClock() {
        #expect(MissionTrailNodeAppearance(task: task(.awaitingConfirmation, assignees: [isa])) == .init(tone: .solo, icon: .clock))
        #expect(MissionTrailNodeAppearance(task: task(.awaitingConfirmation, assignees: [isa, theo])) == .init(tone: .group, icon: .clock))
    }

    @Test("Short date matches Figma ('Sáb, 10 out') and never shifts a day")
    func shortDateFormat() {
        #expect(MissionTrailText.shortDate(fromWire: "2026-10-10", locale: ptBR) == "Sáb, 10 out")
        #expect(MissionTrailText.shortDate(fromWire: "2026-10-05", locale: ptBR) == "Seg, 5 out")
        #expect(MissionTrailText.shortDate(fromWire: "invalid", locale: ptBR) == nil)
    }

    @Test("UX-10: pending shows date and every name, joined with 'e'")
    func pendingLine() {
        #expect(MissionTrailText.secondaryLine(for: task(.pending, assignees: [isa]), locale: ptBR) == "Sáb, 10 out · Isa")
        #expect(MissionTrailText.secondaryLine(for: task(.pending, assignees: [isa, theo]), locale: ptBR) == "Sáb, 10 out · Isa e Theo")
        #expect(
            MissionTrailText.secondaryLine(for: task(.pending, assignees: [isa, theo, renata]), locale: ptBR)
                == "Sáb, 10 out · Isa, Theo e Renata"
        )
    }

    @Test("UX-10: completed and awaiting show the state before the names")
    func stateLine() {
        #expect(MissionTrailText.secondaryLine(for: task(.completed, assignees: [isa]), locale: ptBR) == "Concluída · Isa")
        #expect(
            MissionTrailText.secondaryLine(for: task(.awaitingConfirmation, assignees: [theo]), locale: ptBR)
                == "Aguardando confirmação · Theo"
        )
    }

    @Test("UX-10: without assignees only the date or state remains; removed member is labeled")
    func fallbacks() {
        #expect(MissionTrailText.secondaryLine(for: task(.pending), locale: ptBR) == "Sáb, 10 out")
        #expect(MissionTrailText.secondaryLine(for: task(.completed), locale: ptBR) == "Concluída")
        #expect(MissionTrailText.secondaryLine(for: task(.pending, date: nil), locale: ptBR) == "Pendente")
        #expect(
            MissionTrailText.secondaryLine(for: task(.pending, assignees: [isa, removed]), locale: ptBR)
                == "Sáb, 10 out · Isa e Membro removido"
        )
    }

    @Test("UX-016 §8: node label has title, state, date, assignees and balloon")
    func accessibilityLabel() {
        let label = MissionTrailText.accessibilityLabel(
            for: task(.pending, assignees: [isa, theo]),
            balloon: "SUA TAREFA",
            locale: ptBR
        )
        #expect(label == "Faxina da sala, Pendente, Sáb, 10 out, Isa e Theo, SUA TAREFA")
    }
}
