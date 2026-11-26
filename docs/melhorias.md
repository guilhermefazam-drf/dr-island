# Pontos de melhoria

Lista de melhorias a fazer, com o estado atual e uma proposta para cada uma. Quando uma for feita, sai daqui e o comportamento passa a estar descrito em `funcionalidades.md`.

---

## 1. Gráficos da Gestão: leituras do Jira ainda mais rápidas

### Estado atual

- Cada leitura ao Jira demora cerca de 200 ms, e só se usa `GET`. O Jira continua só de leitura (`JiraClient.get` recusa tudo o que não seja `GET`/`HEAD`).
- A sprint escolhida carrega primeiro e aparece em ~1,7 s. Os campos e os estados ficam guardados durante a sessão.
- A Velocity e os bugs carregam a seguir:
  - a Velocity lê as últimas 6 sprints fechadas, que ficam guardadas em disco;
  - os bugs cobrem 8 semanas e ficam em memória 5 min.
- Com tudo por carregar (sem disco), a página completa demora ~7 s. Com as sprints fechadas já em disco, ~3 s.
- O que mais pesa são os changelogs truncados de cada issue (lidos 4 de cada vez) e o burndown, que precisa do histórico de cada issue da sprint.

### Propostas (por ordem de ganho estimado)

1. **Carregar a Velocity só quando o card estiver visível.** As sprints que já estão em disco aparecem logo; as que faltam só são lidas quando o card entra no ecrã. Só faz diferença com 1 coluna (com 2 ou mais, o card é visível ao abrir).
2. **Guardar em disco a sprint aberta**, com a data da leitura:
   - ao reabrir a app, a sprint aparece logo a partir do disco;
   - depois só se pedem as issues alteradas desde essa data (`updated >= …` no JQL), e os changelogs só dessas.
3. **Pedir menos campos em cada pesquisa**, só os que os gráficos usam (`fields=` e `expand=` mínimos), para respostas mais pequenas.
4. **Ler os changelogs com mais paralelismo** (de 4 para 6–8 de cada vez), medindo antes se o Jira começa a responder `429`.
5. **Bugs incrementais:** guardar as 8 semanas e, nas leituras seguintes, pedir só o que mudou desde a última vez.
6. **Atualizar em segundo plano** enquanto a ilha está fechada, para que ao abrir os dados já estejam frescos.

### Como medir

`DR_ISLAND_JIRA_TRACE=1` escreve cada leitura com o tempo e o tamanho. Medir o arranque a frio (sem a pasta `~/Library/Application Support/DrIsland/sprints`) e o arranque com disco, antes e depois de cada mudança.

### Restrição

Nada de `POST`, nem para leituras como o `bulkfetch`: tudo continua a passar por `JiraClient.get`.

---

## 2. Avisos no modo Bento: informação repetida em tamanho grande

### Estado atual

Em Bento, os avisos aparecem em vários sítios ao mesmo tempo:

- **No tile «Avisos»** da linha de números: quantos houve hoje e «último: há N min».
- **Abaixo das listas**, numa de duas formas:
  - com menos de 3 colunas, na faixa de eventos (`BentoEventStrip`);
  - com 3 colunas, no card «Avisos» (`AlertsBlock`).

Dentro de cada chip da faixa, a origem aparece duas vezes:

- uma em cima, em maiúsculas (por exemplo «PULL REQUESTS»);
- outra no início da mensagem, porque `AlertEntry.displayMessage` junta a origem à frente do texto («PR - …»).

Com os chips estreitos, a origem repetida ocupa o espaço da parte útil da mensagem, que acaba cortada.

### Propostas

1. **Mostrar a origem só uma vez.** No chip e no card, usar a mensagem sem a origem (`message`) e deixar a origem no título do chip, com a cor do tom. `displayMessage` fica só para os sítios sem título de origem (notificação do macOS, linha compacta).
2. **Repensar o chip em tamanho grande** (Normal, 2 ou 3 colunas):
   - ícone da origem à esquerda, no estilo de `SourceTile`, em vez do nome em maiúsculas;
   - mensagem em até 2 linhas, com a referência (#PR, chave do Jira) a negrito;
   - hora relativa discreta à direita.
3. **Não repetir entre o tile e a lista.** Com a faixa ou o card visíveis, o tile «Avisos» mostra só a contagem do dia, sem «último: há N min», que já se vê ao lado.
4. **Agrupar avisos iguais seguidos**, por exemplo vários «CI falhou» do mesmo PR: um chip com «×3».
5. Desenhar primeiro no laboratório (`docs/design/ilha-redesign.html`), como nos outros componentes, e só depois passar para a app.

### A validar

Tirar um print em Bento com 2 e com 3 colunas, nos temas Grafite e Claro, para confirmar onde está a repetição que se vê no uso real (pode haver também avisos duplicados no histórico).

---

## 3. Pull requests: ícone para a aprovação do CodeRabbit

### Estado atual

- Um PR só conta como aprovado com 2 aprovações de pessoas **e** a aprovação do CodeRabbit (`GitHubParser.overallReview`, em `PullRequests.swift`). A consulta ao GitHub já traz quem aprovou (`latestOpinionatedReviews`).
- Essa informação perde-se no parser: a linha do PR (`PullRequestRow`) só mostra o estado final («aprovado», «alterações pedidas», «à espera de revisão»). Não se vê se falta o CodeRabbit ou se faltam pessoas.

### Proposta

1. **No Core**, guardar em `PullRequest` o resumo das aprovações, por exemplo:
   - `codeRabbit: ReviewState` (aprovou, pediu alterações, ainda não reviu);
   - `humanApprovals: Int`.

   Adicionar testes no parser para cada caso.
2. **Na linha do PR**, um ícone pequeno do CodeRabbit ao lado do estado de revisão:
   - **aprovou:** ícone a verde;
   - **pediu alterações:** ícone a âmbar;
   - **ainda não reviu:** ícone em contorno, na cor terciária.

   O tooltip diz, por exemplo, «CodeRabbit aprovou · 1 de 2 aprovações de pessoas».
3. **Ícone:** um símbolo SF genérico (por exemplo `hare` ou `sparkles`) em vez do logótipo, para não usar a marca. Validar a escolha no laboratório.
4. Opcional: mostrar `N/2` ao lado do ícone, para se ver de relance quantas aprovações de pessoas faltam.
5. Atualizar `funcionalidades.md` (secção dos pull requests) quando estiver feito.
