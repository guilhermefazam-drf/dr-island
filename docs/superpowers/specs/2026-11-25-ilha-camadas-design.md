# Ilha «Camadas», temas e modo compacto: desenho

Estado: **rascunho para revisão** (2026-11-25). A proposta visual (laboratório interativo) está em `docs/design/ilha-redesign.html`. Lá aparecem o layout atual, a direção A · Camadas e a direção B · Bento.

## Porquê

A ilha está compacta, plana e com ar datado. A hierarquia de texto quase não existe, os cartões mal se veem, há informação repetida e o conteúdo é cortado a meio sem aviso. O utilizador quer três coisas: uma ilha mais moderna, poder trocar de tema e ter um modo compacto com o mesmo desenho em ponto pequeno. Tudo isto tem de funcionar com 1, 2 e 3 colunas.

## Decisões já tomadas (utilizador)

- **Direção A · Camadas** nesta versão.
- **B · Bento fica para a próxima versão**, como opção de layout nas Definições. Esta versão não implementa nada do Bento, mas a arquitetura tem de o permitir sem refazer nada (ver «Preparar o Bento»).
- **Temas:** é possível trocar de tema.
- **Modo compacto:** o layout Camadas numa versão mais pequena.
- **Colunas:** 1, 2 e 3 continuam suportadas. O exemplo de referência é o de 2 colunas.

## Decisões minhas (para confirmar)

- **O aspeto atual não fica como opção «Clássico».** O Camadas substitui-o. Com o tema Grafite e a densidade Normal fica o mais próximo possível da ilha de hoje. Manter dois renderizadores dobraria o trabalho em cada bloco.
- **O compacto liga-se à mão:** interruptor em «Aparência» e atalho de teclado opcional. Nada de ligar sozinho por tamanho de ecrã ou número de blocos, para a ilha não mudar de aspeto sem explicação.
- **Quatro temas:** Grafite (por defeito), Meia-noite, Aurora e Claro.
- **A mini ilha de alertas, o anel do notch e a dock** mantêm a forma atual. Só passam a usar as cores do tema (acento e semânticas). A base da mini ilha continua preta, porque cresce a partir do notch físico.
- **Página «Gestão»:** passa a usar os tokens de tema e de densidade nos cartões, mas mantém a composição. Os gráficos usam o acento do tema em vez de `Brand.blue`.
- **Avisos e Resumo do dia** continuam a ser dois `IslandBlock` (a configuração guardada não muda). Enquanto o Resumo do dia está ativo, o bloco Avisos esconde-se, porque mostraria as mesmas linhas.
- **Abas** só no card Git (Meus / A rever) e no card Jira (Tasks / Aprovações). O card Sprint mantém as duas sublistas empilhadas: as aprovações da sprint são o que se quer ver logo.
- **A aba escolhida vale só para a sessão** (vive em `IslandState`). Uma aba que não está aberta e tem alterações por ver mostra um ponto na cor do aviso mais forte e o número de alterações. Ao abrir a ilha, se a aba ativa não tiver alterações por ver e a outra tiver, o card muda para essa outra. A tag continua na linha. A regra de escolha da aba é uma função pura no Core, com testes.

## Objetivos

1. Hierarquia clara com três tamanhos de texto: título de card, conteúdo e meta.
2. Todos os blocos no mesmo card (o Claude incluído), com um cabeçalho comum: tile colorido da fonte, título, contador e acessório à direita.
3. Uma cor por fonte, usada no tile, no ponto do aviso e no pulso de alerta: Claude laranja, Git roxo, Jira/Sprint acento do tema, Foco verde, Música rosa e Avisos âmbar.
4. Estado com texto em vez de ícones sem legenda. As siglas passam a avatares.
5. Nada é cortado sem indicação. Uma coluna acima do limite de altura desvanece no fundo e continua a dar scroll, como hoje.
6. Estados vazios curtos, numa só linha (música parada, «A carregar…», «Sem PRs abertos»).
7. Temas e densidade aplicados por tokens, nunca por cores ou medidas dentro das views.

## Não-objetivos

- Layout Bento, faixa de KPIs, música na dock.
- Mudar dados, pedidos, alertas ou regras de negócio. O Jira continua só de leitura (`JiraClient.get`) e nada nesta mudança faz pedidos novos.
- Mudar a forma ou as animações de abrir e fechar a ilha.
- Temas personalizados pelo utilizador (cores livres).

## Anti-objetivos (seria um falhanço mesmo a funcionar)

- O **Compacto** ficar mais alto do que a ilha de hoje com os mesmos blocos e linhas (medido com o snapshot da configuração de referência: 2 colunas, os blocos atuais do utilizador). O Normal pode crescer: o utilizador queixa-se de que a ilha de hoje é compacta demais. O Compacto é o modo para quem quer densidade.
- O tema Claro não se fundir com o notch físico.
- Perder alguma informação que hoje está visível: CI, conflitos, review, threads por resolver, draft, dono, mutes, tags de alteração.
- Partir o cálculo de alturas. A janela da ilha é dimensionada a partir de `height(of:)`, por isso uma altura errada corta ou deixa espaço vazio.

## Restrições

- macOS 14+, SwiftUI/AppKit, sem dependências externas. Uma view por ficheiro e a skill `swiftui-pro` para as views novas.
- A lógica testável vai para `DrIslandCore` (Swift Testing).
- A largura máxima do painel (`IslandLayout.panelSize`, `IslandLayoutConfig.maxWidth`) define a janela. As larguras novas têm de caber nesse máximo ou o máximo tem de ser recalculado.
- Respeitar «Reduzir movimento» (já existe), «Reduzir transparência» e «Aumentar contraste».
- O texto visível fica em português europeu. O código e os comentários ficam em inglês.
- `docs/funcionalidades.md` é atualizado.

## Abordagens consideradas

| Abordagem | Como | Troca |
|---|---|---|
| **1. Tokens e métricas via Environment (escolhida)** | `IslandTheme` e `IslandMetrics` são valores puros no Core. A app injeta-os com `EnvironmentKey` e as views leem `@Environment(\.islandTheme)` / `\.islandMetrics`. `IslandView.height(of:)` usa as mesmas métricas. | Obriga a tocar em todas as views uma vez. Em troca, o Bento e os temas novos ficam baratos e as alturas são testáveis. |
| 2. Restyle direto, sem tokens | Mudar cores e tamanhos dentro de cada view, com um `if compact` aqui e ali. | Mais rápido no início, mas os temas e o compacto multiplicam os `if`, e o Bento obrigaria a repetir tudo. |
| 3. Segundo conjunto de views «v2» ao lado das atuais | Novas `…BlockV2` e um switch de layout. | Permite manter o «Clássico», mas duplica cada bloco e cada correção futura. Não se justifica sem «Clássico». |

## Desenho

### Tokens de tema (`DrIslandCore/IslandTheme.swift`)

`IslandTheme` é um enum `grafite | meiaNoite | aurora | claro`, `Codable` e com `rawValue` para guardar em UserDefaults. Expõe uma `IslandPalette` com cores em RGBA (`ThemeColor`, sem SwiftUI, para ser testável):

- `base` (fundo da ilha, que pode ser gradiente: lista de paragens), `collar` (cor do topo junto ao notch), `surface`, `surfaceRaised`, `border`, `highlight` (o brilho de 1 pt no topo do card), `text`, `textSecondary`, `textTertiary`, `accent`.
- Semânticas: `green`, `amber`, `red`, `purple`, `pink`, `orange`.
- `source(_ block: IslandBlock) -> ThemeColor`: a cor de cada fonte.
- `isLight: Bool`. No Claro: base clara com uma **faixa preta no topo**, com a altura do cabeçalho (`collarHeight` vem das métricas), e o texto do cabeçalho claro.

Os valores de partida são os do laboratório (`docs/design/ilha-redesign.html`, blocos `.island[data-itheme=…]`). O Grafite reproduz as cores de hoje: base preta, superfície em branco a ~5,5%, verde/âmbar/vermelho de `Brand`, acento `Brand.blue`.

Na app, uma extensão converte `ThemeColor` em `Color`. Com «Aumentar contraste», as superfícies e o texto secundário sobem um nível. Com «Reduzir transparência», as superfícies passam a opacas sobre a base.

`Brand.color(forFraction:)` passa a receber a paleta, para usar o verde/âmbar/vermelho do tema.

### Densidade e métricas (`DrIslandCore/IslandMetrics.swift`)

`IslandDensity` é um enum `regular | compact`. `IslandMetrics(density:)` é uma struct pura que substitui as constantes de `IslandLayout` que dependem da densidade:

| Métrica | Normal | Compacto |
|---|---|---|
| padding do card | 14 | 9 |
| espaço entre cards | 12 | 8 |
| raio do card | 18 | 12 |
| linha de lista | 34 (2 linhas) | 22 (1 linha) |
| cabeçalho de card | 26 | 20 |
| tile | 24 | 18 |
| texto: título / conteúdo / meta | 13 sb / 13 / 11,5 | 11,5 sb / 11,5 / 10,5 |
| anel do Claude | 84 | 52 |
| cabeçalho da ilha | 46 | 36 |
| largura base: 1 / 2 / 3 col. | 400 / 660 / 870 (iguais a hoje) | 340 / 560 / 740 |

`IslandLayout` mantém as medidas que não dependem da densidade (overshoot, mini ilha, splash) e passa a delegar as restantes. As alturas dos blocos (`height(of:)`) e as larguras (`IslandLayoutConfig.width`) passam a receber a densidade. `extraColumnWidth` continua a somar-se por coluna e mantém o significado de hoje. `maxWidth` e o tamanho do painel não mudam (o Normal com 3 colunas e o extra máximo continua a ser o maior caso).

**Valores na etapa 1:** `IslandMetrics.regular` começa com as medidas de hoje (linha 25, padding 10, título 20, raio 12…), para a etapa 1 ser igual píxel a píxel. A etapa 3 muda o `.regular` para a tabela acima, e a etapa 4 acrescenta o `.compact`. Não há conjunto «legado» separado.

**Testes (Core):** largura por colunas e densidade; altura de um card de lista para N linhas nas duas densidades; o compacto nunca é mais alto do que o Normal; `maxWidth` cobre todas as combinações.

### Injeção

`IslandView` lê `SettingsKey.islandTheme` e `SettingsKey.islandDensity` com `@AppStorage` e injeta `.environment(\.islandTheme, …)` e `.environment(\.islandMetrics, …)` no conteúdo. As views dos blocos deixam de usar `Color.white.opacity`, `.secondary`, `Brand.*` e `IslandLayout.prRowHeight`, e passam a ler o ambiente. O `IslandController` reage à mudança de definições como já faz (`UserDefaults.didChangeNotification` → `sync()`), o que redimensiona o painel.

### Componentes base (DrIsland)

- **`BlockCard`** substitui `blockCard(active:)`: fundo `surface`, borda `border`, brilho `highlight` em cima, raio e padding das métricas e sombra só no Claro. Com `active` (sprint em curso), a borda e o fundo levam o acento.
- **`CardHeader`** substitui `CardTitle`: tile (fundo na cor da fonte a 20% e ícone na cor da fonte), título, contador opcional (cápsula) e um slot de acessório à direita (abas, barra de sprint, «ver tudo», «reinicia em…»).
- **`SegmentedTabs`**: abas pequenas dentro do cabeçalho, com contador e ponto de «por ver».
- **`ListRow`**: estrutura comum às linhas de PR e de Jira (ícone de estado, chave mono, título, meta, trailing). No Normal tem duas linhas: título em cima e meta em baixo. No compacto tem só uma linha. Meta de um PR: `repositório · autor` (autor só nos «A rever») `· N threads`. Meta de uma task: `tipo · prioridade` ou `tipo · responsável` nas aprovações. São tudo campos que já existem no modelo.
- **`Pill`** substitui `RowTag`: cápsula com o fundo na cor a 18% e o texto na cor, com tamanho pelas métricas.
- **`Avatar`** substitui `OwnerTag`: círculo com as iniciais e uma cor estável derivada do nome (a função pura de cor vai para o Core e é testada). O nome completo fica no tooltip.
- **`ColumnFade`**: máscara no fundo de uma coluna com scroll, visível só quando há conteúdo abaixo.

Todas as views ficam em ficheiros próprios.

### Blocos no Camadas

- **Cabeçalho da ilha:** à esquerda o logo DF; no Normal, também «Bom dia · qua, 25 nov» (a saudação muda com a hora). À direita, «ao vivo» ou o estado offline, Gestão, atualizar e definições.
- **Claude:** passa a ter card. Cabeçalho com «reinicia em…». O anel (ou a barra, segundo `claudeGauge`) e as barras Sessão e Semana com valor à direita. A chip da previsão só aparece no Normal. O custo continua opcional.
- **Foco:** card de uma linha com tile, «Foco · ronda N de 4», os pontos das rondas (só no Normal), o tempo e o botão play.
- **Música:** card de uma linha com capa, título, artista e play. Sem nada a tocar, fica uma linha «Nada a tocar» com a altura de uma linha de lista.
- **Git:** cabeçalho «Pull requests» com as abas Meus / A rever. Sem reviews (`includeReviews` desligado), não há abas e o card mostra só «Meus». Mantém «+N mais» / «ver menos» e as mensagens de estado do gh.
- **Sprint:** cabeçalho com o nome da sprint e, à direita, «dia X/Y» com a barra. Sublistas «As minhas · N» e «Aprovações · N». O card ativo continua com o acento. Várias sprints (diretor) continuam empilhadas no mesmo card.
- **Jira:** cabeçalho com as abas Tasks / Aprovações (as aprovações fora da sprint).
- **Backlog, Histórico, Linha do tempo:** cabeçalho e card novos, conteúdo igual.
- **Avisos:** linha do tempo com ponto na cor da fonte, origem em versaletes, título e hora. Escondido enquanto o Resumo do dia estiver ativo.
- **Resumo do dia:** mesmo visual que os Avisos, com o cabeçalho «Desde ontem · HH:MM» e o botão «ok».
- **Dock:** mesma posição, com a superfície e a borda do tema. No Compacto, os ícones passam de 30 para 22 pt (a altura do dock entra nas métricas e em `maxHeight`).
- **Faixa preta do Claro:** com a altura do cabeçalho da ilha nas métricas (46 no Normal, 36 no Compacto).

### Colunas

- **1 coluna:** as abas são o que impede a altura de disparar. No cabeçalho da ilha, em 1 coluna e no compacto, fica só o logo e os ícones.
- **2 colunas:** o exemplo do laboratório.
- **3 colunas:** igual, com a terceira coluna. O cabeçalho ocupa a largura toda.
- **Sem divisória** de 1 pt entre colunas: os cards já dão a estrutura.
- **Limite de altura** igual ao de hoje (metade do ecrã). Acima dele, a coluna faz scroll e mostra o `ColumnFade`: só um desvanecimento, sem contagem «+N».

### Definições

Em «Aparência», nova secção no topo, **«Tema e tamanho»**:
- **Tema:** quatro miniaturas clicáveis (um retângulo com a base, um card e o acento de cada tema).
- **Tamanho:** controlo segmentado Normal | Compacto.
- **Atalho para alternar o tamanho:** usa o mesmo componente dos atalhos que já existem (`HotKeyOption`/`HotKeyManager`). Desligado por defeito.

Novas chaves em `SettingsKey`: `islandTheme` (por defeito `grafite`), `islandDensity` (`regular`), `densityHotKey`. Os valores por defeito vão para `Settings.registerDefaults()`. O texto de rodapé de «Layout» que fala em 400/660/870 pt é atualizado.

### Preparar o Bento (sem o implementar)

- `SettingsKey.islandStyle` **não** é criada agora. Fica anotado que o Bento entra como `islandStyle = camadas | bento`, com o seletor em «Tema e tamanho».
- Os componentes `BlockCard`, `CardHeader`, `ListRow`, `Pill` e `IslandMetrics` são os que o Bento vai usar. O `KPITile` não entra nesta versão.
- `IslandView` separa a composição das colunas (`CamadasLayout`) do cálculo de alturas, para um `BentoLayout` poder entrar ao lado.

### Snapshots e testes

- Novas variáveis de ambiente: `DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_COLUMNS` (sobrepõem as definições só nesse arranque), para gerar renders de todas as combinações com `DR_ISLAND_SNAPSHOT`.
- `DR_ISLAND_SNAPSHOT_DELAY` (segundos, 3 por defeito). Hoje o snapshot sai antes de o Jira carregar.
- Testes no Core: paleta (cada tema define todas as cores, contraste de `text` sobre `surface` ≥ 4,5:1 e de `textSecondary` ≥ 3:1), métricas e larguras, cor estável dos avatares, regra «Avisos escondido com Resumo ativo» (se for para o Core).

## Etapas de entrega

Cada etapa entra na `main` sozinha.

1. **Fundações** (sem mudança visual): `IslandTheme`, `IslandMetrics`, injeção, chaves de definições. As views passam a ler os tokens, com Grafite + Normal iguais a hoje. Snapshot antes e depois para comparar.
2. **Componentes base:** `BlockCard`, `CardHeader`, `SegmentedTabs`, `ListRow`, `Pill`, `Avatar`, `ColumnFade`.
3. **Camadas:** restyle de todos os blocos, abas, cabeçalho da ilha, estados vazios curtos, Avisos/Resumo e o fim da divisória.
4. **Compacto:** métricas compactas, controlo em «Aparência» e atalho.
5. **Temas:** Meia-noite, Aurora e Claro, as miniaturas em «Aparência», contraste e transparência.
6. **Acabamento:** variáveis de snapshot, página «Gestão» com tokens, `docs/funcionalidades.md` e README.

## Fica para quem constrói

- Os valores exatos das cores de cada tema (partir do laboratório e afinar com o contraste dos testes).
- Os nomes finais dos tipos, desde que fique um tipo por ficheiro.
- Como migrar as views para os tokens (por bloco ou por tipo de cor), desde que cada commit compile e mantenha Grafite + Normal iguais.
