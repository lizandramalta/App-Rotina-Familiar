# Módulos de Domínio — Clean Architecture

Cada módulo neste diretório representa uma fronteira de negócio delimitada da aplicação, conforme especificado em `docs/architecture/backend-architecture.md` (Seção 4).

## Estrutura Interna Recomendada por Módulo

- `domain/`: Entidades puras, objetos de valor e regras invariantes.
- `application/`: Casos de uso (`use-cases/`), contratos e portas de saída (`ports/`).
- `presentation/`: Adaptadores de entrada (rotas Fastify, schemas JSON Schema/TypeBox).
- `infrastructure/`: Adaptadores de saída (repositórios PostgreSQL, mappers SQL).

## Módulos Mapeados

1. **`access`**: Sign in with Apple, convites, ingresso, recuperação restrita e gestão de sessões.
2. **`family`**: Família, papéis de membro, Criador, fuso horário e remoção.
3. **`profile`**: Perfil do titular, apelido, foto e consulta de conquistas.
4. **`tasks`**: Tarefas individuais (`FamilyTask`), atribuições, conclusão, correção e exclusão.
5. **`routines`**: Rotinas recorrentes, versões, horizontes de geração e exceções.
6. **`kids`**: Sinalização Kids, fila de revisão de Administradores e decisão.
7. **`missions`**: Missões coletivas, vínculos, encerramento, participações e marcos.
8. **`rewards`**: Catálogo predefinido/personalizado de recompensas e aceite único.
9. **`insights`**: Períodos, progresso pessoal/familiar e distribuição de carga.
10. **`reports`**: Snapshot semanal adulto para geração de PDF no cliente.
11. **`recognition`**: Ciclos semanais, apuração de pontuação e destaque semanal.
12. **`media`**: Upload de imagens, armazenamento privado R2 e limpeza de órfãos.
13. **`notifications`**: Registro de dispositivos APNs e fila outbox de push.
