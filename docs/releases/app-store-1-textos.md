# Mora — textos da App Store (1.0)

Metadados para cadastrar no App Store Connect, no idioma principal português (Brasil). Os limites de caracteres são os da Apple e foram conferidos. O registro da publicação está em [app-store-1.md](app-store-1.md).

## Informações do app

| Campo | Valor | Limite |
|---|---|---|
| Nome | `Mora` | 4/30 |
| Nome alternativo, se “Mora” estiver ocupado | `Mora: Rotina da Família` | 23/30 |
| Subtítulo | `Tarefas da casa em família` | 26/30 |
| Categoria principal | Estilo de vida | — |
| Categoria secundária | Produtividade | — |
| Copyright | `2026 Lizandra Malta` | — |

Não use a categoria Kids. Ela é para apps feitos para crianças usarem sozinhas e tem regras bem mais rígidas (sem links externos, como o compartilhamento pelo WhatsApp, e com controle parental para qualquer saída do app).

## Texto promocional

Pode ser trocado a qualquer momento, sem nova versão.

```
Divida as tarefas da casa com quem mora com você, veja a participação de cada um e comemore as conquistas juntos. As crianças também participam!
```

## Palavras-chave

Separadas por vírgula e sem espaços. Não repetem palavras do nome nem do subtítulo, que a Apple já indexa.

```
rotina,doméstica,divisão,filhos,crianças,afazeres,organização,lar,limpeza,missões,checklist,agenda
```

## Descrição

```
Em muitas casas, uma pessoa só lembra, distribui e cobra tudo. O Mora ajuda a família a dividir as responsabilidades domésticas de forma visível e colaborativa.

TAREFAS E ROTINAS
• Crie tarefas avulsas ou rotinas que se repetem todo dia ou a cada uma a quatro semanas.
• Defina o peso de esforço de cada tarefa, de 1 a 3.
• Escolha um, vários ou nenhum responsável.
• Marque como concluída e reabra quando precisar.

PARTICIPAÇÃO VISÍVEL
• Veja as tarefas e o progresso da família por dia ou por semana.
• Perceba quando a carga está concentrada em alguém e converse sobre equilíbrio.
• Um destaque semanal reconhece quem mais pontuou, e você pode mandar parabéns.

AS CRIANÇAS TAMBÉM PARTICIPAM
• O perfil Kids tem uma experiência simples, só com as tarefas da criança.
• A criança avisa quando terminou, com foto se quiser, e um adulto confirma.
• Ela acompanha missões, selos e o próprio destaque da semana.

CONQUISTAS EM CONJUNTO
• Missões reúnem tarefas em um objetivo da família, sem prazo e sem penalidade por demora.
• Ao concluir uma missão, a família gira a roleta de recompensas, como escolher o filme da noite ou o jantar.
• Selos marcam a participação de cada um ao longo do tempo.

UM LUGAR PARA CADA PESSOA
• Administrador: organiza a família, os membros, as missões e as recompensas.
• Membro: cria e conclui tarefas e acompanha a família.
• Kids: vê as próprias tarefas, avisa o que fez e acompanha as conquistas.
Quem cria a família entra com Iniciar sessão com a Apple e convida os outros por um link com senha.

PRIVACIDADE
Sem anúncios, sem rastreamento e sem venda de dados. Os perfis de crianças são criados por um adulto da família, e você pode excluir sua conta a qualquer momento pelo próprio app.

Para iPhone e iPad.
```

## URLs

Dependem da publicação do site (`site/`) no Cloudflare Pages com o projeto `mora-app`. Se esse nome não estiver disponível, ajuste o domínio.

| Campo | URL |
|---|---|
| URL de suporte (obrigatória) | `https://mora-app.pages.dev/suporte/` |
| URL de marketing (opcional) | `https://mora-app.pages.dev/` |
| Política de privacidade (obrigatória) | `https://mora-app.pages.dev/privacidade/` |

## Notas para a revisão

Enviar em inglês, no campo “Notes” das informações para a revisão. Antes do envio, troque os campos entre colchetes por um convite real de uma família de teste no backend de produção.

```
Mora is a family chore organizer. There is no demo account because the family creator signs in with Sign in with Apple: please tap "Sign in with Apple" with your own Apple ID to create a test family and explore the Administrator features (tasks, routines, members, missions and rewards).

To test the Member and Kids profiles, use these invitations to an existing test family. Open each link on the device; the app asks for the password:
- Kids profile: [INVITE LINK] — password: [PASSWORD]
- Member profile: [INVITE LINK] — password: [PASSWORD]

Account deletion: Profile > Account > Delete account. Deleting the creator's account deletes the whole family and revokes the Sign in with Apple token.

Photos are optional and only visible inside the family. The app has no ads, analytics SDKs or tracking.
```

## Classificação etária (sugestão)

Responda no App Store Connect conferindo cada pergunta. A sugestão parte do que o app faz hoje:

- **Conteúdo** (violência, sexualidade, linguagem, drogas, apostas, terror e similares): nenhum.
- **Conteúdo gerado por usuários e comunicação:** existe, mas fica restrito ao grupo privado da família. São títulos e observações de tarefas, fotos opcionais e parabéns com texto fixo. Não há chat livre, perfis públicos nem contato com desconhecidos. Responda conforme as perguntas do formulário, porque isso pode influenciar a faixa.
- **Navegação web irrestrita, compras e publicidade:** não.
- **Controles parentais e verificação de idade:** os perfis Kids são criados e administrados por um adulto da família.

## App Privacy (resumo para o questionário)

Coerente com a [política de privacidade](../../site/privacidade/index.html):

| Tipo de dado (Apple) | Coletado | Vinculado à pessoa | Usado para rastreamento | Finalidade |
|---|---|---|---|---|
| Nome | Sim | Sim | Não | Funcionalidade do app |
| Fotos | Sim (opcional) | Sim | Não | Funcionalidade do app |
| Outro conteúdo do usuário (tarefas, conclusões) | Sim | Sim | Não | Funcionalidade do app |
| ID de usuário (identificador da Apple do Criador) | Sim | Sim | Não | Funcionalidade do app |
| ID do dispositivo (token de push e instalação) | Sim | Sim | Não | Funcionalidade do app |

Não são coletados: e-mail, telefone, localização, contatos, dados financeiros, histórico de navegação ou de pesquisa, dados de uso para análise e dados de diagnóstico.
