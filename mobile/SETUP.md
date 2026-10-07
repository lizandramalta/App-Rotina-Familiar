# Configuração do mobile

O aplicativo fica em `mobile/` e usa SwiftUI para iOS/iPadOS 26 ou posterior.
O passo a passo completo de onboarding do repositório está no
[README principal](../README.md#como-executar-localmente-onboarding-rápido);
este documento detalha a parte mobile.

## Pré-requisitos

- Xcode 26 ou superior, com o simulador iOS correspondente ao target 26.0.
- Xcode completo selecionado para as ferramentas de linha de comando
  (`sudo xcode-select -s /Applications/Xcode.app`).

## Primeiro uso

1. Crie os arquivos locais de ambiente a partir dos templates:

   ```sh
   cp Configuration/Development.xcconfig.example Configuration/Development.xcconfig
   cp Configuration/Production.xcconfig.example Configuration/Production.xcconfig
   ```

2. Preencha `API_BASE_URL` com o endpoint apropriado ao ambiente. Com o backend rodando
   localmente conforme o README, use `http://localhost:3000/v1` no simulador — em
   dispositivo físico, troque `localhost` pelo IP da máquina na mesma rede. Esses arquivos
   são ignorados pelo Git; não inclua segredos, pois o app não armazena credenciais de
   infraestrutura.
3. Abra `mobile.xcodeproj` no Xcode, escolha o scheme `FamilyRoutine` e um simulador iOS/iPadOS 26.
4. Execute o aplicativo ou os testes pelo Xcode.

## Linha de comando

Compilar para simulador, sem exigir assinatura de código (igual ao que a CI faz):

```sh
xcodebuild build \
  -project mobile.xcodeproj \
  -scheme FamilyRoutine \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Rodar os `FoundationTests` em um simulador concreto:

```sh
xcrun simctl list devices available        # veja os simuladores instalados
xcodebuild test \
  -project mobile.xcodeproj \
  -scheme FamilyRoutine \
  -destination 'platform=iOS Simulator,name=<simulador instalado>'
```

O nome do simulador varia por máquina e por versão do Xcode, por isso a CI resolve o UDID
do primeiro iPhone disponível em vez de fixar um modelo.

## Limites da fundação

As abas e destinos atuais são placeholders neutros. Não representam telas de produto, sessão,
autorização, perfis ou a navegação Kids; essas responsabilidades serão introduzidas pelos cards
vinculados às SPECs aprovadas.
