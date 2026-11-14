# Direção de arte — abertura do quarto

## Intenção visual

A Fase 1 começa com uma pequena cena de despertar. O quarto precisa ser lido como um espaço íntimo e familiar antes que o jogador possa explorar. A iluminação inicial é fria, azul-arroxeada e baixa; depois do ruído atrás do guarda-roupa, a luz quente revela os tons de madeira, o tapete e os objetos pessoais.

O Esquecido não deve ser percebido como uma segunda sala adjacente. Antes de afastar o guarda-roupa, o espaço à direita permanece preto absoluto, mesmo quando a câmera ou Pablita se aproximam da divisória.

## Fonte visual

O projeto usa a referência existente, sem alterá-la:

`assets/_reference/concept_pack/02_ambientes/Quarto/quarto_pablita_luz_acesa_e_apagada.jpg`

As duas metades são recortadas em `AtlasTexture` na cena `scenes/levels/level_01_intro.tscn`:
- Estado aceso: região `Rect2(45, 68, 775, 752)`.
- Estado apagado: região `Rect2(910, 68, 775, 752)`.

As duas camadas compartilham posição `(139, 210)` e escala `(0.297, 0.297)`. A camada apagada inicia visível; a camada acesa inicia transparente e é revelada pelo controlador.

## Sequência de abertura

1. Pablita aparece sobre a cama, deitada, com movimento e ações bloqueados.
2. Após uma breve pausa, um rangido vindo do guarda-roupa chama a atenção.
3. A câmera enquadra a origem do ruído sem mostrar o Esquecido.
4. A camada de luz acesa aparece gradualmente.
5. Pablita desperta, levanta-se e recebe o controle do jogador.

A flag persistente `f1_bedroom_wakeup_done` impede que a cena de despertar seja repetida ao recarregar a Fase 1. A flag de abertura do guarda-roupa existente (`f1_wardrobe_checked`) continua sendo a condição que remove a máscara do Esquecido.

## Proteção e revelação do Esquecido

`EsquecidoOcclusion` é um `Polygon2D` preto, desenhado com prioridade sobre personagens e objetos do mundo. Sua área cobre o lado direito da arena, de `x=254` a `x=760`, entre `y=24` e `y=396`.

Quando o gatilho existente do guarda-roupa inicia a cinemática do roubo do CD, a máscara perde opacidade em uma transição de 1,15 s. Nenhuma geometria de fase, rota, posição de inimigos ou regra de progressão foi alterada nesta intervenção.

## Regras para próximos passes de arte

- Preservar a referência original em `assets/_reference`; criar derivados em pastas de produção quando forem necessários.
- Manter o filtro de textura Nearest e a leitura de pixel art na resolução base de 640×360.
- Usar a luz quente do quarto como contraste visual com os tons violetas frios do Esquecido.
- Evitar que NPCs, pickups, portais, partículas ou efeitos do Esquecido atravessem a máscara antes da revelação.
- Não redesenhar layout ou colisões para acomodar os assets: adaptar a apresentação visual às dimensões atuais da sala.
