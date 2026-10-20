import SwiftUI

private enum MemberFormTarget: Hashable, Identifiable {
    case new
    case edit(DraftMember)

    var id: String {
        switch self {
        case .new: "new"
        case let .edit(member): member.id.uuidString
        }
    }
}

/// TEL-002 — Crie sua família (Figma node 54:476).
struct CreateFamilyView: View {
    @Bindable var viewModel: InitialOnboardingViewModel
    @State private var memberForm: MemberFormTarget?
    @State private var isTimeZonePickerPresented = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header: Título Grande + Subtítulo explicativo
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.create.title")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(uiColor: .label))

                    Text("family.create.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .padding(.horizontal, 4)

                // Banners de erro / resultado incerto / foto
                bannerSection
                photoStatusSection

                // Seção: Nome da família
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.create.name.label")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    HStack {
                        TextField("family.create.name.placeholder", text: $viewModel.familyName)
                            .font(.body)
                            .focused($isNameFocused)
                            .accessibilityIdentifier("family.create.name")

                        if viewModel.familyNameError != nil {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    HStack(alignment: .top) {
                        if let error = viewModel.familyNameError {
                            Label {
                                Text(error == .required ? "family.create.name.error_required" : "family.create.name.error_invalid")
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("family.create.name_error")
                        } else {
                            Text("family.create.name.footer")
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        Spacer()
                        Text("\(viewModel.familyName.count)/60")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .padding(.horizontal, 8)
                }

                // Seção: Fuso horário
                VStack(alignment: .leading, spacing: 6) {
                    Text("family.create.section.time_zone")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 4)

                    Button {
                        isTimeZonePickerPresented = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(TimeZoneDisplay.city(viewModel.timeZoneID))
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .label))

                                Text(viewModel.timeZoneID)
                                    .font(.footnote)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.create.timezone")
                    .accessibilityValue(Text(viewModel.timeZoneID))

                    Text("family.create.time_zone.footer")
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.horizontal, 8)
                }

                // Seção: Membros
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("family.members.section")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .accessibilityIdentifier("family.members.section")

                        Text("family.members.subtitle")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    .padding(.horizontal, 4)

                    // Lista de membros adicionados
                    if !viewModel.members.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.members.enumerated()), id: \.element.id) { index, member in
                                Button {
                                    memberForm = .edit(member)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(uiColor: .systemGray5))
                                            Text(String(member.name.prefix(1)).uppercased())
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                        }
                                        .frame(width: 36, height: 36)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(member.name)
                                                .font(.body)
                                                .foregroundStyle(Color(uiColor: .label))

                                            Text(member.role.onboardingTitleKey)
                                                .font(.footnote)
                                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.forward")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("family.members.row")

                                if index < viewModel.members.count - 1 {
                                    Divider()
                                        .padding(.leading, 64)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }

                    // Botão "+ Adicionar membro" (sempre abaixo da lista)
                    Button {
                        memberForm = .new
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .systemGray5))
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(uiColor: .label))
                            }
                            .frame(width: 36, height: 36)

                            Text("family.members.add")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .label))

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("family.members.add")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
            .onboardingColumn()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.goBackToProfile()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .disabled(viewModel.isFamilyCreated || viewModel.isCreating)
                .accessibilityIdentifier("family.create.back")
                .accessibilityLabel("Voltar")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !viewModel.isFamilyCreated {
                Button {
                    Task { await viewModel.createFamily() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isCreating {
                            ProgressView()
                                .tint(Color(uiColor: .systemBackground))
                            Text("family.create.submitting")
                        } else {
                            Text("family.create.submit")
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(uiColor: .label))
                    .clipShape(Capsule())
                }
                .disabled(viewModel.isCreating)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .onboardingColumn()
                .accessibilityIdentifier("family.create.submit")
            }
        }
        .sheet(isPresented: $isTimeZonePickerPresented) {
            TimeZonePickerSheetView(selection: $viewModel.timeZoneID)
        }
        .sheet(item: $memberForm) { target in
            NavigationStack {
                InitialMemberDraftFormView(viewModel: viewModel, member: member(for: target))
            }
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
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("family.create.error_uncertain")
                        .font(.footnote)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
                .accessibilityIdentifier("family.create.uncertain_banner")

                Button {
                    viewModel.verifyAccess()
                } label: {
                    Text("family.create.verify_access")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("family.create.verify_access")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .creationGrantInvalid:
            bannerLabel("family.create.error_grant_invalid", identifier: "family.create.grant_invalid_banner")
        case .rateLimited:
            bannerLabel("family.create.error_rate_limited", identifier: "family.create.rate_limited_banner")
        case .unavailable:
            bannerLabel("family.create.error_network", identifier: "family.create.unavailable_banner")
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var photoStatusSection: some View {
        switch viewModel.photoStatus {
        case .uploading:
            HStack(spacing: 8) {
                ProgressView()
                Text("onboarding.profile.photo.uploading")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityIdentifier("profile.initial.photo_uploading")

        case .failed:
            VStack(alignment: .leading, spacing: 12) {
                bannerLabel("onboarding.profile.photo.error_upload", identifier: "profile.initial.photo_error_banner")

                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.retryPhoto() }
                    } label: {
                        Text("onboarding.profile.photo.retry")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .label))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("profile.initial.photo_retry")

                    Button {
                        Task { await viewModel.skipPhoto() }
                    } label: {
                        Text("onboarding.profile.photo.skip")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("profile.initial.photo_skip")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .idle:
            EmptyView()
        }
    }

    private func bannerLabel(_ key: LocalizedStringKey, identifier: String) -> some View {
        Label {
            Text(key)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .foregroundStyle(.red)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier(identifier)
    }
}
