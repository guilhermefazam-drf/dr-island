# Gráficos do Jira para managers — desenho

Estado: **rascunho para revisão** (2026-10-30). Ainda sem plano de implementação.

## Objetivo

Dar a quem gere uma equipa (managers, diretores com várias streams) uma janela «Gestão» com gráficos úteis tirados do Jira, para responder a quatro perguntas:

1. A sprint vai acabar a tempo?
2. Onde está o trabalho preso?
3. A qualidade está a piorar?
4. Como se compara esta sprint com as anteriores?

É sobre o **trabalho da equipa e das streams** (sprint, fluxo, bugs). Não é sobre a produtividade de pessoas individuais.

## Decisões já tomadas

- **Onde vive:** janela própria «Gestão», aberta pelo menu da barra e por um botão no card «Sprint atual». A ilha só mostra um resumo curto (ex.: «Sprint: 62% · 3 bloqueadas»). Os gráficos não são `IslandBlock`.
- **Unidade:** story points (campo «Story Points», `customfield_10008` neste Jira, descoberto por nome) **ou** número de tasks, com seletor na janela. Pontos por defeito; a janela avisa quando faltam pontos em muitas tasks («12 de 40 sem pontos»).
- **Fonte dos dados:** só a API documentada do Jira, com o cálculo feito na app (abordagem A). Nada de `greenhopper`/`sprintreport`.
- **Cache:** local, em disco, atrás de uma interface (`SprintMetricsCache`). Sem cache partilhada (nem gist nem repo).
- **Streams:** o seletor usa os boards já escolhidos em Definições → Jira (`jiraSprintBoards`); sem nenhum, os das sprints onde o utilizador teve tasks.
- **Só leitura:** o Jira nunca é alterado. Todos os pedidos passam por `JiraClient.get` (que recusa tudo o que não seja GET/HEAD).

## Fora de âmbito (agora)

- Exportar/importar os dados da app (cópia de segurança e restauro): sub-projeto à parte, mais tarde.
- Exportar os gráficos (CSV e PNG, com painel de guardar): passo 4 da ordem abaixo; ainda sem desenho detalhado.
- Cache partilhada entre managers.
- Produtividade por pessoa.

## Componentes

### 1. Leitor de métricas (`DrIslandCore`)
Pede ao Jira, em leitura:
- as sprints de um board: `GET /rest/agile/1.0/board/{id}/sprint` (estados `active` e `closed`, paginado);
- as tasks de uma sprint com histórico: `search/jql` com `expand=changelog`, paginando. O `changelog` vem truncado em tasks com muitas alterações, e nesses casos completa-se com `GET /rest/api/3/issue/{key}/changelog`;
- as categorias dos estados: `GET /rest/api/3/status`, para saber se um estado é «por fazer», «em curso» ou «feito».

Devolve um **modelo por sprint**: dados da sprint (id, nome, board, datas, estado) e, por task, chave, tipo, pontos, estado atual, flag, data de criação e de resolução e a lista datada de mudanças de estado, de sprint e de pontos.

### 2. Cálculo (`DrIslandCore`, puro)
Transforma o modelo nas séries dos gráficos. Cada série existe em pontos e em nº de tasks. Sem I/O, testado com JSON de exemplo.

### 3. Cache local (`DrIslandCore`)
`SprintMetricsCache` guarda em disco o modelo das sprints **fechadas** (imutáveis) e relê só a ativa. O formato é versionado: uma versão desconhecida descarta a cache em vez de falhar. A interface é pequena (ler/escrever por sprint) para poder trocar o armazenamento mais tarde.

### 4. Janela «Gestão» (`DrIsland`)
Swift Charts. Seletor de stream, de sprint (ou período), de unidade (pontos/tasks), e os quatro gráficos. Mostra de imediato o que há na cache, atualiza a sprint ativa em segundo plano, e recalcula. Se o Jira falhar, mostra a última cache com um aviso, como as outras fontes.

## Os quatro gráficos

### 1. Sprint (burndown)
- **Mostra:** o trabalho que falta por dia, contra a linha ideal (linear, em dias úteis, do escopo inicial a zero no fim planeado). Marca o «hoje» e o trabalho que entrou depois do início.
- **Cálculo:** para cada dia, soma os pontos (ou conta as tasks) que estavam na sprint nesse dia e ainda não estavam num estado da categoria «feito». A pertença à sprint e o estado em cada dia vêm das mudanças datadas do changelog; os pontos são os atuais, corrigidos pelas alterações do campo registadas no changelog.
- **Resumo:** «62% concluído · 3 bloqueadas · acaba em 4 dias». Bloqueadas = tasks com flag.
- **Caso limite:** sprint já passou do fim planeado mas não foi fechada (ex.: #18_Clínica): a linha continua para além do fim e o gráfico marca «fora de prazo».

### 2. Fluxo
- **Mostra:** quantas tasks (ou pontos) há em cada estado agora, o tempo mediano em cada estado (das tasks que já passaram por ele) e a lista das tasks com flag ou paradas há mais de N dias no mesmo estado.
- **Estados:** vêm como o Jira os devolve, agrupados nas três categorias. Workflows diferentes por projeto aparecem com os seus nomes.

### 3. Bugs
- **Mostra:** criados vs. resolvidos por semana (últimas 8), bugs abertos acumulados e tempo mediano até resolver, por stream.
- **Âmbito:** todos os bugs do(s) projeto(s) da stream, não só os da sprint. Bug = tipo classificado como bug (`JiraIssueKind.bug`, que já inclui «Problema»).

### 4. Velocity
- **Mostra:** por sprint fechada (últimas 6), planeado no início contra concluído no fim, com a média.
- **Definições:** «planeado» = o que estava na sprint no instante do início; o que entrou depois conta à parte («adicionado»). «Concluído» = em estado da categoria «feito» no fim.

## Erros e casos limite

- Task sem pontos conta como 0 em pontos; o aviso de pontos em falta aparece quando passa um limiar (a definir no plano, p. ex. 20%).
- Sprint sem tasks, ou sem datas: o gráfico mostra o estado vazio em vez de falhar.
- Changelog incompleto ou com campos desconhecidos: as mudanças que não se entendem ignoram-se; o gráfico mostra o resto.
- 429 / sem rede / token inválido: mensagens e recuo como no `JiraStore`; a cache continua visível.
- Sem permissão de leitura nos boards: a janela explica-o e sugere o modo automático.

## Testes

- Cálculo em `DrIslandCoreTests`, com JSON de exemplo para cada gráfico e para os casos limite acima (sprint fora de prazo, task adicionada a meio, sem pontos, workflow com estados novos).
- Cache: ida e volta, versão desconhecida, só sprints fechadas.
- Leitor: parsing de uma página de sprints, de tasks com changelog e de changelog truncado.
- Teste que garante que nenhum caminho novo faz pedidos que não sejam de leitura.

## Ordem de construção

1. Leitor + modelo + cálculo + janela «Gestão» com o **gráfico 1**, a ler direto do Jira, sem cache (a interface `SprintMetricsCache` fica definida).
2. **Cache local**, antes dos gráficos que leem várias sprints.
3. Gráficos **2, 3 e 4**, um de cada vez.
4. Exportação (CSV e PNG).

## A validar no plano (não confirmado ainda)

- Que `expand=changelog` em `search/jql` devolve o histórico completo no vosso Jira, e quantas tasks por página cabem sem exceder os limites.
- O nome exato do campo de pontos para a descoberta automática («Story Points» vs. «Story point estimate»).
- O tempo da primeira leitura de 6 sprints fechadas, para decidir se precisa de barra de progresso.
