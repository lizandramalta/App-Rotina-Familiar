import SwiftUI

/// TEL-011 — family tasks for the selected interval (SPEC-009 CA-06/07/12).
struct FamilyTasksView: View {
    @State var viewModel: FamilyTasksViewModel
    let onOpenTask: (UUID) -> Void

    init(viewModel: FamilyTasksViewModel, onOpenTask: @escaping (UUID) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenTask = onOpenTask
    }

    var body: some View {
        FamilyTasksDesignedView(viewModel: viewModel, onOpenTask: onOpenTask)
    }
}
