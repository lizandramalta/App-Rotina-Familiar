import SwiftUI

/// Root of the onboarding stack: TEL-055 → TEL-002 → TEL-056.
struct InitialOnboardingFlowView: View {
    @State private var viewModel: InitialOnboardingViewModel

    init(viewModel: InitialOnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack(path: $viewModel.path) {
            InitialProfileView(viewModel: viewModel)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .family:
                        CreateFamilyView(viewModel: viewModel)
                    case .inviteMembers:
                        InviteMembersView(viewModel: viewModel)
                    }
                }
        }
    }
}
