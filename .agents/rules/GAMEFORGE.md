# GameForge Studio Workflow (Always Active)

Este projeto utiliza o **AlterLab GameForge** como fluxo oficial de produção, design e engenharia em todas as conversas.

## 1. Protocolo de Sessão (Obrigatório em Todas as Conversas)
- **Ao iniciar uma tarefa:** Leia `.gameforge/project.json` e `production/session-state/active.md` para alinhar fase atual (`phase`), pilares do jogo (`pillars`), decisões registradas e bloqueios antes de propor ou executar trabalho.
- **Ao concluir entregas ou decisões:** Atualize `production/session-state/active.md` (seções `Now`, `Decisions`, `Next`, `Blocked on`) com o progresso e os próximos passos.
- **Organização GameForge (overlay junto ao layout Godot):**
  - `design/` — GDD, pilares, conceito e dados de balanceamento.
  - `docs/` — Decisões de arquitetura (ADRs) e notas técnicas (além de `documentation/` já existente).
  - `production/` — Sprints (`sprints/`), marcos (`milestones/`), estado de sessão (`session-state/`, ignorado no git) e logs (`session-logs/`, ignorado no git).
  - `prototypes/` — Experimentos descartáveis (nunca promovidos diretamente para produção sem revisão).

## 2. Run and Check
- **Executar jogo:** `godot --path .` (ou cena específica: `godot --path . res://scenes/levels/level_01_intro.tscn`)
- **Verificar testes (headless):** `godot --headless --path . -s res://tests/test_vertical_slice.gd`
- **Arquivos protegidos:** Nunca edite `.godot/` nem arquivos `*.uid` manualmente; respeite integralmente a regra de **Code Safety** de `AGENTS.md` (não modificar `.gd`, `.tscn`, `.tres`, `.cfg`, `.godot` existentes sem autorização explícita).

## 3. Mapeamento Obrigatório de Skills do GameForge
Sempre que a solicitação do usuário entrar em um dos domínios abaixo, carregue (`read_file` no `SKILL.md` correspondente em `C:\Users\dann1\.gemini\config\skills\<skill>\SKILL.md`) antes de agir:

| Domínio / Necessidade | Skill GameForge |
|---|---|
| Engenharia Godot 4 / GDScript / Cenas / Física | `game-godot-specialist` |
| Arquitetura / Performance / Decisões Técnicas | `game-technical-director` |
| Mecânicas / Core Loop / Game Feel / Balanceamento | `game-designer`, `game-balance-check` |
| Visão Criativa / Pilares / Tom | `game-creative-director` |
| GDD / Especificações / Auditoria de Design | `game-gdd-author`, `game-design-review` |
| Direção de Arte / Sprites / Pipeline IA | `game-art-director`, `game-ai-assets` |
| Áudio / Música Adaptativa / SFX | `game-audio-director` |
| Narrativa / Diálogos / Lore | `game-narrative-director` |
| UI / HUD / Controles Mobile & Desktop / Acessibilidade | `game-ux-designer`, `game-accessibility-specialist` |
| QA / Testes / Code Review | `game-qa-lead`, `game-code-review` |
| Escopo / Produção / Protótipo / Build Loop | `game-producer`, `game-scope-check`, `game-prototype`, `game-vibe-code` |
| Dúvidas gerais de roteamento GameForge | `game-help` |
