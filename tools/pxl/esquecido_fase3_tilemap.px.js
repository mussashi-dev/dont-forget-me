// Ambiente: O Esquecido — Fase 3 (Transição) + Tileset 32x32 (Bíblia de Direção de Arte - Seção 6.2 e Passo 3)
// Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down.
// Direção:
// - O chão de madeira do quarto desaparece; piso de pedra roxa rachada.
// - Objetos antigos (caixas de papelão, brinquedos quebrados, carretéis) misturados à vegetação morta.
// - Iluminação fria/neon vindo de cogumelos roxos brilhantes.

pal({
  k: "#140b1f",                                                             // fendas profundas e sombra de parede
  // Pedra roxa rachada (fria e desgastada)
  p: "#352647", P: "#493661", d: "#251933", l: "#60497d",                   // lajes de pedra roxa / borda iluminada / sombra
  // Vegetação morta e raízes secas
  v: "#3d2f42", V: "#56425c", m: "#2c2030",                                 // galhos secos / folhas murchas roxo-acinzentadas
  // Cogumelos e cristais roxos brilhantes (iluminação bioluminescente)
  g: "#b84dff", G: "#ea9eff", u: "#7822b5", s: "#d8b8f2", o: "#ff6ef7",     // chapéu neon / pintas brilhantes / caule pálido / brilho intenso
  // Objetos antigos (caixas de papelão e brinquedos quebrados)
  c: "#8f6239", C: "#b58253", b: "#5c3c20",                                 // papelão / madeira velha
  t: "#bf5275", a: "#5688a8", y: "#d9b45b",                                 // blocos e brinquedos quebrados desbotados
  // Quarto (tábuas quentes, tapete rosa remendado e luz âmbar)
  w: "#9c6244", W: "#bd7c56", D: "#6b3e29",                                 // madeira quente do quarto
  r: "#b85c7e", R: "#d67a9c", q: "#7d3854",                                 // tapete rosa / destaque / sombra
  A: "#ffd97d", O: "#ffa940",                                               // brilho quente de abajur e lampião
  // Vegetação musgosa (fases iniciais/vila) e engrenagens/ferro (transição/forja/profundo)
  f: "#3e6952", F: "#598c68",                                               // musgo e folhas
  i: "#4a435c", I: "#6d6585", e: "#8c4a2b", E: "#b86b3d",                   // paralelepípedo/ferro e latão enferrujado
  n: "#1a1129", N: "#261a3b",                                               // pedra abissal (Esquecido Profundo)
})

// ==================== TILES 32x32 ====================

// Tile 1: Laje de pedra roxa padrão com juntas
sprite("tile_stone_a", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "p")
  c.hline(0, 0, 32, "P"); c.vline(0, 0, 32, "P")
  c.hline(0, 31, 32, "d"); c.vline(31, 0, 32, "d")
  c.hline(0, 15, 32, "d"); c.vline(16, 0, 15, "d"); c.vline(8, 16, 16, "d")
  c.px(3, 2, "l"); c.px(19, 18, "l")
})

// Tile 2: Pedra roxa profundamente rachada
sprite("tile_stone_cracked", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "p")
  c.hline(0, 0, 32, "P"); c.hline(0, 31, 32, "d")
  // Rachadura diagonal ramificada
  c.line(4, 4, 15, 16, "k"); c.line(15, 16, 27, 26, "k")
  c.line(15, 16, 8, 25, "d"); c.line(18, 19, 25, 11, "d")
  c.px(15, 15, "l"); c.px(16, 17, "l")
})

// Tile 3: Pedra invadida por vegetação morta e raízes
sprite("tile_dead_roots", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "d")
  c.rect(2, 2, 28, 28, "p")
  // Emaranhado de raízes mortas e folhas murchas nas bordas
  c.ellipse(8, 8, 6, 5, "m"); c.ellipse(7, 7, 4, 3, "v"); c.px(6, 6, "V")
  c.ellipse(24, 23, 7, 5, "m"); c.ellipse(23, 22, 5, 3, "v"); c.px(22, 21, "V")
  c.line(8, 12, 16, 20, "m"); c.line(16, 20, 22, 22, "v")
})

// Tile 4: Aglomerado de Cogumelos Roxos Brilhantes (Fonte de Luz)
sprite("tile_glow_mushrooms", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "d")
  // Halo de luz roxa no chão de pedra
  c.ellipse(16, 18, 13, 10, "p")
  c.ellipse(16, 18, 9, 7, "u")
  // Cogumelo maior central
  c.rect(14, 16, 4, 7, "s")
  c.ellipse(16, 13, 7, 5, "u")
  c.ellipse(16, 12, 6, 4, "g")
  c.px(13, 11, "G"); c.px(17, 10, "G"); c.px(15, 13, "G")
  // Cogumelos menores laterais
  c.rect(7, 20, 2, 4, "s"); c.ellipse(8, 19, 4, 3, "g"); c.px(8, 18, "G")
  c.rect(22, 19, 2, 4, "s"); c.ellipse(23, 18, 4, 3, "g"); c.px(23, 17, "G")
  // Esporos luminosos flutuando
  c.px(6, 10, "G"); c.px(25, 9, "G"); c.px(16, 4, "G")
})

// Tile 5: Caixa de papelão antiga e brinquedos quebrados entre arbustos secos
sprite("tile_clutter_toys", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "p")
  // Vegetação morta ao fundo
  c.ellipse(10, 10, 6, 4, "m"); c.ellipse(10, 9, 4, 3, "v")
  // Caixa de papelão amassada
  c.rect(6, 12, 12, 10, "b")
  c.rect(7, 13, 10, 8, "c")
  c.rect(7, 13, 10, 2, "C")
  c.line(7, 16, 16, 16, "b")
  // Brinquedos quebrados ao lado (bloco colorido e rodinha solta)
  c.rect(20, 18, 6, 6, "t"); c.rect(21, 19, 4, 4, "y")
  c.ellipse(19, 26, 3, 2, "a"); c.px(19, 26, "k")
})

// Tile 6: Parede / Ruína de pedra roxa superior
sprite("tile_ruin_wall", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "k")
  c.rect(1, 2, 14, 12, "d"); c.rect(2, 3, 12, 9, "P")
  c.rect(17, 2, 14, 12, "d"); c.rect(18, 3, 12, 9, "p")
  c.rect(0, 16, 9, 14, "d"); c.rect(11, 16, 19, 14, "d"); c.rect(12, 17, 17, 11, "p")
  c.hline(0, 30, 32, "l")
})

sheet("esquecido_fase3_tileset", [
  "tile_stone_a", "tile_stone_cracked", "tile_dead_roots",
  "tile_glow_mushrooms", "tile_clutter_toys", "tile_ruin_wall"
], { cols: 3, pad: 0 })

// ==================== PROGRESSÃO DAS 9 PRANCHAS DE AMBIENTE ====================

// Fase 1-2: Tábuas de madeira quentes com bordas invadidas pelo roxo do Esquecido
sprite("tile_wood_blend_a", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "w")
  for (let y = 0; y < 32; y += 8) {
    c.hline(0, y, 32, "W")
    c.hline(0, y + 7, 32, "D")
  }
  c.vline(10, 0, 8, "D"); c.vline(22, 8, 8, "D"); c.vline(15, 16, 8, "D"); c.vline(25, 24, 8, "D")
  // Laje roxa invadindo canto inferior direito
  c.rect(20, 20, 12, 12, "p"); c.rect(24, 16, 8, 6, "d"); c.hline(20, 20, 12, "l")
  c.px(5, 3, "W"); c.px(18, 11, "D"); c.px(25, 26, "P")
})

// Fase 1-2: Retalho de tapete rosa estrelado/desgastado sobre tábuas/pedra
sprite("tile_rug_patched", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "w")
  c.rect(2, 2, 28, 28, "q")
  c.rect(3, 3, 26, 26, "r")
  c.rect(5, 5, 22, 22, "R")
  // Costuras e estrelinhas desbotadas do quarto
  c.hline(4, 4, 24, "A"); c.hline(4, 27, 24, "q")
  c.px(10, 10, "A"); c.px(20, 11, "A"); c.px(15, 18, "A"); c.px(9, 21, "A")
  // Canto roído pelo Esquecido
  c.rect(21, 21, 9, 9, "p"); c.line(21, 21, 29, 29, "k")
})

// Fase 1-3: Abajur quente sobre mesinha de cabeceira/caixote (luz âmbar acolhedora)
sprite("prop_warm_lamp", { w: 32, h: 32 }, (c) => {
  // Halo âmbar no chão
  c.ellipse(16, 17, 13, 12, "b"); c.ellipse(16, 17, 10, 9, "O"); c.ellipse(16, 16, 7, 6, "A")
  // Mesinha de madeira
  c.rect(9, 18, 14, 10, "D"); c.rect(10, 19, 12, 7, "w"); c.hline(10, 19, 12, "W")
  // Cúpula e base do abajur
  c.rect(14, 14, 4, 5, "D")
  c.rect(11, 7, 10, 7, "O"); c.rect(12, 8, 8, 5, "A"); c.hline(12, 7, 8, "W")
  c.px(15, 10, "A"); c.px(16, 10, "A")
})

// Fase 1-3: Urso de pelúcia gigante (referência recorrente nas pranchas de cenário)
sprite("prop_giant_teddy", { w: 48, h: 48 }, (c) => {
  // Sombra suave
  c.ellipse(24, 42, 16, 5, "k")
  // Pernas e braços rechonchudos
  c.ellipse(12, 34, 6, 7, "b"); c.ellipse(12, 33, 5, 6, "c"); c.ellipse(11, 35, 3, 3, "C")
  c.ellipse(36, 34, 6, 7, "b"); c.ellipse(36, 33, 5, 6, "c"); c.ellipse(37, 35, 3, 3, "C")
  // Barriga e corpo
  c.ellipse(24, 30, 13, 12, "b"); c.ellipse(24, 29, 11, 10, "c"); c.ellipse(24, 31, 7, 6, "C")
  // Braços
  c.ellipse(11, 24, 5, 4, "b"); c.ellipse(11, 24, 4, 3, "c")
  c.ellipse(37, 24, 5, 4, "b"); c.ellipse(37, 24, 4, 3, "c")
  // Cabeça e orelhas redondas
  c.ellipse(13, 10, 5, 5, "b"); c.ellipse(13, 10, 3, 3, "c")
  c.ellipse(35, 10, 5, 5, "b"); c.ellipse(35, 10, 3, 3, "c")
  c.ellipse(24, 15, 12, 10, "b"); c.ellipse(24, 15, 10, 8, "c")
  // Focinho costurado e olhos de botão
  c.ellipse(24, 17, 5, 4, "C"); c.rect(22, 15, 4, 2, "k")
  c.px(19, 13, "k"); c.px(29, 13, "k"); c.px(24, 19, "k")
  // Laço / remendo rosa do quarto
  c.rect(21, 23, 6, 3, "r"); c.px(24, 24, "q")
})

// Fase 4-6: Paralelepípedos arroxeados da Vila dos Achados com musgo
sprite("tile_cobble_vila", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "d")
  const stones = [
    [1, 1, 9, 7], [11, 1, 10, 8], [22, 1, 9, 7],
    [1, 10, 12, 9], [14, 10, 8, 9], [23, 10, 8, 9],
    [1, 21, 8, 9], [10, 21, 11, 9], [22, 21, 9, 9]
  ]
  for (const [x, y, w, h] of stones) {
    c.rect(x, y, w, h, "i"); c.hline(x, y, w, "I"); c.hline(x, y + h - 1, w, "k")
  }
  c.ellipse(13, 19, 3, 2, "f"); c.px(13, 19, "F")
  c.ellipse(24, 8, 2, 2, "f")
})

// Fase 4-6: Lampião de rua da Vila dos Achados (ferro e vidro luminoso)
sprite("prop_street_lantern", { w: 32, h: 48 }, (c) => {
  // Base de pedra e poste de ferro
  c.ellipse(16, 44, 8, 3, "k")
  c.rect(11, 39, 10, 5, "d"); c.rect(12, 39, 8, 3, "i")
  c.rect(14, 18, 4, 21, "k"); c.vline(15, 19, 19, "I")
  // Topo da lanterna + brilho quente/roxo
  c.ellipse(16, 12, 11, 9, "u")
  c.rect(10, 6, 12, 11, "k"); c.rect(11, 7, 10, 9, "O"); c.rect(12, 8, 8, 7, "A")
  c.rect(9, 4, 14, 3, "i"); c.rect(13, 2, 6, 2, "I")
})

// Fase 5-7: Engrenagens enferrujadas, tubos e grade metálica (Forja Rítmica)
sprite("prop_rusty_gears", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "n")
  // Tubo e grade
  c.rect(2, 2, 28, 6, "d"); c.rect(2, 3, 28, 3, "i"); c.hline(2, 3, 28, "I")
  // Engrenagem maior de latão enferrujado
  c.ellipse(14, 18, 9, 9, "e"); c.ellipse(14, 18, 7, 7, "E"); c.ellipse(14, 18, 3, 3, "k")
  c.rect(13, 7, 2, 22, "e"); c.rect(3, 17, 22, 2, "e")
  c.ellipse(14, 18, 6, 6, "E"); c.ellipse(14, 18, 2, 2, "n")
  // Engrenagem menor
  c.ellipse(25, 23, 5, 5, "e"); c.ellipse(25, 23, 3, 3, "E"); c.px(25, 23, "k")
})

// Fase 7-10: Laje abissal roxo-índigo profundo do Esquecido Puro
sprite("tile_deep_void_stone", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "n")
  c.hline(0, 0, 32, "d"); c.vline(0, 0, 32, "d")
  c.hline(0, 16, 32, "k"); c.vline(16, 0, 16, "k"); c.vline(7, 16, 16, "k")
  c.rect(2, 2, 12, 12, "N"); c.rect(18, 2, 12, 12, "N"); c.rect(9, 18, 21, 12, "N")
  // Fissura arcana sutil
  c.line(18, 12, 26, 20, "k"); c.px(21, 15, "u"); c.px(24, 18, "g")
})

// Fase 7-10: Cristais roxos neon brilhantes (iluminação do Esquecido Profundo)
sprite("prop_neon_crystals", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "n")
  c.ellipse(16, 20, 13, 9, "d"); c.ellipse(16, 19, 10, 7, "u")
  // Cristal central alto
  c.rect(13, 6, 6, 18, "u"); c.rect(14, 8, 4, 15, "g"); c.rect(15, 9, 2, 11, "G"); c.px(15, 7, "o")
  // Cristais laterais inclinados
  c.rect(7, 13, 4, 11, "u"); c.rect(8, 14, 2, 9, "g"); c.px(8, 14, "G")
  c.rect(20, 11, 5, 13, "u"); c.rect(21, 12, 3, 11, "g"); c.px(22, 12, "G")
  c.px(6, 7, "o"); c.px(26, 8, "G"); c.px(16, 3, "o")
})

// Fase 7-10: Arco em ruínas com correntes de ferro e musgo roxo
sprite("prop_ruin_arch_chains", { w: 48, h: 48 }, (c) => {
  c.rect(0, 0, 48, 48, "k")
  // Pilares de pedra abissal
  c.rect(4, 6, 11, 38, "d"); c.rect(5, 7, 9, 36, "p"); c.hline(5, 7, 9, "P")
  c.rect(33, 6, 11, 38, "d"); c.rect(34, 7, 9, 36, "p"); c.hline(34, 7, 9, "P")
  // Verga superior rachada
  c.rect(4, 4, 40, 10, "d"); c.rect(6, 5, 36, 7, "p"); c.hline(6, 5, 36, "l")
  c.rect(15, 14, 18, 30, "n")
  // Correntes penduradas no arco
  for (let y = 14; y < 30; y += 3) {
    c.rect(18, y, 2, 2, "I"); c.rect(28, y, 2, 2, "I")
  }
  c.rect(17, 30, 4, 3, "i"); c.rect(27, 27, 4, 3, "i")
  // Vegetação roxa e cristal pequeno na base
  c.ellipse(9, 41, 6, 4, "u"); c.ellipse(9, 40, 4, 3, "g")
  c.ellipse(38, 12, 5, 3, "v"); c.px(39, 11, "V")
})

sheet("esquecido_progression_tileset", [
  "tile_wood_blend_a", "tile_rug_patched", "prop_warm_lamp", "prop_giant_teddy",
  "tile_cobble_vila", "prop_street_lantern", "prop_rusty_gears",
  "tile_deep_void_stone", "prop_neon_crystals", "prop_ruin_arch_chains"
], { cols: 5, pad: 2 })

// ==================== COMPOSIÇÃO DE TILEMAP DEMONSTRATIVO (256x160) ====================
scene("esquecido_fase3_map", { w: 256, h: 160, bg: "k" }, (c) => {
  const layout = [
    ["tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall", "tile_ruin_wall"],
    ["tile_dead_roots", "tile_glow_mushrooms", "tile_stone_a", "tile_stone_cracked", "tile_clutter_toys", "tile_stone_a", "tile_glow_mushrooms", "tile_dead_roots"],
    ["tile_stone_cracked", "tile_stone_a", "tile_stone_cracked", "tile_stone_a", "tile_stone_a", "tile_stone_cracked", "tile_stone_a", "tile_clutter_toys"],
    ["tile_clutter_toys", "tile_stone_a", "tile_glow_mushrooms", "tile_stone_cracked", "tile_stone_a", "tile_glow_mushrooms", "tile_stone_cracked", "tile_dead_roots"],
    ["tile_dead_roots", "tile_dead_roots", "tile_stone_cracked", "tile_clutter_toys", "tile_dead_roots", "tile_stone_cracked", "tile_dead_roots", "tile_dead_roots"]
  ]
  for (let row = 0; row < layout.length; row++) {
    for (let col = 0; col < layout[row].length; col++) {
      c.stamp(layout[row][col], col * 32, row * 32)
    }
  }
})
