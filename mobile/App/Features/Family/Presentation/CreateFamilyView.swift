import SwiftUI

private enum MemberFormTarget: Identifiable {
    case new
    case edit(DraftMember)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(member): member.id.uuidString
        }
    }
}

/// TEL-002 — family name, time zone and local member drafts.
struct CreateFamilyView: View {
    @Bindable var viewModel: InitialOnboardingViewModel
    @State private var memberForm: MemberFormTarget?
    @State private var isTimeZonePickerPresented = false

    var body: some View {
        Form {
            bannerSection

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("family.create.name.label")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("family.create.name.placeholder", text: $viewModel.familyName)
                        .accessibilityIdentifier("family.create.name")
                    if let error = viewModel.familyNameError {
                        FieldErrorText(
                            key: error == .required
                                ? "family.create.name.error_required"
                                : "family.create.name.error_invalid",
                            identifier: "family.create.name_error"
                        )
                    }
                }
            } header: {
                Text("family.create.section.identification")
            }

            Section {
                Button {
                    isTimeZonePickerPresented = true
                } label: {
                    HStack {
                        Text("family.create.time_zone.label")
                            .foregroundStyle(.primary)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(TimeZoneDisplay.city(viewModel.timeZoneID))
                            Text(viewModel.timeZoneID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityIdentifier("family.create.timezone")
                .accessibilityValue(Text(viewModel.timeZoneID))
            } header: {
                Text("family.create.section.time_zone")
            } footer: {
                Text("family.create.time_zone.footer")
            }

            Section {
                ForEach(viewModel.members) { member in
                    Button {
                        memberForm = .edit(member)
                    } label: {
                        HStack {
                            Text(member.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            RoleBadge(role: member.role)
                        }
                    }
                    .accessibilityIdentifier("family.members.row")
                }
                Button {
                    memberForm = .new
                } label: {
                    Label("family.members.add", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("family.members.add")
            } header: {
                Text("family.members.section")
                    .accessibilityIdentifier("family.members.section")
            } footer: {
                if viewModel.members.isEmpty {
                    Text("family.members.empty_footer")
                }
            }
            .disabled(viewModel.isFamilyCreated)
        }
        .disabled(viewModel.isCreating && !viewModel.isFamilyCreated)
        .onboardingColumn()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("family.create.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.goBackToProfile()
                } label: {
                    Label("family.create.back", systemImage: "chevron.backward")
                }
                .disabled(viewModel.isFamilyCreated || viewModel.isCreating)
                .accessibilityIdentifier("family.create.back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isFamilyCreated {
                OnboardingPrimaryButton(
                    title: viewModel.isCreating ? "family.create.submitting" : "family.create.submit",
                    identifier: "family.create.submit",
                    isLoading: viewModel.isCreating
                ) {
                    Task { await viewModel.createFamily() }
                }
            }
        }
        .sheet(isPresented: $isTimeZonePickerPresented) {
            TimeZonePickerSheetView(selection: $viewModel.timeZoneID)
        }
        .sheet(item: $memberForm) { target in
            InitialMemberDraftFormView(viewModel: viewModel, member: member(for: target))
        }
    }

    private func member(for target: MemberFormTarget) -> DraftMember? {
        if case let .edit(member) = target {
            return member
        }
        return nil
    }

    @ViewBuilder
    private var bannerSection: some View {
        switch viewModel.banner {
        case .uncertainOutcome:
            Section {
                bannerLabel("family.create.error_uncertain", identifier: "family.create.uncertain_banner")
                Button("family.create.verify_access") {
                    viewModel.verifyAccess()
                }
                .accessibilityIdentifier("family.create.verify_access")
            }
        case .creationGrantInvalid:
            Section {
                bannerLabel("family.create.error_grant_invalid", identifier: "family.create.grant_invalid_banner")
                Button("family.create.verify_access") {
                    viewModel.verifyAccess()
                }
                .accessibilityIdentifier("family.create.verify_access")
            }
        case .rateLimited:
            Section {
                bannerLabel("family.create.error_rate_limited", identifier: "family.create.rate_limited_banner")
            }
        case .unavailable:
            Section {
                bannerLabel("family.create.error_unavailable", identifier: "family.create.unavailable_banner")
            }
        case nil:
            EmptyView()
        }

        switch viewModel.photoStatus {
        case .uploading:
            Section {
                HStack {
                    ProgressView()
                    Text("onboarding.profile.photo.uploading")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("profile.initial.photo_uploading")
            }
        case .failed:
            Section {
                bannerLabel("onboarding.profile.photo.error_upload", identifier: "profile.initial.photo_error_banner")
                Button("onboarding.profile.photo.retry") {
                    Task { await viewModel.retryPhoto() }
                }
                .accessibilityIdentifier("profile.initial.photo_retry")
                Button("onboarding.profile.photo.skip") {
                    Task { await viewModel.skipPhoto() }
                }
                .accessibilityIdentifier("profile.initial.photo_skip")
            }
        case .idle:
            EmptyView()
        }
    }

    private func bannerLabel(_ key: LocalizedStringKey, identifier: String) -> some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
