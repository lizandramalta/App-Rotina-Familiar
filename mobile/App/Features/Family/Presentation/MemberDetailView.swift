import SwiftUI

/// TEL-032 — Detalhe do membro (Figma nodes 309:2057, 309:2219, 309:2281, UX-003 §5.2).
struct MemberDetailView: View {
    @State private var viewModel: MemberDetailViewModel

    init(viewModel: MemberDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let detail = viewModel.detail {
                    identity(detail)
                    if viewModel.isCreator {
                        creatorNotice
                    }
                    tasksPlaceholder
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .accessibilityIdentifier("family.member.detail.loading")
                }

                if let message = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Label {
                            Text(message)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("family.member.detail.error")

                        Button("family.member.detail.retry") {
                            Task { await viewModel.load() }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("family.member.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func identity(_ detail: FamilyMemberDetail) -> some View {
        VStack(spacing: 12) {
            Text(String(detail.name.prefix(1)).uppercased())
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 80, height: 80)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                .accessibilityHidden(true)

            Text(detail.name)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("family.member.detail.name")

            Text(detail.role.onboardingTitleKey)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .accessibilityIdentifier("family.member.detail.role")

            if detail.isFamilyCreator {
                Label {
                    Text("family.members.creator_badge")
                } icon: {
                    Image(systemName: "star.fill")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .accessibilityIdentifier("family.member.detail.creator_badge")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var creatorNotice: some View {
        Label {
            Text("family.members.creator_protected")
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.footnote)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("family.member.detail.creator_notice")
    }

    private var tasksPlaceholder: some View {
        Text("family.member.detail.tasks_placeholder")
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}
