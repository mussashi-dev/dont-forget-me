// Os 3 Chefes (Bosses) — Escala 250-400% (Bíblia de Direção de Arte - Seção 5)
// Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down.
// - Chefe 1: A Meia Esquecida (Fase 3) — 300% de Pablita (96x96 px). Meia cinza/bege gigante e puída, furos irregulares (vazio escuro), remendos coloridos e fios longos como raízes brilhando em roxo.
// - Chefe 2: O Robô Esquecido (Fase 7) — 350% de Pablita (112x112 px). Robô de lata dos anos 80, pintura azul descascada e ferrugem, olhos de lâmpada (um quebrado), antena torta, engrenagens expostas e ondas/faíscas.
// - Chefe 3: A Rainha Empoeirada (Fase 10) — 400% de Pablita (128x128 px). Boneca de moda gigante e aterrorizante, vestido de retalhos em decomposição cheio de teias, maquiagem borrada/escorrida, cabelo embaraçado com pedaços de outras bonecas, costuras brilhantes e coroa de plástico quebrado.

pal({
  k: "#160c21",                                                             // contorno sombrio e furos de vazio escuro
  // Chefe 1: A Meia Esquecida (cinza/bege puído + remendos + raízes roxas brilhantes)
  s: "#9e9284", S: "#bfb3a4", d: "#6e6357", D: "#4a4138",                   // tecido cinza/bege puído
  p: "#d45999", b: "#5899c4", y: "#e0b653",                                 // remendos de linhas coloridas
  v: "#b94cff", V: "#e29eff", u: "#6c24a6",                                 // fios roxos brilhantes (perigo)
  // Chefe 2: O Robô Esquecido (azul anos 80 descascado + ferrugem + lâmpada + engrenagens)
  a: "#3d6e9c", A: "#659ad9", c: "#264666",                                 // pintura azul metálica anos 80
  r: "#a64b2a", R: "#d46f3d", o: "#6e2c18",                                 // ferrugem pesada e desgaste
  g: "#c99842", G: "#f2ca6b",                                               // engrenagens de latão/bronze expostas
  l: "#59f2ff", L: "#fff6a1",                                               // lâmpada acesa / faíscas e ondas sonoras
  // Chefe 3: A Rainha Empoeirada (vestido de retalhos + teias + cabelo embaraçado + maquiagem escorrida)
  q: "#d9b8a3", Q: "#f2d6c4", m: "#9c7a69",                                 // plástico de boneca pálido/empoeirado
  h: "#c99649", H: "#e8bd72", n: "#7d5522",                                 // cabelo loiro embaraçado e sujo
  w: "#6e2b54", W: "#9e4277", x: "#3d1633",                                 // vestido imperial de retalhos em decomposição
  t: "#cfc9d6", T: "#8b8296",                                               // teias de aranha e costuras brilhantes
  e: "#ff2e63",                                                             // batom borrado / brilho de perigo
})

// ==================== CHEFE 1: A MEIA ESQUECIDA (96x96 — 300%) ====================
const bossMeiaEsquecida = () => [(c) => {
  // Raízes longas de fios roxos brilhantes espalhadas pelo chão
  for (let i = 0; i < 12; i++) {
    const ang = (i * 30 + 15) * Math.PI / 180
    const x1 = Math.round(47 + Math.cos(ang) * 28)
    const y1 = Math.round(54 + Math.sin(ang) * 22)
    const x2 = Math.round(47 + Math.cos(ang) * 43)
    const y2 = Math.round(54 + Math.sin(ang) * 36)
    c.line(x1, y1, x2, y2, i % 2 === 0 ? "v" : "u")
    c.px(x2, y2, "V"); c.px(Math.round((x1 + x2) / 2), Math.round((y1 + y2) / 2), "V")
  }

  // Corpo rasteiro e elástico de meia gigante (formato de L curvo / massa pesada)
  c.ellipse(47, 60, 34, 22, "D")
  c.ellipse(46, 58, 31, 19, "d")
  c.ellipse(45, 56, 27, 16, "s")
  c.ellipse(40, 52, 18, 10, "S")

  // Cano alto da meia erguido e retorcido no topo
  c.ellipse(38, 34, 20, 22, "d")
  c.ellipse(38, 33, 17, 19, "s")
  c.ellipse(36, 30, 12, 13, "S")
  // Listras desbotadas do cano da meia
  c.rect(22, 18, 32, 3, "p")
  c.rect(21, 24, 34, 3, "b")

  // Calcanhar puído à esquerda e ponteira caída à direita
  c.ellipse(20, 56, 11, 10, "p")
  c.ellipse(19, 55, 8, 7, "d")
  c.ellipse(70, 62, 13, 11, "b")
  c.ellipse(69, 61, 10, 8, "d")

  // Remendos de linhas coloridas costurados no tecido
  c.rect(48, 44, 12, 9, "p"); c.rect(49, 45, 10, 7, "d")
  for (let x = 48; x <= 60; x += 3) { c.line(x, 43, x, 54, "y") }
  c.rect(28, 62, 14, 8, "b")
  for (let x = 28; x <= 42; x += 3) { c.line(x, 61, x, 71, "V") }

  // Furos irregulares mostrando o VAZIO ESCURO interior e olhos de fenda roxa
  c.ellipse(35, 35, 6, 5, "k"); c.ellipse(35, 35, 3, 2, "v"); c.px(35, 35, "V")
  c.ellipse(49, 36, 5, 4, "k"); c.ellipse(49, 36, 2, 2, "v"); c.px(49, 36, "V")
  // Rasgo grande na barriga como uma bocarra de fios
  c.ellipse(44, 54, 14, 7, "k")
  for (let x = 33; x <= 55; x += 4) {
    c.line(x, 48, x + 1, 60, "v")
    c.px(x, 54, "V")
  }
}]

// ==================== CHEFE 2: O ROBÔ ESQUECIDO (112x112 — 350%) ====================
const bossRoboEsquecido = () => [(c) => {
  // Ondas sonoras visuais e arcos elétricos ao redor do chassi
  c.ring(55, 56, 48, "u")
  c.ring(55, 56, 51, "l")

  // Esteiras / Pés pesados de lata enferrujada
  c.rect(24, 84, 22, 18, "o"); c.rect(26, 86, 18, 14, "r")
  c.rect(64, 84, 22, 18, "o"); c.rect(66, 86, 18, 14, "r")
  for (let y = 86; y <= 98; y += 4) {
    c.rect(25, y, 20, 2, "k"); c.rect(65, y, 20, 2, "k")
  }

  // Braços articulados de lata anos 80 com garras de pinça
  c.rect(8, 44, 14, 30, "c"); c.rect(10, 46, 10, 26, "a")
  c.rect(10, 54, 10, 6, "r") // mancha de ferrugem
  c.ellipse(15, 78, 7, 6, "g"); c.ellipse(15, 80, 4, 4, "k")

  c.rect(88, 44, 14, 30, "c"); c.rect(90, 46, 10, 26, "a")
  c.rect(90, 50, 10, 8, "R") // ferrugem descascada
  c.ellipse(95, 78, 7, 6, "g"); c.ellipse(95, 80, 4, 4, "k")

  // Torso quadrado massivo de lata dos anos 80 (pintura azul descascada + ferrugem)
  c.rect(22, 38, 66, 48, "c")
  c.rect(25, 40, 60, 44, "a")
  c.rect(27, 42, 24, 16, "A") // brilho metálico azul
  // Placas de ferrugem onde a tinta azul descascou
  c.poly([25, 68, 44, 62, 52, 84, 25, 84], "r")
  c.poly([68, 40, 85, 40, 85, 60, 74, 54], "o")
  c.rect(72, 44, 10, 8, "R")

  // Cavidade peitoral aberta com ENGRENAGENS EXPOSTAS e núcleo rítmico
  c.rect(34, 48, 42, 28, "k")
  c.ellipse(44, 60, 9, 9, "g"); c.ellipse(44, 60, 4, 4, "k")
  c.ellipse(64, 64, 8, 8, "G"); c.ellipse(64, 64, 3, 3, "k")
  // Núcleo central ciano/amarelo vibrando com faíscas
  c.ellipse(54, 56, 6, 6, "l"); c.ellipse(54, 56, 3, 3, "L")
  c.line(54, 56, 38, 44, "L"); c.line(54, 56, 72, 70, "l")

  // Cabeça de lata quadrada no topo
  c.rect(32, 16, 46, 22, "c")
  c.rect(34, 18, 42, 18, "a")
  c.rect(34, 18, 16, 10, "r") // ferrugem na testa

  // Olho esquerdo: LÂMPADA ACESA brilhante; Olho direito: LÂMPADA QUEBRADA (cacos escuros)
  c.ellipse(44, 26, 6, 6, "g")
  c.ellipse(44, 26, 4, 4, "L"); c.px(43, 25, "l")
  c.ellipse(66, 26, 6, 6, "g")
  c.ellipse(66, 26, 4, 4, "k") // quebrado e escuro
  c.px(64, 24, "l"); c.px(68, 28, "l") // cacos de vidro e faísca

  // Grade de alto-falante na boca emitindo pulsos
  c.rect(42, 33, 26, 3, "k")
  for (let x = 44; x <= 66; x += 3) { c.px(x, 34, "G") }

  // Antena torta no topo soltando faíscas
  c.line(55, 16, 51, 8, "g")
  c.line(51, 8, 61, 4, "g")
  c.ellipse(62, 4, 3, 3, "L"); c.px(66, 2, "l"); c.px(58, 1, "L")
}]

// ==================== CHEFE 3: A RAINHA EMPOEIRADA (128x128 — 400%) ====================
const bossRainhaEmpoeirada = () => [(c) => {
  // Teias de aranha radiais e aura de vitral ao fundo
  for (let i = 0; i < 8; i++) {
    const ang = (i * 45) * Math.PI / 180
    c.line(63, 68, Math.round(63 + Math.cos(ang) * 58), Math.round(68 + Math.sin(ang) * 54), "T")
  }
  c.ring(63, 68, 48, "t")
  c.ring(63, 68, 34, "T")

  // Saia imensa de retalhos em decomposição (flutuando sobre o chão)
  c.ellipse(63, 84, 44, 32, "x")
  c.ellipse(63, 82, 40, 28, "w")
  c.ellipse(60, 78, 30, 20, "W")
  // Retalhos costurados na saia com costuras brilhantes
  c.poly([30, 80, 50, 72, 46, 98, 26, 92], "p")
  c.poly([72, 74, 96, 82, 90, 102, 68, 96], "b")
  c.line(30, 80, 50, 72, "V"); c.line(50, 72, 46, 98, "V")
  c.line(72, 74, 96, 82, "L"); c.line(68, 96, 90, 102, "L")
  // Teias sobre o vestido
  c.line(38, 88, 58, 104, "t"); c.line(48, 84, 44, 104, "t")

  // Cabelo loiro embaraçado gigante com pedaços de outras bonecas presos nele
  c.ellipse(63, 38, 34, 24, "n")
  c.ellipse(63, 36, 30, 21, "h")
  c.ellipse(58, 32, 22, 15, "H")
  // Pedaços de outras bonecas embaraçados no cabelo (cabeça menor quebrada à esquerda e mãozinha à direita)
  c.ellipse(34, 38, 7, 7, "q"); c.px(32, 37, "k"); c.px(36, 37, "k"); c.line(32, 40, 36, 40, "k")
  c.ellipse(92, 40, 6, 5, "q"); c.line(92, 35, 96, 32, "q")

  // Torso de boneca de moda (estilo Barbie) rachado com costuras brilhantes
  c.ellipse(63, 56, 14, 14, "m")
  c.ellipse(63, 55, 12, 12, "q")
  c.line(55, 50, 71, 62, "V") // costura brilhante cruzando o torso

  // Braços desproporcionalmente longos e articulados esticando para os lados
  c.line(50, 52, 20, 62, "q"); c.line(20, 62, 8, 48, "Q")
  c.ellipse(20, 62, 3, 3, "V") // junta de boneca brilhante
  c.line(76, 52, 106, 62, "q"); c.line(106, 62, 118, 48, "Q")
  c.ellipse(106, 62, 3, 3, "V")

  // Rosto da Rainha Empoeirada: maquiagem borrada/escorrida
  c.ellipse(63, 34, 13, 12, "q")
  c.ellipse(62, 32, 10, 9, "Q")
  // Olhos com rímel roxo/preto escorrido pelas bochechas
  c.ellipse(58, 32, 3, 2, "k"); c.px(58, 32, "e")
  c.ellipse(68, 32, 3, 2, "k"); c.px(68, 32, "e")
  c.line(58, 34, 57, 41, "k"); c.line(59, 34, 59, 39, "w") // lágrima de maquiagem borrada
  c.line(68, 34, 69, 41, "k"); c.line(67, 34, 67, 39, "w")
  // Boca com batom vermelho/rosa borrado e costura
  c.rect(59, 39, 9, 3, "e")
  c.line(58, 40, 69, 40, "k")

  // Coroa de plástico dourado/rosa QUEBRADA no topo da cabeça
  c.poly([51, 22, 54, 10, 60, 18, 63, 8, 67, 19, 73, 14, 75, 22], "G")
  c.line(52, 22, 74, 22, "e")
  c.px(63, 12, "V"); c.px(56, 16, "l") // joia de plástico
}]

sprite("boss_sock", { w: 94, h: 94, outline: "k" }, ...bossMeiaEsquecida())
sprite("boss_robot", { w: 110, h: 110, outline: "k" }, ...bossRoboEsquecido())
sprite("boss_queen", { w: 126, h: 126, outline: "k" }, ...bossRainhaEmpoeirada())

sheet("bosses_sheet", ["boss_sock", "boss_robot", "boss_queen"], { cols: 3, pad: 4 })
