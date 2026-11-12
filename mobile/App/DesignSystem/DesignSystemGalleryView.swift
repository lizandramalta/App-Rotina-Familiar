import SwiftUI

/// Visual showcase of all Design System tokens and components.
/// Open this file in Xcode to view the interactive live Canvas `#Preview`.
struct DesignSystemGalleryView: View {
    @State private var selectedTab: AppTabItem = .tasks
    @State private var selectedCarouselDay: String = "5"
    @State private var addClickCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxxl) {
                    headerSection
                    tabBarSection
                    dayCarouselSection
                    buttonsAndFeedbackSection
                    decorationsSection
                    colorsSection
                    typographySection
                    spacingAndRadiusSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(Color.App.Background.app.ignoresSafeArea())
            .navigationTitle("Design System")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Mutua Design System")
                .font(.app(.titleLarge))
                .foregroundStyle(Color.App.Text.primary)
            Text("Catálogo visual de componentes e tokens de alta fidelidade.")
                .font(.app(.body))
                .foregroundStyle(Color.App.Text.secondary)
        }
    }

    private var tabBarSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("AppTabBar (Navegação Adulta)", subtitle: "Cápsula flutuante com 4 destinos e abas ativas/inativas")

            VStack(spacing: AppSpacing.md) {
                AppTabBar(selectedTab: $selectedTab)

                Text("Aba selecionada: \(selectedTab.title)")
                    .font(.app(.caption))
                    .foregroundStyle(Color.App.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var dayCarouselSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("DayCarouselItemView (Carrossel RN49)", subtitle: "Estados: Padrão, Hoje, Selecionado e Hoje selecionado")

            HStack(spacing: AppSpacing.md) {
                DayCarouselItemView(weekday: "DOM", dayNumber: "3", state: .standard)
                DayCarouselItemView(weekday: "SEG", dayNumber: "4", state: .today)
                DayCarouselItemView(weekday: "TER", dayNumber: "5", state: .selected)
                DayCarouselItemView(weekday: "HOJE", dayNumber: "4", state: .todaySelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var buttonsAndFeedbackSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Botões e Feedback", subtitle: "CircularAddButton e InlineFeedbackBanner")

            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.lg) {
                    CircularAddButton {
                        addClickCount += 1
                    }

                    Text("Toques no botão: \(addClickCount)")
                        .font(.app(.body))
                        .foregroundStyle(Color.App.Text.primary)
                }

                InlineFeedbackBanner(
                    message: "Não foi possível conectar. Verifique sua internet."
                )

                InlineFeedbackBanner(
                    message: "Tarefa reaberta com sucesso.",
                    systemImage: "arrow.counterclockwise.circle"
                )
            }
            .padding(AppSpacing.lg)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var decorationsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("StarDecorationView", subtitle: "Estrelas decorativas azul e amarela (accessibilityHidden)")

            HStack(spacing: AppSpacing.giant) {
                VStack(spacing: AppSpacing.xs) {
                    StarDecorationView(variant: .blue, size: 54)
                    Text("Azul").font(.app(.caption)).foregroundStyle(Color.App.Text.secondary)
                }

                VStack(spacing: AppSpacing.xs) {
                    StarDecorationView(variant: .yellow, size: 54)
                        .rotationEffect(.degrees(15))
                    Text("Amarela (+15°)").font(.app(.caption)).foregroundStyle(Color.App.Text.secondary)
                }

                // Exemplo aplicado em card
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Destaque").font(.app(.cardTitle)).foregroundStyle(Color.App.Text.primary)
                        Text("Card com estrela").font(.app(.note)).foregroundStyle(Color.App.Text.secondary)
                    }
                    .padding(AppSpacing.md)
                    .background(Color.App.Background.cardHighlight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.cardHighlight, lineWidth: 1))

                    StarDecorationView(variant: .yellow, size: 28)
                        .rotationEffect(.degrees(-10))
                        .offset(x: 8, y: -8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Amostra de Cores Semânticas", subtitle: "Color.App.* (Background, Text, Action, Status, Member)")

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                colorRow("Status", colors: [
                    ("Concluída", Color.App.Status.completed),
                    ("Aguardando", Color.App.Status.waiting),
                    ("Pendente", Color.App.Status.pending),
                ])

                colorRow("Membros", colors: [
                    ("Renata", Color.App.Member.renata),
                    ("Isa", Color.App.Member.isa),
                    ("Theo", Color.App.Member.theo),
                    ("Daniel", Color.App.Member.daniel),
                    ("Você", Color.App.Member.you),
                ])

                colorRow("Ação / Fundo", colors: [
                    ("Primária", Color.App.Action.primary),
                    ("Suave", Color.App.Action.primarySoft),
                    ("Card Destaque", Color.App.Background.cardHighlight),
                    ("Separador", Color.App.Border.separator),
                ])
            }
            .padding(AppSpacing.lg)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Escala Tipográfica", subtitle: "Font.app(_:)")

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(".titleLarge (34pt)").font(.app(.titleLarge))
                Text(".title1 (28pt)").font(.app(.title1))
                Text(".title2 (22pt)").font(.app(.title2))
                Text(".title3 (20pt)").font(.app(.title3))
                Text(".cardTitle (17pt)").font(.app(.cardTitle))
                Text(".body (17pt Medium)").font(.app(.body))
                Text(".bodyStrong (17pt Bold)").font(.app(.bodyStrong))
                Text(".subtitle (15pt Medium)").font(.app(.subtitle))
                Text(".note (13pt Regular)").font(.app(.note))
                Text(".caption (12pt Regular)").font(.app(.caption))
                HStack(spacing: AppSpacing.md) {
                    Text("44").font(.app(.numberLarge))
                    Text(".numberLarge")
                    Text("22").font(.app(.number))
                    Text(".number")
                }
            }
            .foregroundStyle(Color.App.Text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.lg)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    private var spacingAndRadiusSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("Raios de Canto (AppRadius)", subtitle: "banner: 12, card: 14, sheet: 16, pill: 22, cardBoard: 24")

            HStack(spacing: AppSpacing.sm) {
                radiusSample("banner\n12pt", radius: AppRadius.banner)
                radiusSample("card\n14pt", radius: AppRadius.card)
                radiusSample("sheet\n16pt", radius: AppRadius.sheet)
                radiusSample("pill\n22pt", radius: AppRadius.pill)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .background(Color.App.Background.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.app(.cardTitle))
                .foregroundStyle(Color.App.Text.primary)
            Text(subtitle)
                .font(.app(.caption))
                .foregroundStyle(Color.App.Text.secondary)
        }
    }

    private func colorRow(_ category: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(category)
                .font(.app(.noteStrong))
                .foregroundStyle(Color.App.Text.secondary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(colors, id: \.0) { item in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(item.1)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                        Text(item.0)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.App.Text.secondary)
                    }
                }
            }
        }
    }

    private func radiusSample(_ label: String, radius: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.App.Text.primary)
            .frame(width: 68, height: 50)
            .background(Color.App.Background.cardHighlight)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.App.Border.cardHighlight, lineWidth: 1))
    }
}

#Preview {
    DesignSystemGalleryView()
}
