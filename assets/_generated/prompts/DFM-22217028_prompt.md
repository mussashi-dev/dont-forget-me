# Prompt de Geração — Chave Esquecida (Objeto de Memória)

- **Task ID (DFM Team MCP):** `DFM-22217028`
- **Asset Name:** `forgotten_key`
- **Categoria:** `objects`
- **Dimensões Alvo:** `32x32` px (PNG 32-bit RGBA, transparência rígida)
- **Alinhamento no Quadro:** `center`
- **Destino Godot (após aprovação):** `assets/objects/forgotten_key.png`

## Referências Visuais Consultadas
- `assets/_reference/sheet_pablita.jpg`
- `assets/_reference/sheet_pipop.jpg`
- **Convenções:** `documentation/sprites_topdown.md` (escala `1m ≈ 18–19 px`, filtro `Nearest`, sem sombra acoplada ao sprite)

## Prompt Positivo (Copiar para Gemini Web / Google AI Pro / Antigravity `image-generator` / ChatGPT Free)
```text
Top-down 2D pixel art game sprite for the indie game DON'T FORGET ME: Pequena chave antiga de latão oxidado com fita lilás desbotada, estilo pixel art top-down 32x32. Exact target sprite grid 32x32 pixels (16-bit cozy-melancholic dark fantasy pixel art, crisp 1px dark outline #120b1c, hue-shifted shading). Style aligned with Pablita and Pipop sheets (soft handmade toy/memory aesthetic, muted lilacs/purples/warm brass accents from palette #120b1c, #2b1b45, #3f2a63, #5a3d86, #7d5aa8, #4a3a6e, #6b5896, #8f7bb8, #b9a6d9, #4a1f4d, #6d2b6b, #8f3a8a). Centered single asset on a pure solid flat magenta (#FF00FF) background with NO floor cast shadow, NO anti-aliasing, NO text, NO borders.
```

## Prompt Negativo / Restrições
```text
blurry, anti-aliased edges, soft gradients, drop shadow on floor, ground shadow, multiple sprites, sprite sheet grid labels, text, watermark, UI frame, 3D render, realistic photo, high-frequency noise.
```

## Alternativa 100% Gratuita e Determinística (`pxl-pixel-art`)
Caso prefira gerar diretamente na grade exata `32x32` sem pós-processamento:
1. Crie `tools/pxl/forgotten_key.px.js` usando a skill `pxl-pixel-art`.
2. Execute: `node "C:\Users\dann1\.gemini\config\skills\pxl-pixel-art\bin\pxl.js" build tools/pxl/forgotten_key.px.js --out tools/pxl/out/forgotten_key`
3. Copie o PNG gerado para `assets/_generated/inbox/forgotten_key.png`.

## Recebimento e Validação Automática
- Salve a imagem gerada (PNG transparente ou JPEG com fundo `#FF00FF`) em:
  `assets/_generated/inbox/forgotten_key.png` (ou `.jpg` com `--auto-convert`).
- Execute a validação:
  `node tools/art_pipeline/dfm_art_pipeline.mjs intake --file assets/_generated/inbox/forgotten_key.png --task-id DFM-22217028`
- Se vier do Gemini Web / `image-generator` em alta resolução com fundo `#FF00FF`:
  `node tools/art_pipeline/dfm_art_pipeline.mjs intake --file <caminho_da_imagem> --asset-name forgotten_key --task-id DFM-22217028 --auto-convert`
