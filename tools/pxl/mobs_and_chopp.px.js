// Chopp (O Rato) e os 4 Mobs do Esquecido — TOP-DOWN (Bíblia de Direção de Arte - Seções 3.3 e 4)
// Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down.
// Escalas:
// - Chopp: 20-25% de Pablita (16x16 px) — Rato pequeno usando farrapos/lenço do Esquecido, expressivo e desconfiado.
// - Mob 1: O Tufo de Meias (24x24 px) — Bola emaranhada de meias velhas, fios soltos como tentáculos curtos, sem olhos, apenas um buraco escuro.
// - Mob 2: O Brinquedo de Corda (24x24 px) — Coelho de plástico antigo, sem uma orelha, com chave de corda nas costas, avança quicando.
// - Mob 3: Flor de Poeira (28x28 px) — Planta carnívora murcha feita de sacolas plásticas velhas, cospe esporos e morde.
// - Mob 4: O Boneco Desfiado (32x32 px) — Boneco de pano do tamanho de Pablita, um braço faltando, algodão saindo, segura agulha gigante.

pal({
  k: "#21132b",                                                             // contorno escuro do Esquecido
  // Chopp (rato + farrapos)
  r: "#8a7d93", R: "#aba0b5", d: "#5d5166",                                 // pelagem cinza-lavanda do Esquecido
  e: "#e09b9b", E: "#b56971",                                               // orelhas / nariz / cauda
  c: "#c78d38", C: "#8f5b1d", y: "#f2c66d",                                 // farrapos ocre/dourado puído
  w: "#f5eef7", n: "#120917",                                               // olhos expressivos desconfiados
  // Mob 1: Tufo de Meias
  s: "#7d6885", S: "#a48fab", z: "#4d3b57", v: "#140a1c",                   // meias velhas / sombra / buraco escuro vazio
  f: "#d65ca3", F: "#64a8d1",                                               // fios coloridos soltos (rosa e azul desbotado)
  // Mob 2: Brinquedo de Corda (Coelho de plástico antigo)
  p: "#d9c29c", P: "#f0dec0", q: "#a68c65",                                 // plástico amarelado antigo
  m: "#94a1b2", M: "#cdd6e0", g: "#586373",                                 // chave de corda metálica nas costas
  a: "#d9415d",                                                             // olho de botão / rachadura
  // Mob 3: Flor de Poeira (Sacolas plásticas murchas)
  b: "#7888a6", B: "#a3b4d4", u: "#4b5770",                                 // sacola plástica translúcida/acinzentada
  l: "#5f436b", L: "#3e2847", x: "#b855d9",                                 // caule de arame/poeira e esporos roxos
  // Mob 4: Boneco Desfiado (Boneco de pano + algodão + agulha)
  t: "#a88468", T: "#c7a387", o: "#75563f",                                 // tecido de estopa/pano velho
  W: "#f7f2eb", G: "#cfc6b8",                                               // algodão saindo do braço faltando
})

// ==================== 1. CHOPP (O Rato - 16x16) ====================
const choppFrame = (ph) => {
  const by = (ph % 2 === 1) ? -1 : 0
  return [(c) => {
    // Cauda fina enrolada
    c.px(11, 12, "E"); c.px(12, 11, "e"); c.px(13, 10, "e")
    // Pés pequenos
    c.px(5, 13, "e"); c.px(9, 13, "e")
    // Corpo pequeno envolto em farrapos/capa puída do Esquecido
    c.ellipse(7, 10 + by, 3, 3, "C")
    c.ellipse(7, 9 + by, 3, 2, "c")
    c.px(6, 10 + by, "y"); c.px(8, 11 + by, "d") // remendo nos farrapos
    // Cabeça de rato expressiva
    c.ellipse(7, 5 + by, 3, 3, "r")
    c.ellipse(6, 4 + by, 2, 2, "R")
    // Orelhas redondas grandes (uma com pequeno corte)
    c.ellipse(3, 3 + by, 2, 2, "d"); c.px(3, 3 + by, "e")
    c.ellipse(11, 3 + by, 2, 2, "d"); c.px(11, 3 + by, "e")
    // Olhos desconfiados (semicerrados)
    c.px(5, 4 + by, "d"); c.px(6, 4 + by, "d"); c.px(8, 4 + by, "d"); c.px(9, 4 + by, "d")
    c.px(5, 5 + by, "w"); c.px(6, 5 + by, "n"); c.px(8, 5 + by, "w"); c.px(9, 5 + by, "n")
    // Focinho rosado e bigodes
    c.px(7, 7 + by, "e")
    c.px(3, 6 + by, "R"); c.px(11, 6 + by, "R")
  }]
}

// ==================== 2. MOB 1: O TUFO DE MEIAS (24x24) ====================
const mobTufoMeias = (ph) => {
  const stretch = (ph === 1) ? 1 : (ph === 2 ? -1 : 0)
  return [(c) => {
    // Tentáculos curtos de fios soltos na base e laterais
    for (let i = 0; i < 6; i++) {
      const ang = (i * 60 + ph * 20) * Math.PI / 180
      const tx = Math.round(11 + Math.cos(ang) * (8 + (i % 2)))
      const ty = Math.round(12 + Math.sin(ang) * (7 + (i % 2)))
      c.px(tx, ty, i % 2 === 0 ? "f" : "F")
      c.px(Math.round((tx + 11) / 2), Math.round((ty + 12) / 2), "z")
    }
    // Bola emaranhada de meias velhas
    c.ellipse(11, 12, 7 + stretch, 6 - stretch, "z")
    c.ellipse(10, 11, 6 + stretch, 5 - stretch, "s")
    c.ellipse(9, 10, 4, 3, "S")
    // Listras de cano de meia velha e calcanhar puído
    c.line(6, 8, 15, 10, "f")
    c.line(7, 15, 16, 13, "F")
    // Sem olhos: apenas um buraco escuro central profundo
    c.ellipse(11, 12, 3, 3, "k")
    c.ellipse(11, 12, 2, 2, "v")
  }]
}

// ==================== 3. MOB 2: O BRINQUEDO DE CORDA (24x24) ====================
const mobBrinquedoCorda = (ph) => {
  const hop = (ph === 1 || ph === 3) ? -2 : 0
  return [(c) => {
    // Chave de corda metálica nas costas (girando conforme o frame)
    c.rect(2, 9 + hop, 3, 2, "g")
    if (ph % 2 === 0) {
      c.ellipse(2, 7 + hop, 2, 2, "M"); c.ellipse(2, 12 + hop, 2, 2, "m")
    } else {
      c.rect(1, 8 + hop, 2, 4, "M")
    }
    // Pés de plástico rígido
    c.ellipse(8, 19 + hop, 3, 2, "q"); c.ellipse(15, 19 + hop, 3, 2, "q")
    // Corpo de coelho de plástico antigo desbotado
    c.ellipse(12, 14 + hop, 6, 5, "q")
    c.ellipse(12, 13 + hop, 5, 4, "p")
    c.px(10, 11 + hop, "P"); c.px(11, 11 + hop, "P")
    // Cabeça de coelho
    c.ellipse(13, 7 + hop, 5, 4, "p")
    c.ellipse(12, 6 + hop, 3, 3, "P")
    // Orelha esquerda inteira; orelha direita QUEBRADA (toco rachado)
    c.ellipse(10, 2 + hop, 2, 3, "p"); c.px(10, 2 + hop, "e")
    c.rect(15, 3 + hop, 2, 2, "q"); c.px(15, 3 + hop, "k") // orelha faltando
    // Olho de plástico vermelho bizarro e dentes pintados descascados
    c.px(14, 6 + hop, "a"); c.px(15, 6 + hop, "w")
    c.px(10, 6 + hop, "k")
    c.rect(12, 9 + hop, 4, 2, "k")
    c.px(13, 9 + hop, "w"); c.px(14, 9 + hop, "w")
  }]
}

// ==================== 4. MOB 3: FLOR DE POEIRA (28x28) ====================
const mobFlorPoeira = (ph) => {
  const open = (ph === 1 || ph === 2) ? 1 : 0
  return [(c) => {
    // Base de sacolas plásticas rasgadas e raízes de poeira/arame
    c.ellipse(13, 21, 8, 4, "L")
    c.ellipse(13, 20, 6, 3, "l")
    c.line(6, 22, 3, 24, "l"); c.line(20, 22, 23, 24, "l")
    // Caule retorcido
    c.rect(12, 13, 3, 7, "l"); c.px(13, 15, "u")
    // Pétalas murchas feitas de alças de sacola plástica velha
    c.ellipse(7, 11, 4, 3, "u"); c.ellipse(7, 10, 3, 2, "b")
    c.ellipse(19, 11, 4, 3, "u"); c.ellipse(19, 10, 3, 2, "b")
    c.ellipse(13, 6, 5, 3, "b"); c.ellipse(13, 5, 3, 2, "B")
    // Cabeça carnívora central
    c.ellipse(13, 11, 6, 5, "u")
    c.ellipse(13, 10, 5, 4, "b")
    c.px(10, 7, "B"); c.px(11, 7, "B")
    // Boca serrilhada que morde e cospe esporos roxos
    c.rect(9, 9 - open, 9, 3 + open * 2, "v")
    for (let x = 9; x <= 17; x += 2) {
      c.px(x, 9 - open, "W")
      c.px(x + 1, 11 + open, "W")
    }
    if (ph === 2) {
      // Esporos flutuando
      c.px(13, 2, "x"); c.px(8, 3, "f"); c.px(18, 3, "x")
    }
  }]
}

// ==================== 5. MOB 4: O BONECO DESFIADO (32x32) ====================
const mobBonecoDesfiado = (ph) => {
  const step = (ph === 1) ? 1 : (ph === 3 ? -1 : 0)
  const thrust = (ph === 2) ? 2 : 0
  return [(c) => {
    // Pernas de pano costuradas
    c.ellipse(12, 27 + step, 3, 2, "o")
    c.ellipse(18, 27 - step, 3, 2, "o")
    // Tronco de estopa do tamanho de Pablita
    c.ellipse(15, 19, 6, 6, "o")
    c.ellipse(15, 18, 5, 5, "t")
    // Costuras pretas cruzadas no peito
    c.line(12, 16, 18, 21, "k"); c.px(14, 18, "k"); c.px(16, 17, "k")
    // Braço esquerdo FALTANDO -> Toco rasgado com algodão branco saindo!
    c.ellipse(8, 16, 2, 2, "W")
    c.px(7, 15, "G"); c.px(6, 16, "W"); c.px(7, 17, "W")
    // Cabeça de boneco de pano caída para o lado
    c.ellipse(15, 9, 6, 5, "o")
    c.ellipse(15, 8, 5, 4, "T")
    // Olho de botão único e outro rasgado em X
    c.ellipse(12, 8, 2, 2, "k"); c.px(12, 8, "a")
    c.px(17, 7, "k"); c.px(19, 9, "k"); c.px(19, 7, "k"); c.px(17, 9, "k")
    // Boca costurada
    c.rect(12, 11, 6, 1, "k"); c.px(13, 10, "k"); c.px(15, 12, "k"); c.px(17, 10, "k")
    // Braço direito segurando AGULHA GIGANTE (estocada)
    c.ellipse(21, 17, 2, 3, "t")
    c.line(21, 21 - thrust, 27, 5 - thrust, "m")
    c.line(22, 20 - thrust, 28, 4 - thrust, "M")
    c.px(21, 21 - thrust, "k") // furo da agulha com linha presa
    c.line(20, 22, 17, 24, "f")
  }]
}

for (let p = 0; p < 4; p++) {
  sprite(`chopp_idle_${p}`, { w: 14, h: 14, outline: "k" }, ...choppFrame(p))
  sprite(`mob_tufo_meias_${p}`, { w: 22, h: 22, outline: "k" }, ...mobTufoMeias(p))
  sprite(`mob_brinquedo_corda_${p}`, { w: 22, h: 22, outline: "k" }, ...mobBrinquedoCorda(p))
  sprite(`mob_flor_poeira_${p}`, { w: 26, h: 26, outline: "k" }, ...mobFlorPoeira(p))
  sprite(`mob_boneco_desfiado_${p}`, { w: 30, h: 30, outline: "k" }, ...mobBonecoDesfiado(p))
}

sheet("mobs_and_chopp_sheet", [
  "chopp_idle_*",
  "mob_tufo_meias_*",
  "mob_brinquedo_corda_*",
  "mob_flor_poeira_*",
  "mob_boneco_desfiado_*"
], { cols: 4, pad: 2 })
