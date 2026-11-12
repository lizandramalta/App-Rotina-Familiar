# Mutua Mobile Design System

Este diretório contém a fundação do **Design System de Alta Fidelidade** do aplicativo Mutua em Swift/SwiftUI.

> 📖 **Documentação Completa de Design:** Consulte [`docs/design/design-system.md`](../../../docs/design/design-system.md) para a especificação canônica com a rastreabilidade aos nós do Figma (`960:25` e `870:22509`).

---

## 🚀 Como Utilizar nos Componentes e Telas

### 1. Cores Semânticas
Sempre acesse as cores via `Color.App.*` ou `AppColor.*`. **Nunca** use literais hexadecimais soltos ou cores padrão do sistema como `Color.blue` ou `Color.white`.

```swift
import SwiftUI

// Fundos
.background(Color.App.Background.app)          // #FBFCF8 - Fundo padrão da tela
.background(Color.App.Background.card)         // #FFFFFF - Fundo de cards
.background(Color.App.Background.cardHighlight)// #E9EFDC - Destaques suaves

// Bordas
.overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.card, lineWidth: 1))
.overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(Color.App.Border.separator, lineWidth: 1.5))

// Textos
Text("Título").foregroundStyle(Color.App.Text.primary)   // #423C1F - Texto escuro
Text("Subtítulo").foregroundStyle(Color.App.Text.secondary) // #6B6B6B - Texto secundário

// Status
.foregroundStyle(Color.App.Status.completed) // #829DC4 - Azul concluído
.foregroundStyle(Color.App.Status.pending)   // #F3ABA5 - Salmão pendente
.foregroundStyle(Color.App.Status.waiting)   // #EECDD9 - Rosa aguardando
```

---

### 2. Tipografia
Sempre use a escala de 14 papéis via `.font(.app(.role))`.

```swift
// Títulos (Serif / Source Serif 4 fallback)
Text("Título de Tela").font(.app(.titleLarge))  // 34pt Bold
Text("Título 1").font(.app(.title1))            // 28pt Bold
Text("Título 2").font(.app(.title2))            // 22pt Bold
Text("Título 3").font(.app(.title3))            // 20pt Bold
Text("Título de Card").font(.app(.cardTitle))   // 17pt Bold

// Textos (Default / Nunito fallback)
Text("Corpo de texto").font(.app(.body))        // 17pt Medium
Text("Corpo forte").font(.app(.bodyStrong))     // 17pt Bold
Text("Subtítulo").font(.app(.subtitle))         // 15pt Medium
Text("Subtítulo forte").font(.app(.subtitleStrong)) // 15pt Bold
Text("Nota").font(.app(.note))                  // 13pt Regular
Text("Nota forte").font(.app(.noteStrong))      // 13pt Bold
Text("Legenda").font(.app(.caption))            // 12pt Regular

// Números (Fonte oficial Sour Gummy empacotada no app, peso Medium 500)
Text("42").font(.app(.numberLarge))             // 44pt Medium (Sour Gummy)
Text("10").font(.app(.number))                  // 22pt Medium (Sour Gummy)
```

---

### 3. Espaçamentos e Raios
**Nunca** use números mágicos em `padding`, `spacing` ou `cornerRadius`.

```swift
// Espaçamento (AppSpacing)
VStack(spacing: AppSpacing.sm) { ... }          // 8 pt
.padding(.horizontal, AppSpacing.lg)            // 16 pt
.padding(.vertical, AppSpacing.md)              // 12 pt

// Raios de Canto (AppRadius)
.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))   // 14 pt (Cards)
.clipShape(RoundedRectangle(cornerRadius: AppRadius.banner)) // 12 pt (Banners)
.clipShape(RoundedRectangle(cornerRadius: AppRadius.sheet))  // 16 pt (Modais)
.clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))   // 22 pt (Pills/Círculos)
```

---

### 4. Componentes Prontos

* **`AppTabBar`**: Cápsula flutuante de navegação para adultos (`.tasks`, `.family`, `.missions`, `.profile`).
* **`DayCarouselItemView`**: Item do carrossel diário (`.standard`, `.today`, `.selected`, `.todaySelected`).
* **`CircularAddButton`**: Botão circular de 44x44 pt para adicionar tarefas ou itens.
* **`InlineFeedbackBanner`**: Banner inline com ícone para mensagens e alertas.
* **`StarDecorationView`**: Estrelas decorativas de 5 pontas (`.blue` e `.yellow`), com `.accessibilityHidden(true)`.

---

## 🧪 Testes

Os testes unitários do Design System estão localizados em:
- `mobile/FoundationTests/DesignSystem/DesignTokensTests.swift`
- `mobile/FoundationTests/DesignSystem/DesignComponentsTests.swift`
