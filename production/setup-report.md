# Project Setup Report: DON'T FORGET ME
**Date:** 2026-11-14   **State:** In progress (State 3)
**Engine:** Godot 4.7.2 (Mobile renderer)   **Phase:** prototype   **Goal:** commercial / mobile & desktop

## Wiring
| Item | Status | Notes |
|---|---|---|
| `.gameforge/project.json` | created | `name: "DON'T FORGET ME"`, `engine: "godot"`, `engine_version: "4.7"`, `phase: "prototype"` |
| `production/session-state/active.md` | created | Estado inicial de sessão registrado (ignorado pelo git) |
| `.gitignore` (state dirs) | merged | Adicionados `production/session-state/` e `production/session-logs/` preservando todas as linhas existentes |
| `.agents/rules/GAMEFORGE.md` | created | Regra sempre ativa no Antigravity para todas as conversas do workspace |
| `AGENTS.md` & `.agents/rules/AGENTS.md` | merged | Adicionada seção `## GameForge Integration (Always Active)` sem remover regras existentes |
| `CLAUDE.md` | created | Criado com seção `## Run and check` e bloco `gameforge:start/end` |
| Git | existing (`main`, commits existentes) | Repositório Git ativo; Git LFS 3.7.1 instalado no ambiente |
| Check command | `godot --headless --path . -s res://tests/test_vertical_slice.gd` | Documentado em `CLAUDE.md`, `README.md` e `.agents/rules/GAMEFORGE.md` |

## What exists
- Projeto Godot 4.7.2 estruturado (`project.godot`, `autoload/game_manager.gd`, `scenes/`, `scripts/`, `resources/`, `assets/`, `tests/`, `tools/`).
- Campanhas e níveis (`level_01_intro.tscn` a `level_10_boss_queen.tscn`), personagens (`pablita`, `pipop_companion`, `chopp_npc`), inimigos e chefes (`sock_enemy`, `boss_sock`, `boss_robot`, `boss_queen`).
- Pipeline de sprites top-down via `claude-pxl` (`tools/pxl/`) e `tools/build_spriteframes.gd`, documentado em `documentation/sprites_topdown.md`.
- Fluxo de revisão e auditoria documentado em `documentation/chatgpt_review_workflow.md`.
- Suíte de validação headless em `tests/test_vertical_slice.gd`.

## Gaps
| Item | Severity | Recommended action |
|---|---|---|
| GDD e documentos de design ainda não centralizados em `design/` | Important | Consolidar especificações e pilares em `design/` usando `game-gdd-author` ou `game-design-review` |
| Animações pendentes (corrida, combate com manopla, ondas sonoras do Pipop — Etapas B–D da SPEC) | Important | Usar `game-art-director` + `pxl-pixel-art` / `pixel-art` para concluir os quadros top-down |
| Textos e diálogos marcados como `PENDENTE` no código após remoção de conteúdo provisório da v0.1 | Nice-to-have | Usar `game-narrative-director` alinhado ao GDD v0.3 |

## Next three steps
1. **Consolidar GDD / Design (`game-gdd-author` / `game-design-review`):** Documentar formalmente o GDD v0.3 e tabelas de encartes em `design/`.
2. **Completar Pipeline Visual Top-Down (`game-art-director`):** Avançar nas animações pendentes da Pablita e do Pipop conforme `documentation/sprites_topdown.md`.
3. **Auditoria de Código e Testes (`game-code-review` / `game-qa-lead`):** Revisar os scripts de níveis e chefes garantindo cobertura no runner headless `tests/test_vertical_slice.gd`.
