// Pipop (Fuggler) — TOP-DOWN. Referência aprovada: corpo pequeno arredondado, pelagem rosa volumosa e desgrenhada,
// olhos caídos (pálpebras pesadas), boca larga com dentes amarelados irregulares, coração rosa partido e remendado no peito.
// Quadro 24x24 (22x22 + contorno). Pivô: contato com o chão = borda inferior da linha 22 (offset Godot = Vector2(-12, -23)).
pal({
  k: "#4a1238",
  p: "#f668ba", P: "#f98cc9", q: "#fcc4e2", d: "#c43a8e", D: "#9a2a70",   // pelagem: mid / luz / brilho / sombra / sombra funda
  H: "#d0207a", I: "#ff4aa0", x: "#7a1050", B: "#e8c3a8",                 // coração / brilho / rachadura / curativo
  w: "#f4eef0", n: "#2a1020", L: "#8a2a68",                               // olho / pupila / pálpebra
  m: "#6a1848", T: "#ece0a0", t: "#c9b870",                               // boca / dentes
})

const fuzz = (c, cx, cy, rx, ry, seedShift = 0) => {   // tufos soltos na borda superior
  for (let i = 0; i < 9; i++) {
    const a = (200 + i * 17 + seedShift) * Math.PI / 180 * 1.0
    const x = Math.round(cx + Math.cos(a + Math.PI) * (rx + 0.6)), y = Math.round(cy - Math.abs(Math.sin(a)) * (ry + 0.6))
    c.px(x, y, i % 2 ? "P" : "p")
  }
}
const furBlob = (c, cx, cy, rx, ry) => {
  c.ellipse(cx, cy, rx, ry, "d")
  c.ellipse(cx - 1, cy - 1, rx - 1, ry - 1, "p")
  c.ellipse(cx - 2, cy - 2, Math.max(2, rx - 4), Math.max(2, ry - 3), "P")
  c.px(cx - 3, cy - ry + 2, "q"); c.px(cx - 2, cy - ry + 2, "q"); c.px(cx - 4, cy - ry + 3, "q")
}
const heart = (c, x, y, small = false) => {   // (x,y) = canto sup. esq. de um coração 7x6 (coração partido remendado)
  const rows = small ? ["HH.H", "HHHH", ".HH.", "..H."] : [".HH.HH.", "HHHHHHH", "HHHHHHH", ".HHHHH.", "..HHH..", "...H..."]
  rows.forEach((r, j) => [...r].forEach((ch, i) => { if (ch === "H") c.px(x + i, y + j, "H") }))
  if (!small) { c.px(x + 1, y + 1, "I"); c.px(x + 5, y + 1, "I"); c.px(x + 3, y + 1, "x"); c.px(x + 3, y + 2, "x"); c.px(x + 2, y + 3, "x"); c.rect(x + 2, y + 2, 3, 1, "B"); c.px(x + 3, y + 2, "B") }
  else c.px(x + 1, y + 1, "I")
}
const footP = (c, x, dy) => { c.ellipse(x, 22 + dy, 3, 2, "d"); c.ellipse(x - 0.5, 21.5 + dy, 2, 1, "p") }
const tufts = (c, cx, cy, rx, ry, from = 180, to = 360) => {   // pelos soltos ao redor da cabeça
  for (let a = from; a <= to; a += 14) {
    const t = a * Math.PI / 180
    const x = Math.round(cx + Math.cos(t) * (rx + 1)), y = Math.round(cy + Math.sin(t) * (ry + 1))
    c.px(x, y, (a / 14) % 2 ? "P" : "p")
    c.px(Math.round(cx + Math.cos(t) * (rx + 2)), Math.round(cy + Math.sin(t) * (ry + 2)), "p")
  }
}
const armL = (c, x, y) => { c.ellipse(x, y, 2, 3, "d"); c.ellipse(x + 0.5, y - 0.5, 1, 2, "p") }

const south = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0, fl = ph === 0 ? 1 : (ph === 2 ? -1 : 0)
  return [(c) => {
    footP(c, 7, fl); footP(c, 15, -fl)
    armL(c, 2, 16 + by + fl); armL(c, 20, 16 + by - fl)
    furBlob(c, 11, 16 + by, 7, 6)
    c.rect(5, 12 + by, 13, 1, "D")
    heart(c, 8, 13 + by)
    furBlob(c, 11, 6 + by, 9, 6); tufts(c, 11, 6 + by, 9, 6)
    c.rect(5, 5 + by, 4, 1, "L"); c.rect(14, 5 + by, 4, 1, "L")
    c.rect(5, 6 + by, 4, 2, "w"); c.rect(14, 6 + by, 4, 2, "w")
    c.px(6, 7 + by, "n"); c.px(7, 7 + by, "n"); c.px(15, 7 + by, "n"); c.px(16, 7 + by, "n")
    c.rect(5, 8 + by, 4, 1, "d"); c.rect(14, 8 + by, 4, 1, "d")
    c.rect(7, 9 + by, 9, 3, "m"); c.px(8, 9 + by, "T"); c.px(10, 9 + by, "t"); c.px(11, 9 + by, "T"); c.px(13, 9 + by, "T"); c.px(14, 9 + by, "t"); c.px(9, 11 + by, "t"); c.px(12, 11 + by, "T")
  }]
}
const north = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0, fl = ph === 0 ? 1 : (ph === 2 ? -1 : 0)
  return [(c) => {
    footP(c, 7, -fl); footP(c, 15, fl)
    armL(c, 2, 16 + by - fl); armL(c, 20, 16 + by + fl)
    furBlob(c, 11, 16 + by, 7, 6)
    c.rect(5, 12 + by, 13, 1, "D")
    furBlob(c, 11, 7 + by, 9, 7); tufts(c, 11, 7 + by, 9, 7)
    for (const [x, y] of [[6, 4], [10, 2], [14, 6], [8, 9], [13, 10], [17, 4]]) { c.px(x, y + by, "q"); c.px(x + 1, y + by + 1, "d") }
  }]
}
const east = (ph) => {
  const by = (ph === 1 || ph === 3) ? -1 : 0, sw = ph === 0 ? 2 : (ph === 2 ? -2 : 0)
  return [(c) => {
    footP(c, 8 - sw, -1); footP(c, 13 + sw, 0)
    furBlob(c, 10, 16 + by, 7, 6)
    c.rect(4, 12 + by, 12, 1, "D")
    heart(c, 11, 13 + by, true)
    armL(c, 11 + sw, 16 + by)
    furBlob(c, 12, 6 + by, 9, 6); tufts(c, 12, 6 + by, 9, 6)
    c.rect(15, 5 + by, 4, 1, "L"); c.rect(15, 6 + by, 4, 2, "w"); c.px(17, 7 + by, "n"); c.px(18, 7 + by, "n"); c.rect(15, 8 + by, 4, 1, "d")
    c.rect(17, 9 + by, 5, 3, "m"); c.px(18, 9 + by, "T"); c.px(20, 9 + by, "t"); c.px(21, 11 + by, "T")
  }]
}
const mk = (name, items, opts = {}) => sprite(name, { w: 22, h: 24, outline: "k", ...opts }, ...items)
for (let p = 0; p < 4; p++) {
  mk(`pip_south_${p}`, south(p)); mk(`pip_north_${p}`, north(p)); mk(`pip_east_${p}`, east(p))
  sprite(`pip_west_${p}`, { base: `pip_east_${p}`, flip: "x" })
}
sheet("pipop_topdown", ["pip_south_*", "pip_north_*", "pip_east_*", "pip_west_*"], { cols: 4, pad: 1 })
