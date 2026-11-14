# DON'T FORGET ME — Documentação Técnica

Uma aventura e ação top-down sobre memória, apego e objetos esquecidos desenvolvida em **Godot 4.7.2 (Mobile renderer)**.

---

## 1. Visão Geral e Versão da Engine

- **Engine:** Godot Engine 4.7.2-stable (Mobile Renderer / Vulkan Mobile)
- **Linguagem:** GDScript com tipagem estática obrigatória
- **Resolução Base:** 640x360 (Viewport), escala 1280x720 (Janela), modo `canvas_items` com snap pixel-perfect
- **Público / Alvo:** Mobile (Android) e Desktop

---

## 2. Estrutura do Projeto

```text
jogo_pablita/
├── .agents/          # Regras, agentes e skills do time de IA (Antigravity/GameForge)
├── assets/           # Texturas, sprites, áudios e referências aprovadas
│   ├── _reference/   # Fichas de referência visual estritas (não modificar)
│   ├── characters/   # Pablita, Pipop, Chopp, inimigos
│   └── ui/           # Elementos gráficos da interface
├── autoload/         # Singletons globais (GameManager.gd)
├── documentation/    # Guias técnicos específicos e convenções de arte
├── resources/        # Recursos de dados (.tres, SpriteFrames)
├── scenes/           # Cenas do Godot (.tscn)
│   ├── characters/   # Pablita, Pipop
│   ├── enemies/      # Inimigos comuns e chefes
│   ├── environments/ # Cenários e tilesets
│   ├── levels/       # Níveis / Fases (ex: vertical slice)
│   └── ui/           # Telas de menu, HUD e diálogos
├── scripts/          # Código-fonte GDScript (.gd) organizado por domínio
│   ├── characters/   # Controladores de jogador e companheiro
│   ├── enemies/      # Máquinas de estado e IA de inimigos
│   ├── levels/       # Gerenciadores de sala/fase
│   ├── objects/      # Itens interativos, colecionáveis
│   ├── systems/      # Sistemas de combate, memória, encartes
│   └── ui/           # Controladores de HUD e menus
├── tests/            # Testes automatizados e cenas de validação técnica
└── tools/            # Scripts utilitários de pipeline e ferramentas CLI
```

---

## 3. Como Executar o Jogo

### Pelo Godot Editor
1. Abra o Godot 4.7.2.
2. Importe o projeto selecionando o arquivo `project.godot`.
3. Pressione `F5` para executar a cena principal (`res://scenes/ui/main_menu.tscn`) ou `F6` para executar a cena aberta.

### Pela Linha de Comando (CLI)
```powershell
# Execução direta da cena principal:
godot --path .

# Ou executando um nível de teste específico:
godot --path . res://scenes/levels/level_vertical_slice.tscn
```

---

## 4. Como Executar Testes

O projeto contém scripts de validação de fatia vertical e mecânicas em `tests/`:
```powershell
# Execução headless da suíte de teste da fatia vertical:
godot --headless --path . -s res://tests/test_vertical_slice.gd
```

---

## 5. Organização dos Sistemas e Decisões de Arquitetura

1. **GameManager (`autoload/game_manager.gd`):**
   - Singleton central que orquestra estados de jogo (menu, gameplay, pausa, cutscene).
   - Gerencia transições de cena, eventos globais e persistência de dados.

2. **Movimentação Top-Down e Colisão:**
   - Escala base: 1 metro = ~18–19 px.
   - Pablita: quadro 32x32, colisor nos pés (10x6). Camada de colisão 1 (Jogador), máscara 14 (Sólidos, Inimigos, Interativos).
   - Sombras são nós `Polygon2D` independentes, desacopladas dos sprites.

3. **Combate e Companheiro (Pipop):**
   - Ataque físico de Pablita e ataque sônico/grunhido emitido por Pipop.
   - Capacidade compartilhada e encartes acoplados à progressão narrativa.

4. **Diretrizes de Código (AGENTS.md):**
   - Tipagem estática em todas as variáveis e métodos.
   - Sinais para comunicação ascendente (nó filho -> pai).
   - Chamadas de método diretas para comunicação descendente (nó pai -> filho).
   - Parâmetros ajustáveis exportados com `@export`.

---

## 6. Pipeline de Assets e Dependências Externas

- **PixelLab MCP:** Integração para criação de sprites, animações e tilesets.
- **claude-pxl:** Pipeline de arte procedimental (`tools/pxl/`).
- **Lovable MCP:** Ferramenta auxiliar para referências visuais e prototipação de UI.
- **Importação de Texturas:** Filtro `Nearest` (padrão 0) para manter o pixel art nítido.

---

## 7. Instruções de Build / Exportação

As predefinições de exportação são configuradas para a plataforma **Android** e **Windows Desktop**:
```powershell
# Exemplo de exportação headless (quando configurado export_presets.cfg):
godot --headless --export-release "Android" builds/android/dont_forget_me.apk
```
