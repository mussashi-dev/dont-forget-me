# 📘 BÍBLIA DE DIREÇÃO DE ARTE: DON'T FORGET ME

> **Estética Oficial:** *"Melancolia Aconchegante" (Cozy-Melancholy) em Pixel Art Top-Down*  
> **Status:** Style Lock Ativo (v1.1 — Seção 3.2 Pipop Corrigida Cirurgicamente)  
> **Autoridade Visual:** Sable Mori (`game-art-director`) & Pipeline `pxl-pixel-art`

---

## 1. Pilares Visuais e Identidade
*   **Aconchego vs. Melancolia:** O contraste entre o quarto quente (tons de laranja, madeira, rosa) e o Esquecido (roxos profundos, azuis frios, névoa, desgaste).
*   **Legibilidade Mobile:** Silhuetas fortes e contraste alto na resolução base **640×360** (`canvas_items`, filtro **Nearest**). A Pablita (cabelo ruivo volumoso) deve se destacar imediatamente do fundo roxo.
*   **Estilo:** Pixel Art Top-Down (Base 32×32 para personagens pequenos, paletas restritas de 16 a 32 cores por asset, contorno escuro `#2c1420` / `#4a1238`).

### 1.1 Paleta Oficial Validada (Style Lock)
| Domínio | Cores Chave (Hex) | Regra de Uso | Sinal Não-Cor (Acessibilidade) |
|---|---|---|---|
| **Quarto (Aconchego)** | `#f4b168` `#a6633c` `#d87a92` `#5a3628` | Luz acesa, piso de madeira, tapete rosa, segurança | Formas arredondadas, luz radial quente |
| **O Esquecido (Fases 1–3)** | `#3a2b4c` `#241934` `#6e528a` `#8c6d53` | Pedra roxa rachada, madeira puída, névoa fria | Rachaduras angulares, bordas fragmentadas |
| **Esquecido Profundo (4+)** | `#160f24` `#2d1b46` `#a448ff` `#5ce6ff` | Caverna de memórias, cristais e cogumelos neon | Brilho bioluminescente, silhuetas pontiagudas |
| **Pablita (Trava)** | `#9c3d26` `#732819` `#b8b4be` `#26232e` | Cabelo ruivo volumoso, blusa cinza-claro, shorts escuros | Silhueta de copa arredondada gigante |
| **Pipop (Trava)** | `#f668ba` `#c43a8e` `#e85088` `#ece0a0` `#8c8896` | Pelagem rosa-choque, olhos rosa/vermelhos, dentes, curativo cinza | Silhueta felpuda espetada + coração partido no peito |

---

## 2. Hierarquia de Escala (Regra de Ouro)
Para transmitir a sensação de vulnerabilidade de Pablita e o perigo do mundo, a escala visual (não hitbox) deve seguir rigidamente esta proporção (base 1 m ≈ 18–19 px):

| Categoria | Escala Relativa | Dimensão de Quadro (px) | Regra de Silhueta e Pivô |
|---|---|---|---|
| **Pablita** | **100%** (Referência) | `32×32` px | Silhueta dominada pelo cabelo cacheado; pivô nos pés `(0, 0)`, `offset = Vector2(-16, -30)` |
| **Pipop** | **30–40%** | `20×20` a `24×24` px | Pequeno companheiro Fuggler rosa; pivô nos pés, `offset = Vector2(-12, -23)` |
| **Chopp (O Rato)** | **20–25%** | `14×14` a `16×16` px | Rato pequeno e expressivo; cabe na cabeça/ombro de Pablita |
| **Mobs Comuns** | **50–100%** | `24×24` a `32×32` px | Silhuetas simples e ligeiramente grotescas de objetos esquecidos |
| **Chefe 1: A Meia Esquecida** | **300%** | `96×96` px | Massa rasteira elástica com raízes de fios roxos brilhantes |
| **Chefe 2: O Robô Esquecido** | **350%** | `112×112` px | Chassi quadrado/industrial dos anos 80, lâmpada quebrada e engrenagens |
| **Chefe 3: A Rainha Empoeirada** | **400%** | `128×128` px | Silhueta imponente flutuante, vestido de retalhos, coroa quebrada |

---

## 3. Personagens Principais (Trava de Estilo Absoluta)
> **PROIBIÇÃO ESTRITA:** É proibido qualquer desvio anatômico, troca de cores ou alteração de vestuário na Pablita e no Pipop. As pranchas `assets/_reference/sheet_pablita.jpg` e `assets/_reference/sheet_pipop.jpg` são a lei absoluta.

### 3.1 Pablita (Referências: Spritesheets)
*   **Grid Base:** 32×32 (Top-Down).
*   **Aparência Imutável (Não inventar modificações):**
    *   **Cabelo:** Ruivo/castanho-avermelhado, extremamente volumoso, cacheado, formando uma silhueta arredondada gigante.
    *   **Pele:** Parda.
    *   **Roupas:** Blusa oversized cinza-claro (manga longa), shorts escuros (quase pretos), tênis branco/cinza com detalhes escuros.
*   **Animações Obrigatórias:** Idle (4 direções), Caminhada (4 direções), Corrida (4 direções), Agachar, Levantar, Pular, Cobrir o rosto, Dormir, Acordar, Combate (socos com a mão esquerda onde Pipop se manifesta), Defesa, Hit/Dano, Expressões (Surpresa, Medo, Tristeza, Raiva, Alegria, Pensativa) e Interação (abraçando Pipop).

### 3.2 Pipop (Referências: Spritesheet de Pipop e Imagem 3D do Fuggler)
*   **Grid Base:** Top-Down (Escala menor que Pablita - 30–40%).
*   **Aparência Imutável (Não inventar modificações):**
    *   **Corpo:** Uma bola de pelo rosa-choque, felpudo e espetado.
    *   **Olhos:** Pálpebras caídas, olhos rosa/vermelhos com pupilas pequenas pretas, transmitindo um olhar cansado, bizarro e ligeiramente perturbador.
    *   **Boca:** Boca larga e aberta, equipada com dentes humanos/esquisitos (superiores e inferiores) e gengivas expostas.
    *   **Detalhe Frontal (Peito/Barriga):** Um grande coração rosa-choque com uma linha preta quebrada (rachadura) no meio, remendado com um curativo retangular cinza costurado.
*   **Animações Obrigatórias (Baseadas estritamente na Spritesheet):**
    *   **Movimento:** Idle (4 direções), Andar, Correr, Parado/Olhar, Agachar.
    *   **Defesa/Dano:** Defesa (encolhe-se), Dano/Impacto (olhos arregalados, faíscas e exclamações).
    *   **Manifestação Física:** Torna-se uma manopla/luva ao redor da mão de Pablita (usada nos socos).
    *   **Manifestação Sonora (Grunhido):** A boca se abre desproporcionalmente mostrando os dentes, e o coração no peito vibra. Ele emite ondas sonoras visuais (círculos concêntricos e arcos) em tons de roxo e rosa que avançam pela tela.
    *   **Interação e Extras:** Interação (`!`), Segurando caixa de papelão, Lendo livro, Dormindo (deitado com `"Zzz"`).
    *   **Expressões:** Amor (coração flutuante), Choque (`!!`), Raiva (linhas vermelhas), Dúvida (`?`).

### 3.3 Chopp (O Rato)
*   **Direção:** Rato pequeno (escala 20–25%, grid 16×16), usando farrapos ou itens encontrados no Esquecido (cachecol/capa puída em tom ocre/violeta). Expressivo e desconfiado. Deve caber na cabeça da Pablita ou ser carregado por ela. Segue a paleta de cores do Esquecido.

---

## 4. Design de Mobs (Criados a partir do GDD)
*Baseado na estética "melancolia aconchegante" (cozy-melancholy) em pixel art top-down, com formas simples, mas ligeiramente grotescas:*

*   **Mob 1: "O Tufo de Meias" (Objeto/Bestial — Escala 60–75%, 24×24):** Bola emaranhada de meias velhas, fios soltos que agem como tentáculos curtos. Sem olhos, apenas um buraco escuro. Arremessa bolas de poeira e enrosca nos pés.
*   **Mob 2: "O Brinquedo de Corda" (Objeto — Escala 65–80%, 24×24):** Coelho de plástico antigo desbotado, sem uma orelha, com chave de corda metálica nas costas. Avança de forma errática (quicando) causando dano de impacto.
*   **Mob 3: "Flor de Poeira" (Floral — Escala 75–90%, 28×28):** Planta carnívora murcha, feita de sacolas plásticas velhas e arame. Cospe esporos e morde se Pablita chegar perto.
*   **Mob 4: "O Boneco Desfiado" (Humanoide — Escala 100%, 32×32):** Boneco de pano do tamanho de Pablita, um braço faltando, algodão saindo pelas costuras. Segura uma agulha gigante enferrujada. Dá estocadas e costura Pablita no chão.

---

## 5. Design dos Chefes (Bosses - Escala 250–400%)

### 5.1 Chefe 1: A Meia Esquecida (Fase 3)
*   **Escala:** 300% do tamanho de Pablita (`96×96` px).
*   **Direção de Arte:** Meia cinza/bege gigante e puída. Furos irregulares (vazio escuro), remendos de linhas coloridas e fios longos como raízes. Move-se de forma rasteira e elástica. Fios brilham em roxo (perigo).
*   **Ataques:** Lança fios para prender, cria "teias" de costura no chão, estica o corpo como chicote.

### 5.2 Chefe 2: O Robô Esquecido (Fase 7)
*   **Escala:** 350% do tamanho de Pablita (`112×112` px).
*   **Direção de Arte:** Robô de lata dos anos 80. Pintura azul descascada e ferrugem. Olhos de lâmpada (um quebrado). Antena torta. Emite ondas sonoras visuais e faíscas. Engrenagens expostas no peito.
*   **Ataques:** Bate no chão (ondas de choque), emite pulsos sonoros que empurram Pablita, dispara peças soltas como projéteis.

### 5.3 Chefe 3: A Rainha Empoeirada (Fase 10 - Final)
*   **Escala:** 400% do tamanho de Pablita (`128×128` px).
*   **Direção de Arte:** Boneca de moda (estilo Barbie) gigante e aterrorizante. Vestido de retalhos em decomposição, cheio de teias. Maquiagem borrada/escorrida. Cabelo embaraçado com pedaços de outras bonecas. Flutua levemente. Costuras brilhantes pelo corpo e coroa de plástico quebrado.
*   **Ataques:** Usa o vestido como chicote, estica os braços desproporcionalmente, invoca teias, arremessa acessórios quebrados.

---

## 6. Direção de Ambientes (Cenários — Baseado nas 9 Pranchas de Ambiente)

> **Regra de Referência:** As 9 pranchas visuais enviadas definem **exclusivamente a evolução dos cenários, paletas, camadas e iluminação**. Elas nunca alteram a trava de estilo de Pablita (Seção 3.1) ou de Pipop (Seção 3.2).

### 6.1 O Quarto de Pablita (Ambiente Único — Início e Fim)
*   **Estado 1 (Luz Acesa):** Tábuas de madeira quentes, tapete rosa estrelado/remendado, janela com cortina e luz âmbar de abajur/mesa, ursinhos e cama acolhedora.
*   **Estado 2 (Luz Apagada):** Exatamente o mesmo quarto, mergulhado em sombras azul-profundo e violeta-escuro frio até que o despertar/clímax acenda a luz quente.

### 6.2 O Esquecido — Evolução Gradual por Fases
*   **Fases 1 e 2 (Integração com o Quarto):** Piso de tábuas de madeira (`tile_wood_blend_a`) e retalhos do tapete rosa (`tile_rug_patched`) ainda resistem sobre o chão, sendo gradualmente invadidos por lajes de pedra roxa rachada, musgo, raízes e caixas. Abajures acesos (`prop_warm_lamp`) e ursinhos esquecidos (`prop_giant_teddy`) irradiam pontos isolados de luz âmbar contra a névoa violeta.
*   **Fase 3 (Transição — Arena da Meia Esquecida):** As tábuas do quarto somem quase por completo (`esquecido_fase3_tileset`). Predomina o piso de pedra roxa rachada (`tile_stone_a`, `tile_stone_cracked`), ruínas (`tile_ruin_wall`), raízes secas (`tile_dead_roots`) e brinquedos/caixas quebradas (`tile_clutter_toys`), iluminados apenas por cogumelos roxos brilhantes (`tile_glow_mushrooms`) e focos residuais de âmbar.
*   **Fases 4 a 6 (Vila dos Achados e Transição à Forja):** Paralelepípedos arroxeados com musgo (`tile_cobble_vila`), barreiras e postes com lampiões (`prop_street_lantern`) cuja luz quente vai esfriando em direção às engrenagens e tubos enferrujados (`prop_rusty_gears`) da Forja Rítmica.
*   **Fases 7 a 10 (Esquecido Puro / Abissal):** Zero vestígio do quarto. Lajes abissais em índigo e roxo muito escuro (`tile_deep_void_stone`), arcos de pedra em ruína com correntes de ferro (`prop_ruin_arch_chains`), cristais roxos/magenta neon (`prop_neon_crystals`), cogumelos bioluminescentes e esporos flutuantes compõem a caverna de memórias perdidas até a Arena da Rainha Empoeirada.

### 6.3 Arquitetura em Camadas e Paleta Progressiva
*   **Camadas (ordem de desenho):** 1. Plano de Fundo (`#140b1f` / `#1a1129`) -> 2. Piso / Terreno (madeira/pedra/paralelepípedo/abissal) -> 3. Vegetação e Detritos -> 4. Objetos e Decoração -> 5. Elementos Especiais / Luzes (brilho âmbar na integração -> roxo/magenta neon no Esquecido Puro).
*   **Curva de Cor:** Tons quentes pêssego/ocre/madeira (`#ffd97d`, `#ffa940`, `#bd7c56`, `#9c6244`) nas Fases 1–3 -> transição para ardósia/violeta médio (`#6d6585`, `#493661`, `#352647`) nas Fases 4–6 -> domínio abissal e bioluminescente (`#1a1129`, `#251933`, `#7822b5`, `#b84dff`, `#ff6ef7`) nas Fases 7–10.

---

## 7. Direção de Interface (HUD Mobile)
*   **Botão de Ataque Físico:** Ícone da **manopla felpuda do Pipop (rosa)** em destaque sobre botão circular de toque generoso.
*   **Botão de Ataque Sonoro:** Ícone de **ondas sonoras concêntricas (roxo/rosa)** sobre botão circular de toque.
*   **Barra de Presença e Capacidade de Pipop:** Compacta no canto superior esquerdo, com retrato fiel do Pipop (olhos rosa cansados) e slots de capacidade simples em linha, deixando o centro da viewport 640×360 totalmente livre para nunca cobrir a Pablita.

---

## 8. Política de Proveniência e Pipeline Técnico
1. **Arquivos-Fonte (`tools/pxl/*.px.js`):** Todos os sprites procedimentais gerados via `pxl` mantêm seu código-fonte versionado no repositório e exportam PNGs com filtro `Nearest`.
2. **Preservação de Referências (`assets/_reference/`):** Intocáveis. Nenhum script pode sobrescrever os arquivos originais do pacote conceitual.
3. **Regra de Ouro nos Prompts:** Sempre incluir *"Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down"*.
