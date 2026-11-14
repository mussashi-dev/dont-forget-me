# DON'T FORGET ME — Fluxo de Revisão com ChatGPT

Este documento define o processo oficial para auditorias e revisões técnicas e de design de **DON'T FORGET ME** conduzidas pelo ChatGPT como revisor independente.

---

## 1. Modelo de Colaboração

```text
[ Antigravity ] ──(1. Implementa & Testa local)──> [ Branch / PR ]
                                                          │
                                                    (2. Push GitHub)
                                                          │
                                                          ▼
[ ChatGPT ] <───────(3. Conexão GitHub / PR)─────── [ Repositório Oficial ]
     │
 (4. Auditoria de Código, Gameplay e Narrativa)
     │
     ▼
[ Relatório de Revisão ] ──(5. Ajustes e Correções)──> [ Antigravity ]
```

- **Antigravity:** Engenheiro e arquiteto executor (implementação em Godot 4.x, criação de branches, testes, commits).
- **GitHub:** Fonte da verdade e repositório central.
- **ChatGPT:** Revisor sênior e auditor independente (validação técnica, de design e narrativa).

---

## 2. Métodos de Conexão do ChatGPT ao Repositório

### Método 1: Integração Oficial ChatGPT + GitHub (Recomendado)
1. No ChatGPT (Web / Plus / Team), acesse **Configurações (Settings) > Conexões / Aplicativos Conectados (Connected Apps)**.
2. Conecte sua conta do GitHub (`mussashi-dev`).
3. Autorize o acesso ao repositório `dont-forget-me` (apenas leitura ou acesso aos repositórios selecionados).
4. Em qualquer conversa de revisão, mencione o repositório ou cole a URL da branch/pull request para o ChatGPT inspecionar diretamente o código real.

### Método 2: Revisão via Pull Request / Git Diff (Alternativo)
1. O Antigravity publica a branch na origem (ex: `gameplay` ou `feature/mecanica-x`) e abre um Pull Request.
2. O usuário compartilha o diff ou os links dos arquivos modificados com o ChatGPT.
3. O ChatGPT realiza a análise baseando-se no diff e nos arquivos reais.

---

## 3. Rubrica de Revisão Obrigatória

Ao solicitar uma revisão ao ChatGPT, utilize o checklist das três áreas principais:

### 3.1. Gameplay & Design
- **Movimentação e Game Feel:** Suavidade do top-down, aceleração, atrito, colisões nos pés e escala (1 m = ~18-19 px).
- **Combate & Habilidades:** Janelas de hitbox/hurtbox, cooldowns de dash, sinergia entre ataque físico (Pablita) e sônico (Pipop).
- **Inimigos & Chefes:** Lógica das máquinas de estado, telégrafo de ataques, balanceamento de dificuldade e respeito à arena.
- **Progressão & Encartes:** Sistema de encartes, capacidade compartilhada e respeito às especificações de design.

### 3.2. Narrativa & Coerência
- **Fidelidade ao GDD:** Manutenção dos temas de memória, apego e objetos esquecidos.
- **Consistência de Personagens:** Voz de Pablita, Pipop (personagem único) e Chopp.
- **Progressão Espacial:** Quarto de Pablita como área sem retorno até vencer o chefe; conexões narrativas entre fases.

### 3.3. Engenharia & GDScript
- **Tipagem Estática:** Todas as variáveis, parâmetros e retornos com tipagem explícita (`var x: float = 0.0`).
- **Arquitetura Godot 4.x:** Sinais para cima, chamadas diretas para baixo. Sem referências cíclicas ou vazamentos de nós.
- **Performance:** Sem alocações pesadas em `_process` ou `_physics_process`.
- **Compatibilidade Android:** Resolução 640x360 com canvas_items, suporte a toque / botões virtuais.

---

## 4. Template de Prompt para Envio ao ChatGPT

```text
Olá, ChatGPT. Atue como auditor técnico sênior e revisor de design do jogo "DON'T FORGET ME" (Godot 4.7.2, GDScript).
O repositório oficial é: https://github.com/mussashi-dev/dont-forget-me
Branch/PR para revisão: [INSERIR BRANCH OU LINK DO PR]

Arquivos modificados:
- [LISTAR ARQUIVOS]

Por favor, revise o código real e me apresente:
1. Problemas de lógica, bugs potenciais ou regressões em GDScript.
2. Riscos de performance ou arquitetura Godot 4.x.
3. Alinhamento com as convenções do projeto (README.md e documentation/).
4. Apontamentos acionáveis para o Antigravity corrigir.
```
