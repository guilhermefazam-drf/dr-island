# Página «Gestão» dentro da ilha — desenho

Estado: **rascunho para revisão** (2026-10-30). Substitui a janela «Gestão» da Fase 1; a spec de origem é `2026-10-30-jira-manager-charts-design.md` (os dados, o cálculo e o leitor mantêm-se).

## Objetivo

Levar os gráficos de manager para **dentro da ilha**, no mesmo estilo visual dela, sem janela à parte. A ilha passa a ter **duas páginas**: a 1.ª é a de hoje (Claude, PRs, sprint, Jira…); a 2.ª é a «Gestão». Passa-se de uma para a outra com o **deslize horizontal de dois dedos no touchpad**.

## Decisões já tomadas

- **Gesto:** deslize horizontal com dois dedos; a ilha acompanha o dedo. Só com a ilha aberta e o rato por cima dela.
- **Seletores dentro da ilha** (opção 2 do utilizador): chips para a stream, setas ‹ › para a sprint, botão pontos/tasks. Cabem na página porque a ilha só recebe cliques e scroll quando está aberta.
- **Abordagem A:** duas páginas dentro de `IslandView`, com a «Gestão» como composição própria (cabeçalho + área de gráficos). Sem segundo sistema de layout por blocos.
- **UI:** estilo da ilha, escrita e revista segundo a skill `swiftui-pro` (uma view por ficheiro, estado e animações simples, acessibilidade, «Reduzir movimento», sem dependências externas, sem APIs só do macOS 27 sem verificação).
- **Jira só de leitura**, como sempre. Nada de novo faz pedidos que não passem por `JiraClient.get`.

## Fora de âmbito (agora)

Gráficos 2, 3 e 4 (fluxo, bugs, velocity), cache em disco, exportação, definições de layout da página 2, exportar/importar a app.

## Mecânica das páginas

- `IslandState` ganha `page: IslandPage` (`.overview`, `.management`) e `pageDrag: Double` (−1…1, a fração da largura arrastada durante o gesto).
- O conteúdo das duas páginas fica lado a lado num contentor com `offset` ligado a `page` e `pageDrag`. A largura é `layoutWidth`; a altura anima entre a da página 1 e a da página 2 com a mola que a ilha já usa ao redimensionar.
- **Monitor de scroll** (AppKit, `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)`), em `IslandController`: só atua com a ilha aberta e o rato dentro dela; consome o evento só quando o movimento é horizontal dominante. Acumula `scrollingDeltaX` durante a fase do gesto e, ao terminar, decide a página. O sentido segue o «deslize natural» do sistema (`isDirectionInvertedFromDevice`).
- **Decisão (lógica pura, em `DrIslandCore`, testada):** `PageSwipe.target(from page:, translation:, velocity:, width:) -> IslandPage`: passa de página se a translação passar 1/3 da largura **ou** a velocidade passar um limiar; nunca sai de `.overview … .management`; vertical dominante nunca decide.
- **Indicador:** dois pontos no fundo da ilha; clicar num muda para essa página. Rótulos de VoiceOver: «Página 1 de 2: Resumo», «Página 2 de 2: Gestão».
- **Teclado:** ← e → com a ilha aberta (monitor local de `keyDown`), mudam de página.
- **«Reduzir movimento»:** a troca de página é um fade e não um deslize (como o resto da ilha).
- **Ao fechar a ilha**, `page` volta a `.overview`.

## Página «Gestão» (estilo da ilha)

Estrutura vertical, com a largura de `layoutWidth`, no mesmo padding e raios dos cartões da ilha (`blockCard`):

1. **Cabeçalho** (uma linha, ~28 pt): chips de stream (cápsulas pequenas, texto `caption2`; a ativa com a cor da marca, as outras `.white.opacity(0.12)`), à direita as setas ‹ › com o nome da sprint no meio e o botão **Pontos | Tasks** (cápsula dupla). Se houver mais streams do que cabem, os chips deslizam na horizontal.
2. **Cartão do burndown** (`blockCard`): título «Burndown» com o ícone da ilha; gráfico (Swift Charts, ~150 pt de altura): linha **real** a azul da marca, linha **ideal** tracejada cinzenta, linha de **scope** fina, marca do **«hoje»**; eixos mínimos em `caption2`.
3. **Linha de resumo** (etiquetas como `RowTag`): «62% concluído», «3 bloqueadas», e o prazo («acaba em 4 dias», «acaba hoje», «fora de prazo» a vermelho, «fechada»). Quando faltam pontos: etiqueta âmbar «N de M tasks sem pontos» que, ao clicar, muda para tasks.
4. **Estados**, com `ListNote` e o mesmo tom da ilha: «A carregar…», erro (mantém o último gráfico), «Sem boards», «Sem sprints neste board», «Sem tasks nesta sprint», «Sem pontos nesta sprint», e a mensagem de falta de permissão nos boards.

Todos os textos em português europeu; fontes e cores só de `Brand`/tipos já usados na ilha, sem inventar paleta. Cada elemento tem rótulo de acessibilidade; o gráfico tem um `accessibilityLabel` com o resumo e `accessibilityChartDescriptor`.

## Dados e ciclo de vida

- O `ManagementStore` (Fase 1) mantém-se, e passa a ser criado em `AppDelegate` e entregue a `IslandController`, como os outros stores. Não há janela.
- Carrega-se **só quando a página 2 é mostrada** (primeira vez), e volta a atualizar de cada vez que se entra nela, exceto se já estiver a carregar; mantém o gráfico atual enquanto atualiza. A seleção de stream e de sprint **mantém-se** entre aberturas (o `start()` já a preserva).
- O botão do card «Sprint atual» passa a mudar para a página 2 (em vez de abrir a janela).

## O que sai

`ManagementView.swift` (a janela), o item «Gestão…» do menu, `AppDelegate.managementWindow`/`openManagement` e a notificação `.openManagement` (substituída por uma ação direta ao `IslandState`). A lógica de formatação do resumo (prazo, pontos em falta) passa para tipos pequenos testáveis em Core ou para views próprias; nada se perde.

## Erros e casos limite

- Gesto com a ilha a abrir/fechar a meio, ou com o rato a sair: cancela e volta à página atual.
- Touchpad com scroll com inércia: o fim do gesto só conta uma vez; eventos de inércia depois de decidir são ignorados.
- Ilha sem Jira configurado: a página 2 mostra «Configura o Jira nas Definições», e o gesto continua a funcionar.
- Ecrãs sem notch (pílula de 150 pt) e vários ecrãs: cada `IslandInstance` tem o seu estado de página.
- Rato por cima da ilha mas sem a ilha aberta: o gesto não faz nada.

## Testes

- Core: `PageSwipe.target` (limiar de distância, velocidade, vertical dominante, limites das páginas, sentido invertido), mais o que for movido para Core (texto do prazo, contagem de pontos em falta) com os casos da Fase 1.
- A UI não tem testes automáticos; fica uma **lista de verificação manual** no plano (gesto, pontos, teclado, Reduzir movimento, VoiceOver, vários ecrãs, ilha a fechar a meio do gesto).
- Os testes da Fase 1 (cálculo, leitor, store) continuam a passar.

## Ordem de construção (para o plano)

1. Mecânica das páginas: `IslandPage`/estado, `PageSwipe` (Core, testado), monitor de scroll e teclado, indicador, animação — com a página 2 ainda vazia.
2. Página «Gestão» no estilo da ilha (cabeçalho, cartão do burndown, resumo, estados) ligada ao `ManagementStore`; botão do card «Sprint atual».
3. Remover a janela e o menu, atualizar `docs/funcionalidades.md` (fora dos commits da branch, como pedido) e a página «Acerca».

## A validar no plano

- Que o `scrollWheel` chega ao monitor local com a ilha aberta (o painel é uma `NSPanel` que ignora o rato quando fechada) e que `hasPreciseScrollingDeltas`/`phase` distinguem bem o início, o fim e a inércia do gesto.
- Altura da página 2 com vários chips em duas linhas e com 1, 2 ou 3 streams.
- Que o `Chart` se desenha bem sobre o fundo preto da ilha (contraste das linhas e dos eixos).
