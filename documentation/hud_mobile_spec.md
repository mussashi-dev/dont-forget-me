# Especificação de UI/UX — HUD Mobile (`DON'T FORGET ME`)

> **Responsável:** Mira Osei (`game-ux-designer`) & Sable Mori (`game-art-director`)  
> **Resolução Base:** `640×360` px (16:9), escala `canvas_items`, filtro `Nearest`

---

## 1. Objetivo e Hierarquia de Informação
Garantir leitura imediata de sobrevivência e sinergia entre **Pablita** e **Pipop** durante combates top-down em telas pequenas (Mobile Android), sem nunca cobrir o centro da arena (`x: 160..480, y: 80..280`) onde Pablita se move.

### Camadas de Informação (Tiers)
1. **Tier 1 (Sobrevivência e Capacidade — Canto Superior Esquerdo):**
   - Retrato do Pipop (`30×30` px) + Barra de Presença (`140×14` px).
   - **Barra de Capacidade Simples:** Linha compacta abaixo da barra de vida com slots quadrados de `14×14` px (`assets/ui/hud_slot_filled.png` em rosa com curativo cinza para slot ocupado; `assets/ui/hud_slot_empty.png` em roxo escuro para slot livre).
2. **Tier 2 (Ações de Combate — Canto Inferior Direito, Zona do Polegar):**
   - **Botão de Ataque Físico (`PhysicalAttackBtn`):** `64×64` px (`offset: -68..-4`), textura `assets/ui/hud_btn_physical_gauntlet.png` (ícone da **manopla felpuda rosa do Pipop** com o coração remendado).
   - **Botão de Ataque Sonoro (`SonicAttackBtn`):** `58×58` px (`offset: -136..-78`), textura `assets/ui/hud_btn_sonic_waves.png` (ícone das **ondas sonoras concêntricas em roxo/rosa**).
   - **Botão de Esquiva (`DashBtn`)** e **Interação (`InteractButton`):** Acima dos botões de ataque, mantendo espaçamento mínimo de `8` px para evitar toque acidental.
3. **Tier 3 (Navegação de Sistema — Canto Superior Direito):**
   - Botões `ENCARTES` e `PAUSA` na zona segura superior direita.

---

## 2. Regras de Acessibilidade e Feedback
- **Dupla Codificação (Cor + Forma/Ícone):** O botão físico combina a cor **rosa-choque** com a silhueta fechada de **punho/manopla**; o botão sonoro combina o **roxo profundo** com **três arcos concêntricos**.
- **Desobstrução da Pablita:** Nenhum elemento fixo do HUD invade o raio central de `140` px ao redor de Pablita.
- **Adaptação de Dispositivo:** Os controles de toque são ocultados automaticamente quando um modal (Diálogo, Encartes, Pausa) está aberto.
