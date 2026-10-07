# UX Spec 004: Gerar e reenviar convite

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-06 | **Aprovada por:** Pessoa usuária | **Em:** 2026-10-06  
**Spec funcional vinculada:** [SPEC-004-gerar-reenviar-convite.md](SPEC-004-gerar-reenviar-convite.md)  
**Base funcional:** 1.14\
**Superfícies de interface:** TEL-032, TEL-034, TEL-050, TEL-056, UF-01, UF-12

## 1. Objetivo da experiência e jornada

- **Visão da experiência:** um Administrador identifica um integrante no detalhe da família, entende o impacto da emissão e compartilha um único convite seguro. A confirmação evita revogar acesso existente sem perceber esse efeito.
- **Perfis atendidos:** Administrador da própria família. Membros podem consultar TEL-032 conforme UC11, mas não veem a ação. Kids não acessam a jornada. O Criador não é elegível e não recebe caminho para convite.

## 2. Rastreabilidade complementar

| Referência | Código / documento |
|---|---|
| Spec funcional vinculada | `SPEC-004-gerar-reenviar-convite.md` |
| Telas | TEL-032, TEL-034, TEL-050, TEL-056 |
| Fluxo | UF-01, UF-12 |
| Documentos de design | `docs/design/screen-map.md`, `docs/design/user-flows.md` |

As regras de domínio, autorização e contrato de dados são integralmente herdados da SPEC-004.

## 3. Escopo da experiência

- **Dentro:** acesso autorizado a TEL-034 a partir do detalhe ou do onboarding; confirmação dos efeitos; envio único para a folha de compartilhamento nativa; retorno para a origem preservando contexto; carregamento, falha, recurso inelegível e resultado incerto.
- **Fora:** formulário de criação/edição de membro, cópia de credenciais, seleção de canal próprio, mensagem automática, abertura e consumo do convite, troca de acesso e recuperação de ingresso.

## 4. Jornada, navegação e preservação de contexto

| Origem | Ação | Destino | Retorno / cancelamento | Contexto preservado |
|---|---|---|---|---|
| TEL-050 | Adulto seleciona integrante | TEL-032 | Voltar retorna à Família | Dia/semana e rolagem da Família |
| TEL-032 | Admin elegível toca em gerar ou reenviar convite | TEL-034 | Voltar/cancelar retorna ao detalhe | Membro, período e tarefas consultadas |
| TEL-056 | Criador escolhe gerar convite para membro recém-criado | TEL-034 | Voltar/cancelar retorna ao onboarding | Membro recém-criado e lista inicial permanecem |
| TEL-034 | Admin confirma a emissão | Folha de compartilhamento nativa | Cancelar a folha encerra o compartilhamento, sem desfazer a emissão | O app não conserva link ou senha; retorna ao detalhe |
| TEL-034 | Admin cancela antes de confirmar | TEL-032 | Nenhuma emissão ocorre | Membro e período preservados |
| TEL-034 | Emissão falha ou resultado é incerto | TEL-034 | Fechar retorna a TEL-032; nova emissão pede nova confirmação | Membro e contexto preservados; não há credencial exibida |

- A folha nativa recebe uma única mensagem localizável com link e senha juntos. Não há ação de copiar, campos de texto com segredo, histórico de compartilhamentos ou lista de apps implementada pelo aplicativo.
- Se a pessoa cancelar a folha depois de a emissão ser confirmada, a emissão já ocorreu e não é revertida. O app informa que, para compartilhar depois, será necessário gerar novo convite e confirma novamente os efeitos dessa nova emissão.

## 5. Superfícies e componentes

### 5.1. TEL-032 — Detalhe do membro

- **Objetivo:** apresentar o membro e suas tarefas no período, preservando a capacidade administrativa já determinada pelo backend.
- **Ação autorizada:** Administrador vê “Gerar convite” ou “Reenviar convite” apenas se a projeção confirmar que o perfil está ativo, pertence à família e é elegível. A nomenclatura acompanha se há convite/sessão anterior, sem expor credenciais ou estado confidencial.
- **Ações ocultas:** Membro, Kids, alvo Criador, alvo removido ou detalhe que perdeu a capacidade não mostram a entrada para TEL-034.

### 5.2. TEL-034 — Convite do membro

- **Objetivo:** obter confirmação consciente antes de emitir credenciais que revogam convites e sessão anteriores.
- **Anatomia:** botão Voltar; título; identificação não sensível do membro; aviso de efeitos; ação primária “Gerar convite” ou “Gerar novo convite”; ação secundária “Cancelar”.
- **Aviso obrigatório:** nova emissão cria link e senha novos, torna convites anteriores indisponíveis e encerra a sessão anterior do integrante. Não afirma que o convite foi compartilhado ou consumido.
- **Sucesso:** após confirmação do servidor, TEL-034 abre imediatamente a folha de compartilhamento nativa com o conteúdo conjunto. Ao fechá-la, volta a TEL-032 ou TEL-056, conforme a origem, e elimina as credenciais da memória da interface.
- **Sem controles alternativos:** não mostra o link/senha em campos, não oferece copiar, salvar, reenviar por aplicativo específico ou reabrir a folha com as mesmas credenciais.

## 6. Estados da interface

| Estado | Condição | O que a pessoa vê | Ações permitidas |
|---|---|---|---|
| `Content / Confirmation` | Perfil elegível e dados carregados | Aviso dos efeitos e ações Gerar/Cancelar | Confirmar ou voltar |
| `Submitting` | Confirmação enviada | Botão com progresso; controles bloqueados | Nenhuma, para evitar emissão duplicada |
| `Sharing` | Resposta confirmada | Folha de compartilhamento nativa do sistema com uma mensagem contendo link e senha | Escolher destino ou cancelar a folha |
| `Completed` | Folha fechada | Retorno a TEL-032 sem credenciais exibidas | Consultar detalhe; nova emissão inicia nova confirmação |
| `Error / Recoverable` | Recusa conhecida, como indisponibilidade antes da escrita | Mensagem contextual e ação para retornar ou iniciar novamente | Voltar; nova emissão só por confirmação completa |
| `Error / Uncertain` | Resposta perdida ou persistência incerta | Explica que não é possível confirmar a emissão e não mostra segredo | Voltar; emitir novo convite após confirmação explícita |
| `Unavailable` | Perfil se torna removido, Criador ou fora do escopo enquanto a tela está aberta | Mensagem de indisponibilidade e retorno ao detalhe atualizado | Voltar |

## 7. Interações, microcopy e localização

| Elemento | Chave i18n | Texto padrão pt-BR | Cenário |
|---|---|---|---|
| Título inicial | `memberInvite.issue.title` | "Gerar convite" | Perfil sem convite anterior conhecido |
| Título de reemissão | `memberInvite.reissue.title` | "Gerar novo convite" | Perfil com recuperação/reemissão disponível |
| Aviso de impacto | `memberInvite.confirm.effects` | "Um novo convite vai invalidar os anteriores e encerrar o acesso atual desta pessoa." | Antes da confirmação |
| Ação inicial | `memberInvite.issue.action` | "Gerar convite" | Estado de confirmação inicial |
| Ação de reemissão | `memberInvite.reissue.action` | "Gerar novo convite" | Estado de confirmação de reemissão |
| Ação secundária | `memberInvite.cancel.action` | "Cancelar" | Antes do envio |
| Enviando | `memberInvite.submitting` | "Gerando convite…" | Durante a chamada |
| Conteúdo compartilhado | `memberInvite.share.message` | "Convite para entrar na família\nLink: {{link}}\nSenha: {{password}}" | Único conteúdo enviado à folha nativa |
| Compartilhamento cancelado | `memberInvite.share.cancelled` | "O convite foi gerado, mas não foi compartilhado. Para compartilhar depois, gere um novo convite." | Fechamento/cancelamento da folha |
| Resultado incerto | `memberInvite.error.uncertain` | "Não foi possível confirmar a geração do convite. Não compartilhe dados; para tentar de novo, gere um novo convite." | Resposta perdida ou `503` incerto |
| Perfil indisponível | `memberInvite.error.unavailable` | "Este convite não pode mais ser gerado para este perfil." | `404` ou `409` |
| Sem permissão | `memberInvite.error.notAllowed` | "Você não tem permissão para gerar este convite." | `403` inesperado |

## 8. Acessibilidade e adaptação

- A ordem de foco em TEL-034 é: voltar, título, identificação do membro, aviso de impacto, ação principal e cancelar.
- O aviso de impacto é texto completo, não apenas cor ou ícone. O botão principal recebe dica: “Gera novas credenciais e encerra o acesso anterior desta pessoa”.
- A interface não lê link nem senha automaticamente pelo VoiceOver, pois as credenciais não são exibidas em uma view do app. A folha nativa é a única superfície que recebe esse conteúdo intencionalmente para compartilhamento.
- Dynamic Type deve permitir que o aviso e os botões cresçam verticalmente, sem truncar a consequência de revogação. Todos os controles têm área mínima de 44 × 44 pt e contraste WCAG AA, com ícone e texto em avisos.
- Em iPhone, TEL-034 usa apresentação de navegação compatível com a pilha atual; em iPad, mantém o contexto do detalhe em layout adaptativo. A folha de compartilhamento segue a apresentação nativa do sistema em cada dispositivo.

## 9. Decisões e esclarecimentos de UX

| # | Decisão | Origem | Altera a SPEC funcional ou docs/? |
|---|---|---|---|
| UX-01 | A entrega usa exclusivamente a folha de compartilhamento nativa; link e senha são uma única mensagem e não há cópia individual. | Pessoa usuária, 2026-10-06 | Não; registrada também como E-01 na SPEC-004 |
| UX-02 | Fechar a folha depois da emissão não reverte as credenciais e não as mantém para novo compartilhamento; nova emissão exige nova confirmação. | RN46, RF54 e ausência de recuperação de senha | Não |
| UX-03 | TEL-056 pode abrir TEL-034 após o cadastro de um membro, mas “Avançar” permanece disponível mesmo se a folha nativa for cancelada. | Pessoa usuária, 2026-10-07 | Não; aplica UC01/RF41. |

## 10. Checklist de aprovação

- [x] Vinculada à SPEC-004 em elaboração.
- [x] TEL-032, TEL-034, TEL-050 e UF-12 existem na base de design.
- [x] Entrada, confirmação, cancelamento, retorno e resultado incerto foram descritos.
- [x] Estados `Content`, `Submitting`, `Sharing`, `Completed`, `Error` e `Unavailable` foram definidos.
- [x] Microcopy e chaves de localização foram definidas.
- [x] Ações não autorizadas são ocultas.
- [x] VoiceOver, Dynamic Type, contraste, toque e iPad foram considerados.
- [x] Status autorizado explicitamente como `aprovada` pela pessoa usuária em 2026-10-06.
