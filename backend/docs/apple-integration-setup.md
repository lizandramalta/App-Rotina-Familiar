# Configuração do Sign in with Apple no backend

**Situação:** guia operacional de setup
**Rastreabilidade:** BA-01, BA-04, [SPEC-001](../../specs/SPEC-001-autenticar-com-apple.md)

Este guia descreve como obter as credenciais da Apple, configurá-las com
segurança no backend e verificar a integração em desenvolvimento local. A
configuração é usada pela rota `POST /v1/access/apple` para trocar o
`authorizationCode` recebido do app por uma prova verificável pela Apple.

> O backend não aceita uma autenticação Apple apenas porque o simulador mostrou
> a conta conectada. Para cada tentativa ele precisa validar o `identityToken` e
> trocar o `authorizationCode` com a Apple; por isso as três credenciais de
> servidor abaixo também são necessárias ao testar localmente.

## 1. O que o backend precisa

| Variável            | Origem                   | Formato                     | Obrigatória        |
| ------------------- | ------------------------ | --------------------------- | ------------------ |
| `APPLE_CLIENT_ID`   | Bundle ID do app iOS     | identificador reverso       | sim (tem default)  |
| `APPLE_TEAM_ID`     | Membership details       | 10 caracteres alfanuméricos | em cada ambiente que fará login Apple |
| `APPLE_KEY_ID`      | Chave Sign in with Apple | 10 caracteres alfanuméricos | em cada ambiente que fará login Apple |
| `APPLE_PRIVATE_KEY` | Arquivo `.p8`            | PEM                         | em cada ambiente que fará login Apple |
| `APPLE_ISSUER`      | Apple                    | URL                         | sim (tem default)  |
| `APPLE_JWKS_URL`    | Apple                    | URL                         | sim (tem default)  |
| `APPLE_TOKEN_URL`   | Apple                    | URL                         | sim (tem default)  |

Em `development` e `test` o backend sobe sem `APPLE_TEAM_ID`, `APPLE_KEY_ID` e
`APPLE_PRIVATE_KEY`, para não bloquear quem não tem acesso à conta Apple
Developer. Quando informadas, o formato é validado em qualquer ambiente. Em
`production` a ausência ou o formato inválido derruba o boot imediatamente
(fail-fast), antes de a API aceitar tráfego.

Isso não torna o login Apple simulado: se uma chamada real chegar sem as três
credenciais, a troca do código não pode ser feita e a rota responde
`401 APPLE_PROOF_INVALID`. A resposta é intencionalmente genérica para não
revelar detalhes de segurança ao cliente. Para testar o fluxo de ponta a ponta
em `development`, preencha as três variáveis e reinicie a API.

A validação da chave privada não olha apenas os delimitadores `-----BEGIN/END-----`:
o backend pede ao Node para interpretar a chave, então um `.p8` truncado ou com
base64 corrompido é recusado no boot, e não na primeira tentativa de assinatura.

Em `production` a chave precisa ainda ser EC na curva **P-256** (`prime256v1`). O
client secret da Apple é assinado em ES256, que é definido como ECDSA com P-256 e
SHA-256 (RFC 7518 §3.4): uma chave RSA ou EC de outra curva (`secp384r1`,
`secp521r1`) geraria assinatura de tamanho incompatível com o `alg` declarado, e a
Apple recusaria toda troca de `authorizationCode`. As chaves `.p8` emitidas pelo
Apple Developer Portal já são P-256; a checagem existe para apontar no boot uma
chave trocada por engano, em vez de derrubar a autenticação em runtime.

`APPLE_ISSUER`, `APPLE_JWKS_URL` e `APPLE_TOKEN_URL` podem apontar para um stub em
`development` e `test`. Em `production` precisam ser exatamente os endpoints
canônicos definidos em `.env.example` — conferir a prova de identidade contra
outra origem invalidaria a autenticação.

## 2. Pré-requisitos para o teste local

- A conta da organização deve ter acesso ao Apple Developer Program e ao App ID
  configurado para o aplicativo.
- O `APPLE_CLIENT_ID` precisa ser o Bundle ID exato do app. A branch
  `release-testflight` usa `com.lizandramalta.mutua`; o valor de produção
  precisa ser atualizado antes do login com o novo build.
- A conta usada no simulador deve ser uma conta Apple comum que consiga iniciar
  sessão no dispositivo. **Sandbox Apple Accounts** são destinadas a testes de
  compras no App Store e não servem para entrar no simulador e testar Sign in
  with Apple.
- A API deve estar acessível no host configurado pelo app. Para o simulador iOS
  local, `http://127.0.0.1:3000/v1` funciona; em dispositivo físico, use o IP
  da máquina na rede local ou um ambiente HTTPS acessível pelo aparelho.

O `authorizationCode` fornecido pela Apple é de uso único e tem validade curta.
Depois de uma falha de rede ou de configuração, inicie uma nova tentativa pelo
botão da Apple; não há como reaproveitar o código anterior.

## 3. Obter o Team ID

1. Acesse o [Apple Developer Portal](https://developer.apple.com/account) com a
   conta da organização.
2. Abra **Membership details**.
3. Copie o **Team ID** (10 caracteres alfanuméricos) para `APPLE_TEAM_ID`.

## 4. Habilitar a capability no App ID

1. Em **Certificates, Identifiers & Profiles > Identifiers**, selecione o App ID
   do aplicativo (ou crie um do tipo _App IDs > App_).
2. Confirme que o **Bundle ID** é exatamente o valor usado em
   `APPLE_CLIENT_ID`. Ele é a audiência (`aud`) esperada no `identityToken`; uma
   divergência faz toda autenticação ser recusada.
3. Marque a capability **Sign in with Apple** e salve.

## 5. Criar a chave e baixar o arquivo `.p8`

1. Em **Certificates, Identifiers & Profiles > Keys**, crie uma nova chave.
2. Dê um nome que identifique o uso (por exemplo, `FamilyRoutine Sign in with Apple`).
3. Marque **Sign in with Apple**, associe ao App ID do passo anterior e
   confirme.
4. Copie o **Key ID** exibido para `APPLE_KEY_ID`.
5. Baixe o arquivo `AuthKey_<KEY_ID>.p8`.

> O download é **único**. A Apple não disponibiliza o arquivo novamente. Guarde-o
> em um gerenciador de segredos antes de sair da página. Se o arquivo for
> perdido, a única saída é revogar a chave e criar outra (seção 9).

## 6. Formatar a chave para o ambiente

O arquivo `.p8` é um PEM com quebras de linha reais:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----
```

Para que o `.env` seja portável, converta as quebras de linha do arquivo para
`\n` literal e mantenha o valor inteiro entre aspas. Não cole o caminho do
arquivo nem use as aspas tipográficas de um editor:

```bash
# Imprime o valor pronto para colar no .env
awk 'BEGIN { ORS="\\n" } { print }' AuthKey_ABC1234567.p8
```

Resultado no `.env`:

```dotenv
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49...\n-----END PRIVATE KEY-----"
```

O backend normaliza `\n` literal para quebras reais e remove aspas externas
antes de usar a chave, de modo que plataformas que injetam o PEM com quebras
reais também funcionam sem ajuste.

Nunca envie o `.p8` em chat, e-mail, ticket ou commit. O arquivo e seu conteúdo
devem permanecer fora do repositório; apenas os nomes das variáveis entram em
documentação e logs.

## 7. Configurar e verificar localmente

1. Crie `backend/.env` a partir de `backend/.env.example`, se ele ainda não
   existir.
2. Preencha `APPLE_TEAM_ID`, `APPLE_KEY_ID` e `APPLE_PRIVATE_KEY` conforme as
   seções anteriores. Mantenha os endpoints `APPLE_*` canônicos da Apple.
3. Inicie ou **reinicie** o processo da API. O dotenv é lido somente no boot;
   editar o `.env` não atualiza um `npm run dev` que já está em execução.

```bash
cd backend
npm run dev
```

Em outro terminal, confirme primeiro que o processo e o banco estão prontos:

```bash
curl -fsS http://127.0.0.1:3000/health/live
curl -fsS http://127.0.0.1:3000/health/ready
```

As duas requisições devem responder `200`. A primeira confirma que o processo
está vivo; a segunda também confirma o acesso ao banco. Se o app registrar
`connection refused` para `127.0.0.1:3000`, a API não está escutando nessa porta
ou o `API_BASE_URL` do app está apontando para o lugar errado.

Para checar se as credenciais foram preenchidas sem exibir nenhum valor secreto:

```bash
awk -F= '/^APPLE_(TEAM_ID|KEY_ID|PRIVATE_KEY)=/ { print $1 "=" ($2 == "" ? "vazia" : "definida") }' .env
```

O boot falha com mensagem indicando a variável e o problema quando algo está
inválido. As mensagens de erro nunca incluem o valor da chave, nem o detalhe da
exceção criptográfica. Em `development`, credenciais ausentes não impedem o
boot, mas impedem a confirmação de uma tentativa real de Sign in with Apple.

Para conferir o comportamento estrito de produção sem publicar nada, rode a
suíte unitária, que cobre os cenários de `development`, `test` e `production`:

```bash
npm run test
```

## 8. Diagnóstico de uma falha no app

| Sintoma | Causa provável | Próxima ação segura |
| --- | --- | --- |
| O app informa que não foi possível confirmar a conta Apple, e a API responde `401 APPLE_PROOF_INVALID` | Prova inválida, código expirado/reutilizado ou credenciais do backend ausentes/incorretas | Confirme as três variáveis sem imprimir seus valores, reinicie a API e execute um novo fluxo Apple. |
| `connection refused` para `127.0.0.1:3000` | A API não iniciou, está em outra porta ou a URL do app está incorreta | Rode as sondas da seção 7 e confira `API_BASE_URL` em `mobile/Configuration/Development.xcconfig`. |
| O boot falha citando `APPLE_PRIVATE_KEY` | PEM malformado, chave truncada ou chave de tipo/curva incorreta | Refaça a conversão do `.p8` da seção 6. Não gere uma chave substituta manualmente. |
| A conta não entra no simulador | Foi usada uma Sandbox Apple Account ou há uma etapa de segurança da Apple pendente | Use uma conta Apple comum e conclua a etapa diretamente no simulador. Não registre senhas ou códigos de verificação em logs. |

O cliente recebe deliberadamente uma mensagem genérica para qualquer falha de
prova Apple. A causa detalhada deve ser investigada no ambiente local e nos
logs protegidos do servidor, sem registrar token, código de autorização, nonce
ou chave privada.

## 9. Rotação e revogação de credenciais

A chave privada da Apple não expira, mas deve ser rotacionada quando houver
suspeita de exposição, saída de pessoa com acesso ou política interna de prazo.

1. Crie uma **nova** chave seguindo a seção 5, sem revogar a atual. Use sempre a
   chave `.p8` gerada pela Apple, que é EC P-256; não substitua por chave própria
   de outro tipo ou curva, porque o boot em produção a recusa.
2. Atualize `APPLE_KEY_ID` e `APPLE_PRIVATE_KEY` no gerenciador de segredos de
   cada ambiente e reinicie os processos.
3. Confirme que a autenticação funciona com a nova chave.
4. Só então revogue a chave antiga em **Keys > (chave) > Revoke**.

Revogar antes de confirmar a nova chave interrompe o login de todos os usuários.

## 10. Regras de segurança

- Nunca versione o arquivo `.p8`, o PEM ou qualquer credencial real. `.env.example`
  usa apenas placeholders.
- Credenciais vêm do ambiente ou de um gerenciador de segredos, nunca do código.
- `identityToken`, `authorizationCode`, `rawNonce`, o client secret assinado e a
  chave privada são sanitizados como `[REDACTED]` pelo logger estruturado e não
  aparecem em logs, telemetria ou mensagens de erro (RNF08, RNF16).
- Em caso de exposição confirmada, trate como incidente: rotacione a chave
  (seção 9) e revogue a anterior imediatamente após a troca.

## Referências

- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Generate and validate tokens](https://developer.apple.com/documentation/signinwithapplerestapi/generate_and_validate_tokens)
- [Fetch Apple's public key](https://developer.apple.com/documentation/signinwithapplerestapi/fetch_apple_s_public_key_for_verifying_token_signature)
