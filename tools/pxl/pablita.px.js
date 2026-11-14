// Pablita — TOP-DOWN (câmera alta). Fonte: folha de referência aprovada (cabelo ruivo-escuro cacheado enorme,
// suéter cinza-malva oversized, short off-white, meias brancas e tênis escuros).
// Perspectiva: topo do cabelo domina; rosto na parte baixa da cabeça (sul) ou lateral (leste/oeste); norte = só cabelo.
// Quadro final 32x32 (sem sombra no chão: a sombra é um nó separado no Godot).
// Pivô: contato com o chão = borda inferior da linha 29 (offset Godot = Vector2(-16, -30)).
pal({
  k: "#1a1220",
  a: "#2a0f12", b: "#4e1e1e", c: "#7e362a", d: "#a2523a", e: "#c7704a",  // cabelo: sombra → luz
  s: "#b07858", S: "#8a5a46", X: "#d09a76",                              // pele
  n: "#1a0e10", R: "#8a4a42",                                            // olho / boca
  g: "#9b929c", G: "#6e6670", f: "#b8afb9",                              // suéter
  w: "#dcd6d6", W: "#a39c9d",                                            // short
  h: "#ece8e8", j: "#4a4258", J: "#2e2838",                              // meia / tênis
})

// ---------- cacho: círculo sombreado ----------
const curl = (c, x, y, r) => {
  c.circ(x, y, r, "c")
  c.px(x - 1, y - r + 1, "d"); c.px(x, y - r + 1, "d"); c.px(x - r + 1, y - 1, "d"); c.px(x - r + 1, y, "d")
  c.px(x - 1, y - 1, "e")
  c.px(x + r - 1, y + 1, "b"); c.px(x + 1, y + r - 1, "b"); c.px(x, y + r - 1, "b"); c.px(x + r - 1, y, "b")
}
// massa de cabelo: base escura + anel de cachos (silhueta irregular) + cachos internos
const hair = (c, cx, cy, rx, ry, dy = 0, skip = null) => {
  c.ellipse(cx, cy + dy, rx, ry, "b")
  for (let a = 0; a < 360; a += 30) {
    if (skip && skip(a)) continue
    const t = a * Math.PI / 180
    curl(c, Math.round(cx + Math.cos(t) * (rx - 2.5)), Math.round(cy + dy + Math.sin(t) * (ry - 2.5)), 3)
  }
  for (let a = 15; a < 360; a += 60) {
    const t = a * Math.PI / 180
    curl(c, Math.round(cx + Math.cos(t) * (rx * 0.45)), Math.round(cy + dy + Math.sin(t) * (ry * 0.45)), 3)
  }
}

// ---------- pés (sul/norte): dy>0 = pé à frente, dy<0 = pé recuado ----------
const footV = (c, x, dy) => {
  if (dy >= 0) c.rect(x, 25, 3, 1 + dy, "s")
  c.rect(x, 26 + dy, 3, 1, "h")
  c.rect(x - 1, 27 + dy, 5, 2, "j"); c.rect(x - 1, 28 + dy, 5, 1, "J"); c.px(x + 1, 27 + dy, "h")
}
// ---------- pés (leste): x = posição, pé aponta para a direita ----------
const footE = (c, x, dy) => {
  c.rect(x + 1, 25, 3, 1, "s"); c.rect(x, 26 + dy, 4, 1, "h")
  c.rect(x, 27 + dy, 6, 2, "j"); c.rect(x, 28 + dy, 6, 1, "J"); c.px(x + 5, 27 + dy, "h")
}

// ---------- corpo (sul/norte) ----------
const bodyV = (c, by, hand) => {
  // manga esquerda/direita + mãos
  c.rect(4, 17 + by, 4, 6, "g"); c.rect(4, 17 + by, 1, 6, "f"); c.rect(4, 22 + by, 4, 1, "G")
  c.rect(22, 17 + by, 4, 6, "g"); c.rect(25, 17 + by, 1, 6, "G"); c.rect(22, 22 + by, 4, 1, "G")
  c.rect(4, 23 + by + hand, 2, 2, "s"); c.rect(24, 23 + by - hand, 2, 2, "s")
  // tronco oversized
  c.poly([8, 16 + by, 22, 16 + by, 23, 18 + by, 23, 23 + by, 7, 23 + by, 7, 18 + by], "g")
  c.rect(8, 17 + by, 2, 5, "f"); c.rect(21, 17 + by, 2, 6, "G"); c.rect(7, 22 + by, 16, 1, "G")
  c.px(14, 19 + by, "G"); c.px(15, 20 + by, "G"); c.px(16, 21 + by, "G")
  // short
  c.rect(9, 23, 12, 2, "w"); c.rect(9, 24, 12, 1, "W"); c.rect(19, 23, 2, 2, "W")
}

// ---------- SUL ----------
const south = (phase) => {
  const by = (phase === 1 || phase === 3) ? -1 : 0
  const fl = phase === 0 ? 1 : (phase === 2 ? -1 : 0)
  const hand = phase === 0 ? 1 : (phase === 2 ? -1 : 0)
  return [
    (c) => {
      footV(c, 10, fl); footV(c, 17, -fl)
      bodyV(c, by, hand)
      hair(c, 15, 8 + by, 12, 8, 0, (a) => a > 40 && a < 140)
      // rosto (maior e mais baixo na cabeça; mostra o queixo)
      c.ellipse(15, 12 + by, 7, 5, "s"); c.rect(9, 12 + by, 13, 3, "s")
      c.rect(8, 11 + by, 2, 4, "X"); c.rect(10, 16 + by, 10, 1, "S"); c.rect(20, 13 + by, 2, 3, "S")
      c.rect(11, 11 + by, 1, 2, "n"); c.rect(18, 11 + by, 1, 2, "n")
      c.px(11, 10 + by, "a"); c.px(12, 10 + by, "a"); c.px(18, 10 + by, "a"); c.px(19, 10 + by, "a")
      c.px(14, 15 + by, "R"); c.px(15, 15 + by, "R"); c.px(14, 17 + by, "S"); c.px(15, 17 + by, "S")
      // franja de cachos sobre a testa
      for (const x of [9, 13, 17, 21]) curl(c, x, 6 + by, 2)
      curl(c, 6, 13 + by, 3); curl(c, 24, 13 + by, 3); curl(c, 7, 17 + by, 2); curl(c, 23, 17 + by, 2)
    },
  ]
}
// ---------- NORTE ----------
const north = (phase) => {
  const by = (phase === 1 || phase === 3) ? -1 : 0
  const fl = phase === 0 ? 1 : (phase === 2 ? -1 : 0)
  const hand = phase === 0 ? 1 : (phase === 2 ? -1 : 0)
  return [
    (c) => {
      footV(c, 10, -fl); footV(c, 17, fl)
      bodyV(c, by, hand)
      c.ellipse(15, 18 + by, 9, 3, "b")                 // cabelo caindo nas costas
      hair(c, 15, 10 + by, 12, 10)
      for (const [x, y] of [[9, 18], [14, 19], [20, 18]]) curl(c, x, y + by, 3)
    },
  ]
}
// ---------- LESTE ----------
const east = (phase) => {
  const by = (phase === 1 || phase === 3) ? -1 : 0
  const sw = phase === 0 ? 3 : (phase === 2 ? -3 : 0)
  return [
    (c) => {
      footE(c, 8 - sw, -1); footE(c, 13 + sw, 0)
      // braço de trás + tronco + braço da frente
      c.rect(8, 18 + by, 3, 5, "G")
      c.poly([9, 16 + by, 20, 16 + by, 21, 18 + by, 21, 23 + by, 8, 23 + by, 8, 18 + by], "g")
      c.rect(9, 17 + by, 2, 5, "f"); c.rect(8, 22 + by, 13, 1, "G"); c.rect(19, 17 + by, 2, 6, "G")
      c.rect(12, 17 + by, 5, 6, "g"); c.rect(12, 17 + by, 1, 6, "f"); c.rect(12, 22 + by, 5, 1, "G"); c.rect(16, 17 + by, 1, 6, "G")
      c.rect(16 + (sw > 0 ? 1 : 0), 23 + by, 2, 2, "s")
      c.rect(9, 23, 11, 2, "w"); c.rect(9, 24, 11, 1, "W")
      hair(c, 13, 9 + by, 11, 9, 0, (a) => a < 40 || a > 320)
      // rosto de 3/4 virado para a direita
      c.ellipse(21, 12 + by, 5, 5, "s"); c.rect(17, 13 + by, 9, 3, "s"); c.rect(16, 11 + by, 2, 4, "X"); c.rect(18, 16 + by, 7, 1, "S")
      c.rect(22, 11 + by, 1, 2, "n"); c.px(21, 10 + by, "a"); c.px(22, 10 + by, "a"); c.px(26, 12 + by, "s"); c.px(25, 15 + by, "R")
      for (const [x, y] of [[18, 7], [22, 8]]) curl(c, x, y + by, 2)
      curl(c, 12, 14 + by, 3)
    },
  ]
}

const mk = (name, items, opts = {}) => sprite(name, { w: 30, h: 30, outline: "k", ...opts }, ...items)
for (let p = 0; p < 4; p++) {
  mk(`pab_south_${p}`, south(p))
  mk(`pab_north_${p}`, north(p))
  mk(`pab_east_${p}`, east(p))
  sprite(`pab_west_${p}`, { base: `pab_east_${p}`, flip: "x" })
}
sheet("pablita_topdown", ["pab_south_*", "pab_north_*", "pab_east_*", "pab_west_*"], { cols: 4, pad: 1 })
