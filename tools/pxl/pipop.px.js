// Pipop (Fuggler) — TOP-DOWN + ANIMAÇÕES COMPLETAS (Bíblia de Direção de Arte v1.1 - Seção 3.2)
// Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down.
// Trava de Estilo Absoluta:
// - Bola de pelo rosa-choque, felpudo e espetado.
// - Olhos com pálpebras caídas, íris/esclera rosa/vermelhos com pupilas pequenas pretas (olhar cansado/bizarro).
// - Boca larga e aberta com dentes humanos/esquisitos (superiores e inferiores) e gengivas expostas.
// - Grande coração rosa-choque no peito/barriga com linha preta quebrada (rachadura) no meio e curativo retangular cinza costurado.
// Quadro base 24x24 (22x22 + contorno). Pivô nos pés: offset Godot = Vector2(-12, -23).

pal({
  k: "#380d2a",                                                             // contorno profundo e rachadura preta/vinho
  p: "#f668ba", P: "#ff8cd6", q: "#ffc6ea", d: "#c43a8e", D: "#8f2265",     // pelagem rosa-choque: base / luz / brilho / sombra / sombra funda
  H: "#ff2a85", I: "#ff7ec0", x: "#1c0615",                                 // coração rosa-choque / brilho / rachadura preta no meio
  B: "#9a96a4", b: "#686472", s: "#d4d0dc",                                 // curativo retangular cinza costurado (base / costura / ponto claro)
  e: "#f25287", E: "#c92a5a", n: "#140610", L: "#9e2b6c",                   // olhos rosa/vermelhos / pálpebra caída cansada / pupila pequena preta
  m: "#5e1137", g: "#b82860", T: "#f2e8b6", t: "#cbb87a",                   // boca funda / gengivas expostas / dentes claros e amarelados
  v: "#b44cff", V: "#7a22cc", u: "#ff66cc",                                 // ondas sonoras (roxo neon / roxo escuro / rosa vibrante)
  c: "#b8824c", C: "#85582c", z: "#d9a973",                                 // caixa de papelão
  r: "#7a3b6e", w: "#f5eef7", y: "#ffea59", a: "#ff2e4c",                   // capa livro / páginas e brilho / faísca / raiva
})

const furBlob = (c, cx, cy, rx, ry) => {
  c.ellipse(cx, cy, rx, ry, "d")
  c.ellipse(cx - 1, cy - 1, rx - 1, ry - 1, "p")
  c.ellipse(cx - 2, cy - 2, Math.max(2, rx - 4), Math.max(2, ry - 3), "P")
  c.px(cx - 3, cy - ry + 2, "q"); c.px(cx - 2, cy - ry + 2, "q")
}

// Pelos espetados ao redor da silhueta
const tufts = (c, cx, cy, rx, ry, from = 165, to = 375) => {
  for (let a = from; a <= to; a += 15) {
    const rad = a * Math.PI / 180
    const x1 = Math.round(cx + Math.cos(rad) * (rx + 0.8))
    const y1 = Math.round(cy + Math.sin(rad) * (ry + 0.8))
    c.px(x1, y1, (a / 15) % 2 ? "P" : "p")
    const x2 = Math.round(cx + Math.cos(rad) * (rx + 1.8))
    const y2 = Math.round(cy + Math.sin(rad) * (ry + 1.8))
    c.px(x2, y2, "d")
  }
}

// Grande coração rosa-choque quebrado no meio (linha preta x) e remendado com curativo retangular cinza (B/b/s)
const heart = (c, x, y, small = false, vibrate = 0) => {
  const vx = vibrate
  const rows = small
    ? ["HH.H", "HHHH", ".HH.", "..H."]
    : [".HH.HH.", "HHHHHHH", "HHHHHHH", ".HHHHH.", "..HHH..", "...H..."]
  rows.forEach((r, j) => [...r].forEach((ch, i) => {
    if (ch === "H") c.px(x + i + vx, y + j, "H")
  }))
  if (!small) {
    c.px(x + 1 + vx, y + 1, "I"); c.px(x + 5 + vx, y + 1, "I")
    // Linha preta quebrada (rachadura) no meio
    c.px(x + 3 + vx, y + 0, "x")
    c.px(x + 3 + vx, y + 1, "x")
    c.px(x + 2 + vx, y + 2, "x")
    c.px(x + 3 + vx, y + 3, "x")
    c.px(x + 3 + vx, y + 4, "x")
    // Curativo retangular cinza costurado sobre a rachadura
    c.rect(x + 1 + vx, y + 2, 5, 2, "B")
    c.px(x + 1 + vx, y + 2, "b"); c.px(x + 5 + vx, y + 2, "b")
    c.px(x + 2 + vx, y + 2, "s"); c.px(x + 4 + vx, y + 3, "s")
  } else {
    c.px(x + 2 + vx, y + 0, "x"); c.px(x + 2 + vx, y + 1, "x")
    c.rect(x + 1 + vx, y + 1, 3, 1, "B")
  }
}

const footP = (c, x, dy) => {
  c.ellipse(x, 22 + dy, 3, 2, "d")
  c.ellipse(x - 0.5, 21.5 + dy, 2, 1, "p")
}

const armL = (c, x, y) => {
  c.ellipse(x, y, 2, 3, "d")
  c.ellipse(x + 0.5, y - 0.5, 1, 2, "p")
}

// Olhos rosa/vermelhos cansados com pálpebras caídas e pupilas pretas pequenas
const tiredEyes = (c, by, wide = false, lookShift = 0) => {
  if (wide) {
    // Olhos arregalados (Choque / Dano / Grunhido)
    c.rect(5, 5 + by, 4, 3, "e"); c.rect(14, 5 + by, 4, 3, "e")
    c.px(5, 5 + by, "E"); c.px(14, 5 + by, "E")
    c.px(6 + lookShift, 6 + by, "n"); c.px(15 + lookShift, 6 + by, "n")
  } else {
    // Pálpebras caídas pesadas no topo + esclera/íris rosa cansada + pupila preta
    c.rect(5, 5 + by, 4, 1, "L"); c.rect(14, 5 + by, 4, 1, "L")
    c.rect(5, 6 + by, 4, 2, "e"); c.rect(14, 6 + by, 4, 2, "e")
    c.px(5, 6 + by, "E"); c.px(8, 6 + by, "E"); c.px(14, 6 + by, "E"); c.px(17, 6 + by, "E")
    c.px(6 + lookShift, 7 + by, "n"); c.px(7 + lookShift, 7 + by, "n")
    c.px(15 + lookShift, 7 + by, "n"); c.px(16 + lookShift, 7 + by, "n")
    c.rect(5, 8 + by, 4, 1, "d"); c.rect(14, 8 + by, 4, 1, "d")
  }
}

// Boca larga com gengivas expostas e dentes humanos/esquisitos (superiores e inferiores)
const fugglerMouth = (c, by, roar = false) => {
  if (roar) {
    c.rect(6, 8 + by, 11, 5, "m")
    c.rect(6, 8 + by, 11, 1, "g")
    c.rect(6, 12 + by, 11, 1, "g")
    // Dentes superiores e inferiores bem visíveis
    c.px(7, 9 + by, "T"); c.px(9, 9 + by, "t"); c.px(11, 9 + by, "T"); c.px(13, 9 + by, "t"); c.px(15, 9 + by, "T")
    c.px(8, 11 + by, "t"); c.px(10, 11 + by, "T"); c.px(12, 11 + by, "t"); c.px(14, 11 + by, "T")
  } else {
    c.rect(7, 9 + by, 9, 3, "m")
    c.rect(7, 9 + by, 9, 1, "g")
    c.px(8, 9 + by, "T"); c.px(10, 9 + by, "t"); c.px(11, 9 + by, "T"); c.px(13, 9 + by, "T"); c.px(14, 9 + by, "t")
    c.px(9, 11 + by, "t"); c.px(11, 11 + by, "T"); c.px(13, 11 + by, "t")
  }
}

const south = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0
  const fl = ph === 0 ? 1 : (ph === 2 ? -1 : 0)
  return [(c) => {
    footP(c, 7, fl); footP(c, 15, -fl)
    armL(c, 2, 16 + by + fl); armL(c, 20, 16 + by - fl)
    furBlob(c, 11, 16 + by, 7, 6)
    c.rect(5, 12 + by, 13, 1, "D")
    heart(c, 8, 13 + by)
    furBlob(c, 11, 6 + by, 9, 6); tufts(c, 11, 6 + by, 9, 6)
    tiredEyes(c, by, false, 0)
    fugglerMouth(c, by, false)
  }]
}

const north = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0
  const fl = ph === 0 ? 1 : (ph === 2 ? -1 : 0)
  return [(c) => {
    footP(c, 7, -fl); footP(c, 15, fl)
    armL(c, 2, 16 + by - fl); armL(c, 20, 16 + by + fl)
    furBlob(c, 11, 16 + by, 7, 6)
    c.rect(5, 12 + by, 13, 1, "D")
    furBlob(c, 11, 7 + by, 9, 7); tufts(c, 11, 7 + by, 9, 7)
    for (const [x, y] of [[6, 4], [10, 2], [14, 6], [8, 9], [13, 10], [17, 4]]) {
      c.px(x, y + by, "q"); c.px(x + 1, y + by + 1, "d")
    }
  }]
}

const east = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0
  const sw = ph === 0 ? 2 : (ph === 2 ? -2 : 0)
  return [(c) => {
    footP(c, 8 - sw, -1); footP(c, 13 + sw, 0)
    furBlob(c, 10, 16 + by, 7, 6)
    c.rect(4, 12 + by, 12, 1, "D")
    heart(c, 11, 13 + by, true)
    armL(c, 11 + sw, 16 + by)
    furBlob(c, 12, 6 + by, 9, 6); tufts(c, 12, 6 + by, 9, 6)
    c.rect(15, 5 + by, 4, 1, "L")
    c.rect(15, 6 + by, 4, 2, "e"); c.px(15, 6 + by, "E")
    c.px(17, 7 + by, "n"); c.px(18, 7 + by, "n")
    c.rect(15, 8 + by, 4, 1, "d")
    c.rect(16, 9 + by, 5, 3, "m"); c.rect(16, 9 + by, 5, 1, "g")
    c.px(17, 9 + by, "T"); c.px(19, 9 + by, "t"); c.px(20, 11 + by, "T")
  }]
}

// Animação extra: Manifestação Sonora (Grunhido) — boca escancarada, coração vibrando, arcos roxo/rosa
const sonicRoar = (ph) => {
  const vib = (ph % 2 === 0) ? -1 : 1
  return [(c) => {
    footP(c, 7, 0); footP(c, 15, 0)
    armL(c, 2, 15); armL(c, 20, 15)
    furBlob(c, 11, 16, 7, 6)
    heart(c, 8, 14, false, vib)
    furBlob(c, 11, 6, 9, 6); tufts(c, 11, 6, 9, 6)
    tiredEyes(c, -1, true, 0)
    fugglerMouth(c, -1, true)
    // Arcos sonoros concêntricos em roxo e rosa
    if (ph >= 1) {
      c.px(21, 7, "u"); c.px(22, 8, "v"); c.px(22, 9, "v"); c.px(22, 10, "v"); c.px(21, 11, "u")
    }
    if (ph >= 2) {
      c.px(1, 7, "u"); c.px(0, 8, "v"); c.px(0, 9, "v"); c.px(0, 10, "v"); c.px(1, 11, "u")
    }
  }]
}

// Animações extras da Spritesheet: Defesa, Dano, Segurando Caixa, Lendo Livro, Dormindo
const defensePose = () => [(c) => {
  footP(c, 8, 0); footP(c, 14, 0)
  furBlob(c, 11, 17, 7, 5)
  heart(c, 8, 15)
  furBlob(c, 11, 9, 9, 6); tufts(c, 11, 9, 9, 6)
  tiredEyes(c, 3, false, 0)
  armL(c, 6, 15); armL(c, 16, 15)
  c.px(1, 11, "u"); c.px(1, 12, "v"); c.px(21, 11, "u"); c.px(21, 12, "v")
}]

const hurtPose = () => [(c) => {
  footP(c, 6, -1); footP(c, 16, 1)
  armL(c, 2, 13); armL(c, 20, 13)
  furBlob(c, 11, 16, 7, 6)
  heart(c, 8, 13)
  furBlob(c, 11, 6, 9, 6); tufts(c, 11, 6, 9, 6)
  tiredEyes(c, 0, true, 0)
  fugglerMouth(c, 0, true)
  // Exclamação e faíscas
  c.px(10, 0, "y"); c.px(10, 1, "y"); c.px(13, 0, "y"); c.px(13, 1, "y")
}]

const holdBoxPose = () => [(c) => {
  footP(c, 7, 0); footP(c, 15, 0)
  furBlob(c, 11, 16, 7, 6)
  furBlob(c, 11, 6, 9, 6); tufts(c, 11, 6, 9, 6)
  tiredEyes(c, 0, false, 0)
  fugglerMouth(c, 0, false)
  // Caixa de papelão à frente do peito
  c.rect(6, 13, 10, 7, "c")
  c.rect(6, 13, 10, 2, "z")
  c.rect(6, 15, 10, 1, "C")
  c.px(11, 14, "C"); c.px(11, 16, "C")
  armL(c, 5, 16); armL(c, 17, 16)
}]

const readBookPose = () => [(c) => {
  footP(c, 7, 0); footP(c, 15, 0)
  furBlob(c, 11, 16, 7, 6)
  furBlob(c, 11, 6, 9, 6); tufts(c, 11, 6, 9, 6)
  tiredEyes(c, 0, false, 0)
  // Livro aberto nas mãos
  c.rect(6, 13, 10, 6, "r")
  c.rect(7, 13, 4, 5, "w"); c.rect(12, 13, 4, 5, "w")
  c.rect(11, 13, 1, 6, "k")
  armL(c, 5, 16); armL(c, 17, 16)
}]

const sleepPose = () => [(c) => {
  // Deitado dormindo com Zzz
  furBlob(c, 9, 17, 7, 5); tufts(c, 9, 17, 7, 5)
  furBlob(c, 16, 18, 5, 4)
  heart(c, 13, 16, true)
  c.rect(5, 16, 4, 1, "L")
  c.px(7, 18, "T"); c.px(9, 18, "t")
  // Zzz
  c.px(15, 9, "q"); c.px(16, 9, "q"); c.px(15, 10, "q")
  c.px(18, 6, "u"); c.px(19, 6, "u"); c.px(18, 7, "u")
}]

const mk = (name, items, opts = {}) => sprite(name, { w: 22, h: 24, outline: "k", ...opts }, ...items)

for (let p = 0; p < 4; p++) {
  mk(`pip_south_${p}`, south(p))
  mk(`pip_north_${p}`, north(p))
  mk(`pip_east_${p}`, east(p))
  sprite(`pip_west_${p}`, { base: `pip_east_${p}`, flip: "x" })
}

for (let p = 0; p < 3; p++) {
  mk(`pip_sonic_${p}`, sonicRoar(p))
}
mk("pip_defense", defensePose())
mk("pip_hurt", hurtPose())
mk("pip_box", holdBoxPose())
mk("pip_book", readBookPose())
mk("pip_sleep", sleepPose())

sheet("pipop_topdown", [
  "pip_south_*", "pip_north_*", "pip_east_*", "pip_west_*",
  "pip_sonic_*", "pip_defense", "pip_hurt", "pip_box", "pip_book", "pip_sleep"
], { cols: 4, pad: 1 })
