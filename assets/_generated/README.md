# `assets/_generated/` — Área de Staging de Imagens Geradas

Esta pasta recebe, valida e prepara imagens geradas fora de APIs pagas (ex.: geração manual via Gemini Web / Google AI Pro, ChatGPT Free, subagente `image-generator` do Antigravity ou `pxl-pixel-art`) antes de entrarem no projeto Godot.

O arquivo `.gdignore` garante que o Godot Editor **não importe** rascunhos, prompts ou imagens reprovadas.

## Estrutura
- `briefs/` — Briefings técnicos JSON sincronizados com o banco SQLite do **DFM Team MCP** (`C:\Users\dann1\.dfm-team\team.sqlite3`).
- `prompts/` — Prompts prontos (Positivo, Negativo, grade e referência) para geração manual ou via subagente.
- `inbox/` — Pasta monitorada onde os PNGs (ou JPEGs com fundo `#FF00FF` para conversão automática) devem ser salvos.
- `validated/` — PNGs aprovados na validação técnica (formato PNG, dimensões, transparência RGBA, contagem de cores) + relatórios `.report.json` com `data_url` pronto para o **Pixel Art MCP (`pixellab`)**.
- `rejected/` — Arquivos reprovados na validação com `.error.json` detalhando o motivo.

## Comandos Principais
Consulte `documentation/art_generation_workflow.md` ou execute `node tools/art_pipeline/dfm_art_pipeline.mjs --help`.
