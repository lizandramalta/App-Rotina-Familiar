# Configuração do mobile

O aplicativo fica em `mobile/` e usa SwiftUI para iOS/iPadOS 26 ou posterior.

## Pré-requisitos

- Xcode com o simulador iOS correspondente ao target 26.0.
- Xcode selecionado para as ferramentas de linha de comando (`xcode-select`).

## Primeiro uso

1. Crie os arquivos locais de ambiente a partir dos templates:

   ```sh
   cp Configuration/Development.xcconfig.example Configuration/Development.xcconfig
   cp Configuration/Production.xcconfig.example Configuration/Production.xcconfig
   ```

2. Preencha `API_BASE_URL` com o endpoint apropriado ao ambiente. Esses arquivos são ignorados pelo Git; não inclua segredos, pois o app não armazena credenciais de infraestrutura.
3. Abra `mobile.xcodeproj` no Xcode, escolha o scheme `FamilyRoutine` e um simulador iOS/iPadOS 26.
4. Execute o aplicativo ou os testes pelo Xcode.

Pela linha de comando, após selecionar o Xcode completo, use:

```sh
xcodebuild test \
  -project mobile.xcodeproj \
  -scheme FamilyRoutine \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Limites da fundação

As abas e destinos atuais são placeholders neutros. Não representam telas de produto, sessão, autorização, perfis ou a navegação Kids; essas responsabilidades serão introduzidas pelos cards vinculados às SPECs aprovadas.
