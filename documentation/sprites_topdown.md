# Sprites top-down — Pablita e Pipop (protótipo v0.2)

## Pipeline
- Fonte de arte como código: `tools/pxl/pablita.px.js` e `tools/pxl/pipop.px.js` (ferramenta [claude-pxl](https://github.com/crsolver/claude-pxl), MIT, clonada fora do projeto; roda com `node <pxl>/bin/pxl.js build <arquivo> --out tools/pxl/out/<nome>`).
- PNGs finais: `assets/characters/{pablita,pipop}/topdown/walk_<dir>_<0..3>.png` (dir = south|north|east|west; oeste = espelho do leste).
- `tools/build_spriteframes.gd` (Godot headless) gera `resources/*_topdown_frames.tres` com `idle_<dir>` e `walk_<dir>`.
- Referências aprovadas (preservadas, nunca alteradas): `assets/_reference/sheet_pablita.jpg`, `sheet_pipop.jpg`.

## Convenções
- Escala-base: 1 m = ~18–19 px. Pablita (1,55 m): quadro 32x32, pivô nos pés = borda inferior da linha 29 → `offset = Vector2(-16, -30)`.
- Pipop: quadro 24x24, `offset = Vector2(-12, -23)`.
- Origem do nó = contato com o chão. Colisor só nos pés (10x6). Sombra = nó `Polygon2D` separado (não está no sprite).
- Camadas de colisão: 1 = jogador, 2 = sólidos do mundo (máscara da Pablita = 14), 4 = inimigos, 8 = interativos.

## Estado (protótipo, Etapas B–D da SPEC)
| Item | Estado |
|---|---|
| Idle 4 direções | quadro neutro estático (respiração/cabelo: pendente) |
| Andar 4 direções | 4 quadros (passo E, neutro, passo D, neutro) |
| 8 direções | diagonais usam o eixo dominante (sprites próprios: pendente) |
| Correr, agachar, combate com manopla, defesa, dano, interação, expressões, outros | **pendentes** (aguardam aprovação da perspectiva) |
| Pipop: grunhido e ondas sonoras (efeitos independentes) | **pendente** |
| Dash/ataques/dano no jogo | provisório: reutilizam a caminhada + tweens |

Fora do escopo por decisão: não há categoria de pulo.

## Decisões de design registradas
- Quarto de Pablita: entrada **sem retorno** até derrotar a Rainha Empoeirada.
- Chefes devem parecer gigantes em relação à Pablita (a definir por escala por chefe).
- Pipop é um único personagem (GDD v0.3).
- Conteúdo inventado na v0.1 removido (falas do Chopp, CD que curava, textos de derrota); ver marcações `PENDENTE` no código.
