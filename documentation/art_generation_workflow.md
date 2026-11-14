# DON'T FORGET ME — Fluxo Gratuito de Geração e Recebimento de Imagens

Este documento registra a investigação técnica realizada neste ambiente e define o fluxo oficial **custo zero** para o departamento de geração de imagens de **DON'T FORGET ME**.

---

## 1. Diagnóstico Técnico Comprovado (Ambiente Local)

1. **Gemini CLI (`@google/gemini-cli` v0.68.0):**
   - `gemini --list-models` expõe apenas modelos de texto (`auto`, `gemini-2.5-pro`, `gemini-3.5-flash`, `gemini-3.1-flash-lite`); **não possui modelo Imagen nem comando/ferramenta nativa de geração de imagens via CLI**.
   - `gemini --list-extensions` com a conta individual falha com:
     `IneligibleTierError: This client is no longer supported for Gemini Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity suite of products: https://antigravity.google`
2. **Assinatura Google AI Pro vs. Gemini API:**
   - A assinatura **Google AI Pro** (conta de consumidor) **não** concede créditos gratuitos na Gemini API / Vertex AI (`GEMINI_API_KEY` faturada).
   - Endpoints de geração de imagens da Gemini API exigem faturamento de API e, portanto, **não devem ser usados**.
3. **Antigravity CLI (`agy`) e Sessão Antigravity (`image-generator`):**
   - `agy` não está instalado no `PATH` neste sistema.
   - Dentro do **Antigravity**, o subagente nativo `image-generator` (`generate_image`) opera sob a sessão Google AI Pro sem cobrança adicional de API, porém gera **JPEG em alta resolução no diretório de artefatos**, **sem canal alfa** e **sem grade pixel-perfect nativa** (`16x16`, `24x24`, `32x32`).
   - Conclusão: o `image-generator` do Antigravity (ou geração manual gratuita no Gemini Web / Google AI Pro / ChatGPT Free) serve como gerador de base visual em fundo sólido magenta (`#FF00FF`), exigindo conversão/recorte/validação antes de entrar no Godot.
4. **Pixel Art MCP (`pixellab`) e `pxl-pixel-art`:**
   - `pixellab:get_balance` mostra plano `trial` com `credits: $0.00` e `generations_remaining: 20/40` (`generations_today: 10`, bônus diário recarregável).
   - `pixellab:pixelart_workbench` (`score`, `lint`, `repair`, `inspect`) foi testado com **custo zero de gerações e créditos** (saldo permaneceu `20/40` e `$0.00`).
   - A skill local `pxl-pixel-art` (`C:\Users\dann1\.gemini\config\skills\pxl-pixel-art\bin\pxl.js`, Node.js `v24.11.1`) permite geração 100% determinística por código sem custo nem pós-processamento (como já feito em `tools/pxl/`).
5. **DFM Team MCP:**
   - Os arquivos do servidor Python (`tools/dfm_team_mcp/server.py`) residem na branch `origin/feature/dfm-team-mcp` (não mesclada em `art-assets`), e o Python local não está instalado.
   - O script `tools/art_pipeline/dfm_art_pipeline.mjs` usa o módulo nativo `node:sqlite` do Node.js `v24.11.1` para ler e atualizar diretamente o mesmo banco SQLite `C:\Users\dann1\.dfm-team\team.sqlite3` (`DFM_TEAM_DATA`) com esquema idêntico ao do DFM Team MCP.

---

## 2. Arquitetura do Fluxo Implementado

```text
[DFM Team MCP SQLite] ──(1. brief)──> [assets/_generated/briefs/<id>.json + prompts/<id>_prompt.md]
                                                      │
                  (2. Geração Manual: Gemini Web / Antigravity image-generator / pxl)
                                                      │
                                                      ▼
[assets/_generated/inbox/] ──(3. intake / watch)──> [Validação PNG + Dimensões + RGBA]
                                                      ├── Reprovado ──> assets/_generated/rejected/
                                                      └── Aprovado  ──> assets/_generated/validated/
                                                                              │
                                            (4. pixellab:pixelart_workbench: score/lint/repair)
                                                                              │
                                                                              ▼
[assets/<categoria>/<asset>.png] <──(5. integrate --approve)── [Aprovação Explícita + Godot Check]
```

### Estrutura de Pastas
- `assets/_generated/.gdignore`: impede que o Godot importe rascunhos, prompts ou arquivos rejeitados.
- `assets/_generated/briefs/`: briefings JSON vinculados às tarefas `DFM-*` e às referências em `assets/_reference/` e `documentation/sprites_topdown.md`.
- `assets/_generated/prompts/`: arquivos Markdown com Prompt Positivo, Prompt Negativo, paleta do Esquecido e alternativa determinística em `pxl`.
- `assets/_generated/inbox/`: diretório monitorado (`watch`) para receber PNGs ou JPEGs com fundo `#FF00FF`.
- `assets/_generated/validated/`: PNGs aprovados na validação técnica + `.report.json` contendo `data_url` pronto para o **Pixel Art MCP**.
- `assets/_generated/rejected/`: arquivos reprovados + `.error.json` com os erros exatos.

---

## 3. Como Usar Passo a Passo

### Passo 1 — Criar ou puxar briefing do DFM Team MCP
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs brief `
  --department art `
  --title "Chave Esquecida (Objeto de Memória)" `
  --asset-name "forgotten_key" `
  --category "objects" `
  --width 32 `
  --height 32 `
  --target-path "assets/objects/forgotten_key.png" `
  --description "Pequena chave antiga de latão oxidado com fita lilás desbotada, estilo pixel art top-down 32x32"
```
Para puxar uma tarefa já existente do quadro `art`:
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs brief --pull-next --asset-name "nome_do_asset" --width 32 --height 32
```

### Passo 2 — Gerar a imagem gratuitamente
Use o arquivo `assets/_generated/prompts/<TASK_ID>_prompt.md` em uma das opções sem cobrança de API:
1. **Gemini Web (Google AI Pro)** ou **ChatGPT Free** (upload manual do PNG/JPEG para `assets/_generated/inbox/<asset_name>.png` ou `.jpg`).
2. **Subagente `image-generator` do Antigravity** (gera JPEG em fundo `#FF00FF` dentro da sessão).
3. **`pxl-pixel-art` local** (grade exata sem conversão):
   ```powershell
   node "C:\Users\dann1\.gemini\config\skills\pxl-pixel-art\bin\pxl.js" build tools/pxl/<asset_name>.px.js --out tools/pxl/out/<asset_name>
   ```

### Passo 3 — Receber e validar em `assets/_generated/`
Para validar um PNG pronto salvo em `assets/_generated/inbox/`:
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs intake --file assets/_generated/inbox/forgotten_key.png --task-id DFM-22217028
```
Para monitorar continuamente `assets/_generated/inbox/`:
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs watch --interval-ms 1500
```
Se a imagem gerada vier em JPEG ou alta resolução sobre fundo sólido `#FF00FF`, use `--auto-convert` (remove chroma-key e reduz com `tools/art_pipeline/image_processor.ps1` antes de validar):
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs intake `
  --file "<caminho_da_imagem>" `
  --asset-name forgotten_key `
  --task-id DFM-22217028 `
  --auto-convert
```

### Passo 4 — Revisar no Pixel Art MCP (`pixellab`)
1. Leia `pixel_art_mcp.data_url` em `assets/_generated/validated/<asset_name>.report.json`.
2. Envie ao servidor MCP `pixellab` -> `pixelart_workbench` (gratuito):
   - `argv: ["score", "<data_url>"]`
   - `argv: ["lint", "<data_url>"]`
   - Opcional: `argv: ["repair", "<data_url>"]` para limpeza determinística sem gastar gerações.
3. Registre o parecer no pipeline:
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs record-mcp-review `
  --asset-name forgotten_key `
  --status passed `
  --score 61.2 `
  --summary "pixellab:pixelart_workbench aprovado"
```

### Passo 5 — Integrar ao Godot após aprovação explícita
Por segurança (`AGENTS.md`), nenhuma integração acontece automaticamente e arquivos existentes nunca são sobrescritos:
```powershell
node tools/art_pipeline/dfm_art_pipeline.mjs integrate `
  --asset-name forgotten_key `
  --target assets/objects/forgotten_key.png `
  --approve `
  --godot-check
```
O projeto `project.godot` já define `textures/canvas_textures/default_texture_filter=0` (`Nearest`) e snap pixel-perfect 2D.
