// Quarto da Pablita — Tileset de chão (32x32 sem costura) + Móveis separados para colisão e Y-Sort
// Inspirado nas pranchas de referência do Quarto (tons quentes: madeira, rosa queimado, abajur âmbar e Luffy).

pal({
  k: "#241326", // contorno quente escuro
  s: "#3b2121", // madeira escura / sombra profunda
  m: "#5c3422", // estrutura de madeira escura
  M: "#824c34", // madeira média de móveis
  h: "#b06e48", // brilho de madeira
  // Piso quente do quarto
  w: "#8f5638", // base tábua quente
  W: "#a66946", // destaque tábua quente
  d: "#6e3f26", // junta suave de tábua
  // Tecidos (colcha patchwork, tapete, caminha, cadeira)
  r: "#9e5270", // rosa queimado base
  R: "#b86888", // rosa claro
  p: "#7a3b58", // rosa escuro / sombra tecido
  c: "#f2e6d8", // creme travesseiro / papel
  C: "#d6c3b3", // sombra creme
  g: "#d9a76a", // dourado suave / estrelinhas / puxador latão
  // Luz do abajur e monitor
  A: "#ffd97d", // âmbar brilhante
  O: "#ffa940", // âmbar laranja
  e: "#4b8ec2", // tela azul suave notebook
  E: "#87c9f5", // brilho tela
  // Vegetação e livros
  v: "#467554", // folha escura
  V: "#6ba368", // folha clara
  b: "#487aa8", // livro azul
  y: "#c95b6c", // livro vermelho-rosa
  // Cachorrinho Luffy (caramelo)
  l: "#c9823b", // pelo caramelo
  L: "#f5d096", // focinho/patas claras
  f: "#8c5220", // orelhas e sombreado caramelo
  q: "#7a485c", // borda caminha
  Q: "#9e6378", // almofada caminha
})

// ==================== PISO SEAMLESS DO QUARTO (32x32) ====================

sprite("tile_bedroom_wood_0", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "w")
  // Tábuas horizontais contínuas sem borda externa quadrada
  for (let y = 0; y < 32; y += 8) {
    c.hline(0, y, 32, "W")
    c.hline(0, y + 7, 32, "d")
  }
  // Emendas escalonadas das tábuas
  c.vline(11, 1, 6, "d")
  c.vline(25, 9, 6, "d")
  c.vline(6, 17, 6, "d")
  c.vline(19, 25, 6, "d")
  // Veios sutis da madeira
  c.hline(3, 3, 5, "W"); c.hline(17, 4, 7, "d")
  c.hline(9, 11, 8, "W"); c.hline(14, 19, 9, "W")
  c.hline(2, 27, 6, "d"); c.hline(23, 28, 5, "W")
})

sprite("tile_bedroom_wood_1", { w: 32, h: 32 }, (c) => {
  c.rect(0, 0, 32, 32, "w")
  for (let y = 0; y < 32; y += 8) {
    c.hline(0, y, 32, "W")
    c.hline(0, y + 7, 32, "d")
  }
  c.vline(21, 1, 6, "d")
  c.vline(9, 9, 6, "d")
  c.vline(28, 17, 6, "d")
  c.vline(13, 25, 6, "d")
  // Pequenos nós e veios quentes para quebrar repetição
  c.px(7, 4, "d"); c.px(8, 4, "d"); c.hline(13, 3, 6, "W")
  c.hline(15, 12, 8, "d"); c.hline(4, 20, 7, "W")
  c.px(24, 20, "d"); c.hline(17, 27, 7, "W")
})

// ==================== TAPETE E CAMINHA (NÍVEL DO CHÃO) ====================

sprite("furn_rug", { w: 96, h: 72 }, (c) => {
  // Base acolhedora rosa queimado com bordas douradas e franjas laterais
  c.rect(4, 2, 88, 68, "k")
  c.rect(5, 3, 86, 66, "p")
  c.rect(7, 5, 82, 62, "r")
  c.box(9, 7, 78, 58, "g")
  c.rect(11, 9, 74, 54, "R")
  c.rect(15, 13, 66, 46, "r")
  // Franjas esquerda e direita
  for (let y = 6; y < 66; y += 4) {
    c.rect(2, y, 2, 2, "c")
    c.rect(92, y, 2, 2, "c")
  }
  // Estrelinhas bordadas no tapete
  const stars = [[26, 22], [68, 21], [48, 36], [28, 50], [66, 49]]
  for (const [sx, sy] of stars) {
    c.px(sx, sy, "A")
    c.px(sx - 1, sy, "g"); c.px(sx + 1, sy, "g")
    c.px(sx, sy - 1, "g"); c.px(sx, sy + 1, "g")
  }
})

sprite("furn_dog_bed", { w: 32, h: 28 }, (c) => {
  c.ellipse(16, 15, 15, 12, "k")
  c.ellipse(16, 14, 14, 11, "q")
  c.ellipse(16, 14, 11, 8, "Q")
  c.ellipse(16, 15, 8, 5, "p")
  // Ossinho bordado/brinquedo na borda da caminha
  c.hline(12, 20, 8, "c")
  c.px(11, 19, "c"); c.px(11, 21, "c")
  c.px(20, 19, "c"); c.px(20, 21, "c")
})

// ==================== CACHORRINHO LUFFY (24x24) ====================

sprite("luffy_dog", { w: 24, h: 24 }, (c) => {
  // Corpo deitado fofinho no estilo top-down 3/4
  c.ellipse(12, 16, 8, 5, "k")
  c.ellipse(12, 16, 7, 4, "f")
  c.ellipse(12, 15, 6, 3, "l")
  // Rabiho levantado à direita
  c.rect(18, 12, 2, 3, "l"); c.px(19, 11, "L")
  // Patinhas frontais descansando
  c.rect(7, 18, 3, 2, "L"); c.rect(14, 18, 3, 2, "L")
  // Cabeça arredondada e orelhas caídas
  c.ellipse(11, 10, 6, 5, "k")
  c.ellipse(6, 11, 2, 4, "f")
  c.ellipse(16, 11, 2, 4, "f")
  c.ellipse(11, 10, 5, 4, "l")
  // Focinho creme, olhinhos e coleira vermelha
  c.ellipse(11, 12, 3, 2, "L")
  c.px(11, 11, "k") // nariz
  c.px(9, 9, "k"); c.px(13, 9, "k") // olhos
  c.px(9, 8, "L"); c.px(13, 8, "L") // sobrancelha caramelo clara
  c.hline(8, 14, 6, "y") // coleira fofa
  c.px(11, 15, "A") // medalhinha
})

// ==================== MÓVEIS COM COLISÃO E Y-SORT ====================

sprite("furn_bed", { w: 64, h: 96 }, (c) => {
  // Cabeceira e estrutura de madeira
  c.rect(4, 2, 56, 92, "k")
  c.rect(5, 3, 54, 14, "m")
  c.rect(7, 4, 50, 10, "M")
  c.hline(7, 4, 50, "h")
  // Postes da cabeceira
  c.rect(5, 2, 6, 16, "s"); c.rect(6, 3, 4, 12, "M")
  c.rect(53, 2, 6, 16, "s"); c.rect(54, 3, 4, 12, "M")
  // Moldura lateral e pé da cama
  c.rect(5, 16, 54, 72, "m")
  c.rect(5, 86, 54, 8, "s"); c.rect(7, 87, 50, 5, "m")
  // Colchão + lençol creme dobrado
  c.rect(8, 16, 48, 22, "C")
  c.rect(9, 17, 46, 16, "c")
  // Travesseiro fofo
  c.rect(14, 14, 36, 14, "k")
  c.rect(15, 15, 34, 12, "C")
  c.rect(16, 15, 32, 9, "c")
  // Colcha patchwork rosa e ameixa
  c.rect(8, 34, 48, 52, "p")
  for (let row = 0; row < 4; row++) {
    for (let col = 0; col < 4; col++) {
      const x = 9 + col * 11
      const y = 36 + row * 12
      const shade = (row + col) % 2 === 0 ? "R" : "r"
      c.rect(x, y, 10, 11, shade)
      c.hline(x, y, 10, (row + col) % 2 === 0 ? "c" : "R")
    }
  }
  c.hline(8, 34, 48, "c")
  // Coelhinho de pelúcia pequeno sobre a colcha
  c.rect(42, 42, 7, 8, "k"); c.rect(43, 43, 5, 6, "c")
  c.rect(43, 39, 2, 4, "c"); c.rect(46, 39, 2, 4, "c")
  c.px(44, 45, "k"); c.px(46, 45, "k"); c.px(45, 47, "r")
})

sprite("furn_nightstand", { w: 28, h: 32 }, (c) => {
  // Criado-mudo de madeira + abajur aceso
  c.rect(2, 10, 24, 21, "k")
  c.rect(3, 11, 22, 9, "M"); c.hline(3, 11, 22, "h")
  c.rect(3, 20, 22, 10, "m")
  c.box(5, 21, 18, 7, "s"); c.rect(6, 22, 16, 5, "M")
  c.rect(12, 24, 4, 2, "g")
  // Abajur quente sobre o tampo
  c.rect(12, 12, 4, 4, "s")
  c.rect(8, 3, 12, 9, "k")
  c.rect(9, 4, 10, 7, "O")
  c.rect(10, 5, 8, 5, "A")
  c.hline(11, 4, 6, "c")
})

sprite("furn_desk", { w: 76, h: 40 }, (c) => {
  // Escrivaninha com notebook, fones e livros
  c.rect(2, 2, 72, 26, "k")
  c.rect(3, 3, 70, 16, "M"); c.hline(3, 3, 70, "h")
  c.rect(3, 19, 70, 8, "m")
  // Pernas e gavetas laterais
  c.rect(4, 20, 16, 7, "s"); c.rect(6, 21, 12, 4, "M"); c.px(11, 23, "g")
  c.rect(56, 20, 16, 7, "s"); c.rect(58, 21, 12, 4, "M"); c.px(63, 23, "g")
  // Notebook aberto no centro
  c.rect(26, 4, 20, 12, "k")
  c.rect(27, 5, 18, 8, "e")
  c.rect(28, 6, 12, 5, "E")
  c.rect(25, 14, 22, 4, "C")
  // Livros empilhados à esquerda e luminária/caderno à direita
  c.rect(8, 6, 11, 8, "b"); c.hline(9, 7, 9, "c")
  c.rect(10, 9, 10, 6, "y")
  c.rect(52, 6, 12, 9, "c"); c.hline(54, 8, 8, "r")
  c.rect(65, 5, 5, 5, "O"); c.rect(66, 6, 3, 3, "A")
  // Cadeira estofada rosa encaixada na frente
  c.rect(28, 24, 18, 14, "k")
  c.rect(29, 25, 16, 10, "r")
  c.rect(31, 26, 12, 6, "R")
  c.rect(29, 34, 16, 3, "p")
})

sprite("furn_wardrobe", { w: 32, h: 96 }, (c) => {
  // Guarda-roupa alto visto de cima/frente, com duas portas altas e puxadores de latão
  c.rect(2, 2, 28, 92, "k")
  // Tampo superior em perspectiva 3/4
  c.rect(3, 3, 26, 14, "h")
  c.rect(4, 5, 24, 10, "M")
  // Corpo frontal com duas portas
  c.rect(3, 17, 26, 70, "m")
  c.rect(5, 19, 10, 65, "M")
  c.rect(17, 19, 10, 65, "M")
  c.hline(5, 19, 10, "h"); c.hline(17, 19, 10, "h")
  c.box(6, 22, 8, 58, "m")
  c.box(18, 22, 8, 58, "m")
  // Puxadores dourados
  c.rect(13, 46, 2, 5, "g")
  c.rect(17, 46, 2, 5, "g")
  // Rodapé inferior
  c.rect(3, 87, 26, 6, "s")
})

sprite("furn_bookshelf", { w: 36, h: 32 }, (c) => {
  // Estante baixa com livros coloridos e vasinho de planta no topo
  c.rect(2, 4, 32, 26, "k")
  c.rect(3, 5, 30, 8, "M"); c.hline(3, 5, 30, "h")
  c.rect(3, 13, 30, 16, "s")
  // Prateleira de cima (lombadas de livros)
  c.rect(5, 14, 4, 7, "y"); c.rect(9, 15, 3, 6, "b"); c.rect(12, 14, 4, 7, "r")
  c.rect(16, 15, 4, 6, "g"); c.rect(22, 14, 4, 7, "b"); c.rect(26, 15, 5, 6, "c")
  // Prateleira de baixo
  c.rect(5, 22, 30 - 4, 6, "m")
  c.rect(7, 22, 5, 5, "c"); c.rect(13, 22, 4, 5, "y"); c.rect(20, 22, 7, 5, "b")
  // Vasinho verde sobre a estante
  c.rect(24, 2, 6, 5, "h"); c.rect(25, 3, 4, 3, "m")
  c.ellipse(27, 2, 4, 2, "v"); c.px(26, 1, "V"); c.px(28, 1, "V")
})
