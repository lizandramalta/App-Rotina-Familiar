# UX Spec 020: Apurar e compartilhar destaque semanal

**Status:** aprovada  
**Autor:** Codex | **Criada em:** 2026-10-10 | **Aprovada por:** Usuária | **Em:** 2026-10-10  
**Spec funcional vinculada:** [SPEC-020-destaque-semanal.md](SPEC-020-destaque-semanal.md)  
**Base funcional:** 1.17  
**Superfícies:** TEL-010, TEL-040, TEL-052, UF-15

## 1. Jornada

Pessoa reconhecida abre uma notificação ou o destaque disponível em Minhas tarefas e consulta TEL-052. A ausência de push não impede o acesso interno.

O acesso interno é o card “Você é destaque da semana!”, no dia de hoje de TEL-010 e TEL-040. Ele mostra o resultado mais recente enquanto durar a semana seguinte ao ciclo reconhecido: desde o início do novo ciclo até sete dias civis depois, no fuso do resultado. Abrir pela notificação sem sessão válida passa pela recuperação de acesso e revalida o resultado antes de exibi-lo.

## 2. TEL-052

- Cabeçalho com semana, pontos e tarefas realizadas. O título é “Fiquei em primeiro em pontos nesta semana!” ou, em empate, “Fiquei entre os primeiros em pontos nesta semana!”.
- Convite: “Mande para sua família e sugira algo para vocês fazerem juntos.”
- Mensagem sugerida editável e ações “Compartilhar no WhatsApp” e “Copiar mensagem”.
- Variante Kids mantém linguagem adequada e não mostra carga ou PDF familiar.
- Mensagem sugerida, editável, conforme UF-15: “Fiquei em primeiro em pontos nas tarefas desta semana! Que tal fazermos algo juntos para celebrar? Minha sugestão é: ____.” Em empate, começa com “Fiquei entre os primeiros em pontos…”. A variante Kids usa o mesmo texto.
- TEL-052 é tela empilhada: a barra de abas fica oculta.

## 3. Estados

| Estado | Comportamento |
|---|---|
| Carregando | Skeleton, sem resultado provisório |
| Conteúdo | Resultado final e ações opcionais |
| WhatsApp indisponível | Oferece copiar mensagem |
| Cancelado | Retorna ao resultado, sem afirmar envio |
| Sessão inválida | Direciona à recuperação e revalida antes de abrir |
| Erro | Mantém conteúdo confirmado ou permite tentar novamente |
| Mensagem vazia | “Compartilhar no WhatsApp” e “Copiar mensagem” ficam desabilitados até haver texto |
| Copiado | Exibe “Mensagem copiada” e anuncia no VoiceOver; não afirma envio |

## 4. Microcopy

| Chave | Texto pt-BR |
|---|---|
| `recognition.title` | Meu destaque semanal |
| `recognition.tie` | Fiquei entre os primeiros em pontos nesta semana! |
| `recognition.invite` | Mande para sua família e sugira algo para vocês fazerem juntos. |
| `recognition.share` | Compartilhar no WhatsApp |
| `recognition.copy` | Copiar mensagem |
| `recognition.error` | Não foi possível abrir seu destaque agora. |
| `recognition.first` | Fiquei em primeiro em pontos nesta semana! |
| `recognition.message.first` | Fiquei em primeiro em pontos nas tarefas desta semana! Que tal fazermos algo juntos para celebrar? Minha sugestão é: ____. |
| `recognition.message.tie` | Fiquei entre os primeiros em pontos nas tarefas desta semana! Que tal fazermos algo juntos para celebrar? Minha sugestão é: ____. |
| `recognition.period` | Semana de %1$@ a %2$@ |
| `recognition.points` / `recognition.tasks` | pontos / tarefas realizadas |
| `recognition.whatsapp_unavailable` | Não encontramos o WhatsApp neste aparelho. Copie a mensagem para enviar por outro app. |
| `recognition.retry` | Tentar novamente |
| `recognition.copied` | Mensagem copiada |
| `recognition.entry.title` | Você é destaque da semana! |
| `recognition.entry.subtitle` | Toque para ver e mandar para a família. |
| `recognition.notification` | Você é destaque da semana! Toque para ver e mandar para a família. |

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

## 7. Decisões e esclarecimentos de UX

| # | Decisão | Situação | Impacto |
|---|---|---|---|
| UX-01 | O card de entrada aparece no dia de hoje de TEL-010/TEL-040 durante a semana seguinte ao ciclo reconhecido (E-01 da SPEC-020). | Decidida pela pessoa usuária em 2026-11-08 | Apresentação; usa a lista própria existente. |
| UX-02 | O título sem empate e a mensagem sugerida seguem UF-15, e não os textos propostos no Figma; Kids usam o mesmo texto. | Decidida pela pessoa usuária em 2026-11-08 | Os textos do Figma 578:443 devem ser ajustados por UX. |
| UX-03 | O texto do push (`recognition.notification`) é o mesmo do card de entrada. | Decidida pela pessoa usuária em 2026-11-08 | Chave enviada pelo backend (SCRUM-102). |
| UX-04 | Copiar exibe e anuncia “Mensagem copiada”; mensagem vazia desabilita as ações. | Decidida pela pessoa usuária em 2026-11-08 | Apresentação. |
| UX-05 | TEL-052 oculta a barra de abas, conforme `screen-map.md` 1.24. | Decidida pela pessoa usuária em 2026-11-08 | O Figma 578:443 mostra a barra e deve ser ajustado por UX. |
| UX-06 | TEL-010 adulta reaproveita o card de TEL-040 (Figma 578:184), que não tem versão adulta desenhada. | Decidida pela pessoa usuária em 2026-11-08 | O quadro de TEL-010 deve receber o card. |

## 8. Checklist

- [x] Jornada, estados, microcopy e acessibilidade definidos.
- [x] Revisão e aprovação explícita junto da SPEC funcional em 2026-10-10.
- [x] Decisões UX-01 a UX-06 registradas em 2026-11-08 (SCRUM-103).
