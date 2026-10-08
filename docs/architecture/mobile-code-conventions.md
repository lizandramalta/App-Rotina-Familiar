# Convenções de código mobile

**Versão:** 1.0  
**Data:** 2026-10-08  
**Situação:** norma técnica para implementações Swift/SwiftUI

[Arquitetura mobile](mobile-architecture.md) · [Catálogo mobile](mobile-feature-catalog.md) · [Decisões mobile](mobile-decisions.md) · [Índice](../DOCUMENTACAO.md)

## 1. Escopo e precedência

Estas convenções se aplicam a código em `mobile/`. Elas complementam a arquitetura; em conflito, prevalecem a SPEC/UX-spec aprovada para comportamento e a arquitetura para fronteiras técnicas. Não introduzem jornadas, permissões, contratos ou estados de produto.

Código, tipos, arquivos, chaves de localização e comentários técnicos usam inglês. Textos exibidos, documentação explicativa e descrições de acessibilidade usam recursos localizáveis em português. APIs públicas ou compartilhadas recebem documentação `///` curta quando seu propósito não for evidente no uso.

## 2. Organização e nomes

- Use `PascalCase` para tipos e arquivos (`FamilyOverviewViewModel.swift`); `camelCase` para membros, funções, propriedades e cases (`loadFamilyOverview()`, `awaitingConfirmation`).
- Nomeie pelo papel, não pelo mecanismo genérico: `TaskRepository`, `CompleteTaskUseCase`, `TaskDTO`, `RemoteTaskRepository` e `TaskMapper` são preferíveis a `TaskService`, `TaskManager` ou `Utils`.
- Sufixos `ViewModel` identifica estado e coordenação de uma tela; `View` identifica apresentação; `DTO` fica restrito ao transporte; `Command` e `Result` representam intenção e resultado de caso de uso.
- Mantenha vocabulário de domínio estável: `FamilyTask`, `Member`, `Routine`, `Mission`, `RewardItem`, `BadgeAward` e `WeeklyRecognition`. Não crie sinônimos entre features.
- Organize código de feature em `Presentation`, `Application`, `Domain` e `Data` quando a feature passar a ter essas responsabilidades. Não crie pastas, ViewModels ou protocolos vazios apenas para espelhar a árvore arquitetural.

## 3. Swift e SwiftUI

- Use Swift 6, tipos explícitos onde a inferência não deixa a intenção clara e `struct`/`enum` para valores. Evite `Any`, force unwrap, `try!` e `as!`; represente ausência e falha no tipo.
- Indente com quatro espaços, sem tabs. Preserve o formato de imports e quebras de linha do arquivo alterado; não introduza formatador novo sem decisão técnica.
- Views descrevem apresentação, acessibilidade e eventos. Elas não fazem HTTP, não manipulam DTOs, não acessam Keychain e não implementam regras de negócio.
- Use `@State` para estado local de apresentação que pertence à View. ViewModels e routers que coordenam estado observável pertencem ao `@MainActor`; componentes estáticos podem permanecer somente como Views.
- Use `NavigationStack` com rotas tipadas. A View não constrói URLs nem faz parsing de deep link: isso pertence ao router/parser da camada App.
- Todo texto visível deve vir de catálogo de strings. Inclua `accessibilityLabel`, `accessibilityHint` ou valores equivalentes quando o controle não for autoexplicativo para VoiceOver.

## 4. Concorrência, dados e segurança

- Prefira `async/await`. Valores atravessando isolamento devem ser `Sendable`; estado concorrente de infraestrutura deve usar actor ou adaptação segura equivalente.
- Cancelar uma `Task` local não confirma o cancelamento remoto. ViewModels ignoram respostas obsoletas ao trocar sessão, recurso ou filtro.
- `Application` depende de portas/protocolos; `Data` implementa HTTP, DTOs e mapeadores. Converta DTO para modelo/projeção antes de entregar dados à Presentation.
- A API é `/v1`, usa DTOs próprios e erros estáveis. O app não decide autorização, crédito, papel ou estado de domínio a partir da UI; o servidor permanece a autoridade.
- Tokens e refresh credentials ficam somente no Keychain. Não grave credenciais, dados privados ou URLs assinadas em `UserDefaults`, logs, previews ou fixtures.

## 5. Erros, testes e revisão

- Apresente erro recuperável como estado de tela localizado; não exponha mensagens técnicas, tokens ou detalhes de transporte. Mantenha a ação de repetição coerente com o contrato: consultas podem ser repetidas; comandos com resposta perdida exigem reconciliação antes de novo envio.
- Testes usam `Testing` e descrevem comportamento em inglês. Teste caso de uso, ViewModel, mapper e regra local no menor nível que exercite a decisão; teste UI para navegação, acessibilidade e estados visíveis quando aplicável.
- Fixtures são fictícias, determinísticas e sem dados pessoais. Use doubles de portas e relógio/aleatoriedade controláveis.
- Antes da entrega, execute os testes mobile disponíveis e o build de simulador sem assinatura. Se o ambiente não tiver Xcode/simulador compatível, informe precisamente a limitação e forneça o comando para execução local/CI.

## Referências

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — clareza no ponto de uso e documentação de APIs.
- [Arquitetura mobile](mobile-architecture.md) — fronteiras, estado, concorrência, sessão e contratos.
- [Catálogo mobile](mobile-feature-catalog.md#7-convenções-de-nomenclatura) — vocabulário e nomes já estabelecidos no produto.

## Histórico

| Versão | Data | Alteração |
|---|---|---|
| 1.0 | 2026-10-08 | Convenções iniciais de Swift/SwiftUI, Clean Architecture, concorrência, segurança, testes e revisão. |
