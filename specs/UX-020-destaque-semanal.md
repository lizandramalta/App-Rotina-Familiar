# UX Spec 020: Apurar e compartilhar destaque semanal

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-020-destaque-semanal.md](SPEC-020-destaque-semanal.md)  
**Base funcional:** 1.17  
**Superfícies:** TEL-010, TEL-040, TEL-052, UF-15

## 1. Jornada

Pessoa reconhecida abre uma notificação ou o destaque disponível em Minhas tarefas e consulta TEL-052. A ausência de push não impede o acesso interno.

## 2. TEL-052

- Cabeçalho com semana, pontos e tarefas realizadas; empate usa “Fiquei entre os primeiros…”.
- Convite: “Mande para sua família e sugira algo para vocês fazerem juntos.”
- Mensagem sugerida editável e ações “Compartilhar no WhatsApp” e “Copiar mensagem”.
- Variante Kids mantém linguagem adequada e não mostra carga ou PDF familiar.

## 3. Estados

| Estado | Comportamento |
|---|---|
| Carregando | Skeleton, sem resultado provisório |
| Conteúdo | Resultado final e ações opcionais |
| WhatsApp indisponível | Oferece copiar mensagem |
| Cancelado | Retorna ao resultado, sem afirmar envio |
| Sessão inválida | Direciona à recuperação e revalida antes de abrir |
| Erro | Mantém conteúdo confirmado ou permite tentar novamente |

## 4. Microcopy

| Chave | Texto pt-BR |
|---|---|
| `recognition.title` | Meu destaque semanal |
| `recognition.tie` | Fiquei entre os primeiros em pontos nesta semana! |
| `recognition.invite` | Mande para sua família e sugira algo para vocês fazerem juntos. |
| `recognition.share` | Compartilhar no WhatsApp |
| `recognition.copy` | Copiar mensagem |
| `recognition.error` | Não foi possível abrir seu destaque agora. |

## 5. Acessibilidade

- Pontos, período, empate e tarefas são lidos em sequência; cor não indica mérito sozinha.
- Ações têm ao menos 44×44 pt, Dynamic Type e ordem de foco lógica.
- iPhone/iPad preservam informação e ações; Kids não recebem elementos de carga/PDF.

## 6. Critérios UX

| ID | Critério |
|---|---|
| UX-CA-01 | Resultado é compreensível sem push e sem ranking completo. |
| UX-CA-02 | Empate, sessão inválida e indisponibilidade têm estados explícitos. |
| UX-CA-03 | Compartilhamento é editável, opcional e não declara envio. |
| UX-CA-04 | Variante Kids não expõe dados familiares restritos. |

## 7. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Revisão e aprovação explícita junto da SPEC funcional em 2026-10-10.
