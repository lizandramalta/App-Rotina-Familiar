# Design System — Alta Fidelidade (Mutua Mobile)

**Versão:** 1.0\
**Data:** 2026-11-12\
**Situação:** norma técnica e guia de utilização do Design System em SwiftUI (`mobile/`)

[Screen map](screen-map.md) · [User flows](user-flows.md) · [Convenções mobile](../architecture/mobile-code-conventions.md) · [Arquitetura mobile](../architecture/mobile-architecture.md) · [Índice](../DOCUMENTACAO.md)

---

## 1. Visão geral e fontes de verdade

Este documento define a especificação e as diretrizes de utilização da camada de apresentação e componentes de interface do aplicativo **Mutua** (iOS/iPadOS). Ele é a **referência canônica para desenvolvedores e agentes de IA** implementarem telas, fluxos e componentes visuais.

### Fontes no Figma
As definições visuais deste Design System derivam diretamente dos seguintes nós do arquivo do Figma:
- **Design Tokens:** [`node-id=960-25`](https://www.figma.com/design/CuxXOp9tKivMbELeeB6mHw/APP-FAM%C3%8DLIA-%7C-C18?node-id=960-25) (*Documentação · Design System Alta (em revisão)*).
- **Componentes Base:** [`node-id=870-22509`](https://www.figma.com/design/CuxXOp9tKivMbELeeB6mHw/APP-FAM%C3%8DLIA-%7C-C18?node-id=870-22509) (*Componentes · Alta (definitivos em revisão)*).

### Localização no Código
Todo o código do Design System está implementado no módulo mobile sob:
- Tokens: `mobile/App/DesignSystem/Tokens/`
- Componentes: `mobile/App/DesignSystem/Components/`
- Testes: `mobile/FoundationTests/DesignSystem/`

---

## 2. Regras de ouro para Agentes de IA

Ao criar ou modificar qualquer View em SwiftUI no projeto:

1. **Nunca use cores brutas ou cores genéricas do sistema:**
   - ❌ `Color(hex: "FBFCF8")`, `Color.white`, `Color.black`, `Color.gray`, `Color.blue`.
   - ✅ `Color.App.Background.app`, `Color.App.Background.card`, `Color.App.Text.primary`, `Color.App.Status.completed`.
2. **Nunca use tamanhos de fonte arbitrários para textos de UI:**
   - ❌ `Text("Título").font(.system(size: 22, weight: .bold))`
   - ✅ `Text("Título").font(.app(.title2))`
3. **Nunca use espaçamentos numéricos "mágicos":**
   - ❌ `VStack(spacing: 15)`, `.padding(10)`
   - ✅ `VStack(spacing: AppSpacing.lg)`, `.padding(.horizontal, AppSpacing.lg)`
4. **Nunca hardcode raios de borda (`cornerRadius`):**
   - ❌ `.cornerRadius(10)`
   - ✅ `.clipShape(RoundedRectangle(cornerRadius: AppRadius.card))`
5. **Textos sempre via catálogo de strings (`Localizable.xcstrings`):**
   - ❌ `Text("Tarefas")`
   - ✅ `Text("family.tasks.title")` ou chave correspondente da SPEC/UX-spec.
6. **Acessibilidade não é acabamento:**
   - Todo controle interativo deve ter trait `.isButton` e `accessibilityLabel` claro.
   - Elementos puramente visuais ou decorativos (como estrelas) devem conter `.accessibilityHidden(true)`.

---

## 3. Design Tokens

### 3.1 Cores Semânticas (`AppColor` / `Color.App`)
As cores estão agrupadas semanticamente sob o enum `AppColor` (acessível via alias `Color.App.*` em qualquer View SwiftUI).

```swift
import SwiftUI

// Exemplo de uso:
Text("Título")
    .foregroundStyle(Color.App.Text.primary)
    .background(Color.App.Background.card)
```

#### Fundo (`Color.App.Background.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `app` | `#FBFCF8` | Fundo principal da aplicação e telas. |
| `card` | `#FFFFFF` | Fundo de cards padrão, modais e containers. |
| `cardHighlight` | `#E9EFDC` | Fundo de cards em destaque e abas ativas. |
| `subtle` | `#E9EFDC` | Fundo suave de apoio (`#E9EFDC`). |
| `cardUpdate` | `#F2F6FC` | Fundo sutil de cards de novidade / atualização. |

#### Borda (`Color.App.Border.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `card` | `#CFE0BE` | Contorno de cards padrão (verde-oliva suave). |
| `cardHighlight` | `#C3CCAD` | Contorno de cards em destaque. |
| `separator` | `#DDE4CC` | Linhas divisórias, bordas de carrossel e botões. |

#### Texto (`Color.App.Text.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `primary` | `#423C1F` | Texto principal, títulos e rótulos escuros. |
| `secondary` | `#6B6B6B` | Textos secundários, legendas e notas. |
| `highlight` | `#57613D` | Textos em ênfase verde-oliva. |
| `onAction` | `#FFFFFF` | Texto sobre botões e fundos escuros de ação. |
| `onCompleted` | `#2E3F5C` | Texto escuro sobre fundos azuis de conclusão. |

#### Ação (`Color.App.Action.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `primary` | `#57613D` | Cor principal de botões de ação e CTAs. |
| `primarySoft` | `#81905B` | Variação suave de botões de ação secundários. |

#### Status (`Color.App.Status.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `completed` | `#829DC4` | Azul de tarefa ou meta concluída. |
| `completedBackground` | `#E3EBF7` | Fundo de container de item concluído. |
| `completedBorder` | `#ADBBD2` | Borda de container concluído. |
| `completedOutline` | `#5F7DAD` | Contorno de destaque concluído. |
| `waiting` | `#EECDD9` | Rosa para itens aguardando aprovação/confirmação. |
| `waitingBackground` | `#FBEAF0` | Fundo suave de itens aguardando. |
| `waitingBorder` | `#D4B3C0` | Borda de itens aguardando. |
| `pending` | `#F3ABA5` | Salmão de tarefa pendente. |

#### Membro da Família (`Color.App.Member.*`)
Cores de identificação individual e trilhas de progresso:
| Membro | Hex Principal | Hex Trilha (`*Track`) |
|---|---|---|
| Renata | `renata` (`#9D659F`) | `renataTrack` (`#E3D0EC`) |
| Isa | `isa` (`#E27D74`) | `isaTrack` (`#FFDDDD`) |
| Theo | `theo` (`#317EAD`) | `theoTrack` (`#C8D5DB`) |
| Daniel | `daniel` (`#8F8D42`) | `danielTrack` (`#E0E0E0`) |
| Você (Titular) | `you` (`#57613D`) | `youTrack` (`#E9EFDC`) |

#### Decoração (`Color.App.Decoration.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `yellow` | `#FFF0B5` | Amarelo decorativo base. |
| `yellowShadow` | `#F3DC93` | Sombra de elementos amarelos. |
| `ochre` | `#C29A2E` | Ocre para ilustrações e selos. |
| `ochreInner` | `#D9B24E` | Ocre interno de contraste. |
| `starBlue` | `#A9BBD8` | Estrela decorativa azul. |
| `starYellow` | `#E6CF86` | Estrela decorativa amarela. |

#### Sistema (`Color.App.System.*`)
| Token | Hex | Descrição / Uso |
|---|---|---|
| `destructive` | `#FF3B30` | Vermelho de exclusão e ações destrutivas. |
| `dimming` | `#000000` | Escurecimento de fundo / overlay / caixas pretas. |

---

### 3.2 Tipografia (`AppTypography` / `Font.app`)
A escala tipográfica possui 14 papéis funcionais. O aplicativo utiliza a fonte oficial `Sour Gummy` empacotada no projeto (`UIAppFonts`) e fallbacks nativos correspondentes:
- **Títulos:** Fonte pretendida `Source Serif 4` → fallback nativo `Font.Design.serif`.
- **Textos de interface:** Fonte pretendida `Nunito` → fallback nativo `Font.Design.default`.
- **Números:** Fonte oficial empacotada `Sour Gummy` (`SourGummy.ttf`, peso Medium 500) → fallback nativo `Font.Design.rounded`.

```swift
import SwiftUI

// Exemplo de uso:
Text("Minhas Tarefas")
    .font(.app(.titleLarge))

Text("Descrição da rotina")
    .font(.app(.body))
```

#### Tabela da Escala Tipográfica
| Papel | Tamanho | Peso | Design | Entrelinha | Uso Típico |
|---|---|---|---|---|---|
| `.titleLarge` | 34 pt | Bold | Serif | 1.15em | Título principal de tela. |
| `.title1` | 28 pt | Bold | Serif | padrão | Títulos de seções principais. |
| `.title2` | 22 pt | Bold | Serif | padrão | Títulos de grupos e blocos. |
| `.title3` | 20 pt | Bold | Serif | padrão | Subtítulos de cabeçalho. |
| `.cardTitle` | 17 pt | Bold | Serif | padrão | Título de cards e listas. |
| `.body` | 17 pt | Medium | Default | 1.3em | Corpo de texto padrão. |
| `.bodyStrong` | 17 pt | Bold | Default | padrão | Corpo de texto enfatizado. |
| `.subtitle` | 15 pt | Medium | Default | padrão | Subtítulos e banners de apoio. |
| `.subtitleStrong` | 15 pt | Bold | Default | padrão | Rótulos de botões e ênfases. |
| `.note` | 13 pt | Regular | Default | padrão | Notas de rodapé e orientações. |
| `.noteStrong` | 13 pt | Bold | Default | padrão | Notas de rodapé em destaque. |
| `.caption` | 12 pt | Regular | Default | padrão | Legendas de status e datas. |
| `.numberLarge` | 44 pt | Medium | Rounded | padrão | Pontuação e contadores de destaque. |
| `.number` | 22 pt | Medium | Rounded | padrão | Contadores diários e progresso. |

---

### 3.3 Espaçamentos (`AppSpacing`)
Tamanhos fixos e padronizados para `padding`, `spacing` em stacks e grids:

| Token | Valor | Uso Típico |
|---|---|---|
| `AppSpacing.xxs` | 2 pt | Gaps mínimos internos (ex: entre ícone e texto na tab bar). |
| `AppSpacing.xs` | 4 pt | Padding de cápsulas e borders internos. |
| `AppSpacing.sm` | 8 pt | Espaçamento entre ícone e texto em banners/listas. |
| `AppSpacing.md` | 12 pt | Padding vertical de cards e botões médios. |
| `AppSpacing.base` | 14 pt | Padding padrão de elementos de formulário. |
| `AppSpacing.lg` | 16 pt | Margem padrão de telas e padding lateral de cards. |
| `AppSpacing.xl` | 18 pt | Gap entre seções em fluxos verticais. |
| `AppSpacing.xxl` | 20 pt | Padding generoso de cartões de destaque. |
| `AppSpacing.xxxl` | 24 pt | Margem entre blocos e seções estruturais. |
| `AppSpacing.giant` | 32 pt | Espaçamento entre cabeçalho e conteúdo. |
| `AppSpacing.huge` | 40 pt | Espaçamento de telas de boas-vindas / onboarding. |
| `AppSpacing.massive` | 64 pt | Separação de grandes áreas vazias. |
| `AppSpacing.colossal` | 80 pt | Espaçamento de boards e banners superiores. |

---

### 3.4 Raios de Borda (`AppRadius`)
Constantes de arredondamento de cantos (`cornerRadius`):

| Token | Valor | Uso Típico |
|---|---|---|
| `AppRadius.banner` | 12 pt | Banners de feedback, alertas inline e avisos. |
| `AppRadius.card` | 14 pt | Cards de tarefas, itens de carrossel e formulários. |
| `AppRadius.sheet` | 16 pt | Modais, sheets e caixas de diálogo. |
| `AppRadius.pill` | 22 pt | Botões circulares de 44 pt e pills de filtro. |
| `AppRadius.cardBoard` | 24 pt | Painéis grandes e cartões de boas-vindas. |

---

## 4. Componentes Base Prontos

### 4.1 Barra de Abas Flutuante (`AppTabBar`)
Componente em formato de cápsula flutuante para a navegação principal adulta (TEL-010/011/014/030), em conformidade com o nó Figma `870:22510`.

```swift
import SwiftUI

struct MyView: View {
    @State private var currentTab: AppTabItem = .tasks

    var body: some View {
        ZStack(alignment: .bottom) {
            // Conteúdo da tela ativa...

            AppTabBar(selectedTab: $currentTab)
                .padding(.bottom, AppSpacing.lg)
        }
    }
}
```
* **Abas:** `.tasks` ("Tarefas"), `.family` ("Família"), `.missions` ("Missões"), `.profile` ("Perfil").
* **Ícones:** Vetores SVG originais do Figma empacotados em `Assets.xcassets` (`TabBarTasksActive/Inactive`, `TabBarFamilyActive/Inactive`, etc.) com renderização nativa preservada.
* **Aparência:** Fundo `card` com contorno `separator` de 1.5 pt e raio 34 pt. A aba selecionada possui fundo `cardHighlight` (`#E9EFDC`), raio de 29 pt, ícone preenchido e tipografia bold.

---

### 4.2 Controle do Carrossel de Dias (`DayCarouselItemView`)
Controle de navegação de dias do calendário/rotina diária (RN49), nó Figma `907:13356`. Os números utilizam a fonte `Sour Gummy` tamanho 20 pt (Medium 500).

```swift
DayCarouselItemView(
    weekday: "SEG",
    dayNumber: "5",
    state: .todaySelected
) {
    // Ação ao selecionar o dia
}
```
* **Estados (`DayCarouselState`):**
  * `.standard`: Sem destaque, dia comum.
  * `.today`: Número com cor de destaque azul (`Status.completed`), sem caixa.
  * `.selected`: Dia não-hoje selecionado, caixa preta (`System.dimming`) com texto branco.
  * `.todaySelected`: Hoje selecionado, caixa azul (`Status.completed`) com texto branco.

---

### 4.3 Botão Circular de Adição (`CircularAddButton`)
Botão de toque 44x44 pt padronizado para criar tarefas ou adicionar itens, nó Figma `907:13369`.

```swift
CircularAddButton {
    // Abrir modal de criação
}
```
* **Aparência:** Botão circular de 44 pt com borda de efeito desenhado a giz/lápis (pincel Drone texturizado, asset `CircularAddButtonBackground`) e ícone `plus` centralizado.
* **Acessibilidade:** Rótulo localizado `"Adicionar"` e trait `.isButton`.

---

### 4.4 Mensagem Inline de Feedback (`InlineFeedbackBanner`)
Banner horizontal para alertas, falhas de conexão ou avisos na tela, nó Figma `907:13372`.

```swift
InlineFeedbackBanner(
    message: String(localized: "common.network.error"),
    systemImage: "wifi.slash" // Opcional, padrão: "exclamationmark.triangle"
)
```
* **Aparência:** Fundo `Background.card`, contorno `Border.separator` de 1 pt, raio `AppRadius.banner` (12 pt), tipografia `.subtitle`.

---

### 4.5 Estrela Decorativa (`StarDecorationView`)
Estrelas orgânicas com contorno irregular de giz/adesivo e sombra suave para decoração em cards de destaque, nós Figma `926:21661` (`.blue`) e `926:21662` (`.yellow`), renderizadas a partir dos assets `StarDecorationBlue` e `StarDecorationYellow`.

```swift
ZStack(alignment: .topTrailing) {
    CardView()
    StarDecorationView(variant: .yellow)
        .padding(AppSpacing.md)
}
```
* **Acessibilidade:** Elemento puramente decorativo, estritamente oculto de tecnologias assistivas (`.accessibilityHidden(true)`).
    CardView()

    StarDecorationView(variant: .yellow, size: 48)
        .rotationEffect(.degrees(15))
        .offset(x: 10, y: -10)
}
```
* **Variantes:** `.blue` (`Decoration.starBlue`) e `.yellow` (`Decoration.starYellow`).
* **Regra mandatória de acessibilidade:** Possui `.accessibilityHidden(true)` embutido para nunca poluir a leitura do VoiceOver.

---

## 5. Histórico e Manutenção

| Versão | Data | Alteração |
|---|---|---|
| 1.0 | 2026-11-12 | Criação da especificação do Design System com base nos nós Figma 960:25 e 870:22509, documentando tokens de cores, tipografia, espaçamentos, raios e componentes primitivos. |
