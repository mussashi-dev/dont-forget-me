// HUD Mobile — Ícones de Ataque Físico (Manopla do Pipop Rosa) e Ataque Sonoro (Ondas Roxas) + Slots de Capacidade (Bíblia de Direção de Arte - Passo 4)
// Baseado na estética 'melancolia aconchegante' (cozy-melancholy) em pixel art top-down.

pal({
  k: "#280b21",                                                             // contorno escuro da UI
  // Botão Físico: Manopla felpuda rosa-choque do Pipop com coração remendado
  p: "#f668ba", P: "#ff99d8", q: "#ffd4ef", d: "#bf3487", D: "#7d1b57",     // pelagem rosa da manopla
  H: "#ff2a85", x: "#1c0615", B: "#9a96a4", s: "#d4d0dc",                   // coração quebrado e curativo cinza
  // Botão Sonoro: Ondas sonoras concêntricas roxas e rosa-neon
  v: "#a844ff", V: "#dfa6ff", u: "#5c1b99", M: "#331254",                   // ondas sonoras roxas e fundo do botão
  // Slots de capacidade simples e retratos
  e: "#f25287", n: "#140610", L: "#9e2b6c", T: "#f2e8b6", m: "#5e1137",
})

// 1. Botão de Ataque Físico (32x32): Ícone da Manopla felpuda do Pipop (Rosa)
sprite("hud_btn_physical_gauntlet", { w: 30, h: 30, outline: "k" }, (c) => {
  // Base circular acolchoada escura
  c.ellipse(15, 15, 13, 13, "D")
  c.ellipse(15, 15, 11, 11, "d")
  // Punho/manopla felpuda rosa-choque com nós dos dedos e tufos espetados
  c.ellipse(15, 16, 8, 7, "p")
  c.ellipse(14, 14, 6, 5, "P")
  // 4 dedos fechados de soco no topo
  c.ellipse(9, 10, 2, 3, "p"); c.px(9, 9, "q")
  c.ellipse(13, 9, 2, 3, "P"); c.px(13, 8, "q")
  c.ellipse(17, 9, 2, 3, "P"); c.px(17, 8, "q")
  c.ellipse(21, 10, 2, 3, "p"); c.px(21, 9, "q")
  // Polegar fechado à frente
  c.ellipse(11, 14, 4, 2, "P")
  // Coração quebrado e remendado nas costas da manopla
  c.rect(13, 16, 5, 4, "H")
  c.px(15, 16, "x"); c.px(15, 17, "x"); c.px(15, 19, "x")
  c.rect(13, 17, 5, 2, "B"); c.px(14, 17, "s"); c.px(16, 18, "s")
})

// 2. Botão de Ataque Sonoro (32x32): Ícone de Ondas Sonoras Concêntricas (Roxo)
sprite("hud_btn_sonic_waves", { w: 30, h: 30, outline: "k" }, (c) => {
  // Base circular roxa profunda
  c.ellipse(15, 15, 13, 13, "M")
  c.ellipse(15, 15, 11, 11, "u")
  // Núcleo emissor à esquerda + 3 arcos concêntricos roxos/rosa avançando
  c.ellipse(8, 15, 3, 3, "p")
  c.ellipse(8, 15, 2, 2, "V")
  // Arco 1 (interno)
  c.line(12, 11, 14, 15, "V"); c.line(14, 15, 12, 19, "V")
  // Arco 2 (médio)
  c.line(16, 8, 19, 15, "v"); c.line(19, 15, 16, 22, "v")
  c.px(17, 11, "V"); c.px(18, 15, "V"); c.px(17, 19, "V")
  // Arco 3 (externo amplo)
  c.line(20, 6, 24, 15, "p"); c.line(24, 15, 20, 24, "p")
  c.px(22, 10, "V"); c.px(23, 15, "V"); c.px(22, 20, "V")
})

// 3. Slots simples da Barra de Capacidade (12x12) — Ativo (Rosa/Coração) e Vazio (Roxo Escuro)
sprite("hud_slot_filled", { w: 12, h: 12, outline: "k" }, (c) => {
  c.rect(1, 1, 10, 10, "d")
  c.rect(2, 2, 8, 8, "H")
  c.px(3, 3, "P"); c.px(4, 3, "P")
  c.rect(4, 5, 4, 2, "B") // detalhe de curativo cinza
})

sprite("hud_slot_empty", { w: 12, h: 12, outline: "k" }, (c) => {
  c.rect(1, 1, 10, 10, "M")
  c.rect(2, 2, 8, 8, "u")
})

sheet("hud_mobile_icons", [
  "hud_btn_physical_gauntlet",
  "hud_btn_sonic_waves",
  "hud_slot_filled",
  "hud_slot_empty"
], { cols: 4, pad: 2 })
