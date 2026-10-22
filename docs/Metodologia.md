# Metodologia — Amostragem em Múltiplos Estágios no Poker Online

> Comparação entre um plano amostral direto de elementos (dataset Kaggle) e um plano complexo com **estágio temporal, estratificação por buy-in e conglomerados** aplicado a torneios do PokerStars, com coleta de desempenho via SharkScope.

Autor: Arthur Agostinho — Estatística, Unicamp
Disciplina: Técnicas de Amostragem

---

## Sumário

1. [Motivação](#1-motivação)
2. [População, unidades e variáveis](#2-população-unidades-e-variáveis)
3. [Por que um estágio temporal](#3-por-que-um-estágio-temporal)
4. [Delineamento amostral](#4-delineamento-amostral)
5. [Tamanho e alocação da amostra](#5-tamanho-e-alocação-da-amostra)
6. [Protocolo de coleta](#6-protocolo-de-coleta)
7. [Estimadores](#7-estimadores)
8. [Estimação da variância](#8-estimação-da-variância)
9. [Efeito do planejamento (EPA/DEFF)](#9-efeito-do-planejamento-epadeff)
10. [Baseline: dataset Kaggle](#10-baseline-dataset-kaggle)
11. [Erros não amostrais](#11-erros-não-amostrais)
12. [Implementação de referência (Python)](#12-implementação-de-referência-python)
13. [Estrutura do repositório e dicionário de dados](#13-estrutura-do-repositório-e-dicionário-de-dados)
14. [Limitações e considerações éticas](#14-limitações-e-considerações-éticas)
15. [Referências](#15-referências)

---

## 1. Motivação

O objetivo é estimar o desempenho médio dos jogadores de torneios de poker online, medido pelo **ROI médio** ($\bar{Y}$), e a **proporção de jogadores lucrativos** ($P$). Também queremos quantificar quanto a estrutura de conglomerados (jogadores agrupados em torneios, e torneios agrupados no tempo) altera a precisão das estimativas, em comparação com uma amostra aleatória simples.

Duas restrições práticas definem o desenho:

- **Não existe uma moldura completa de torneios.** O PokerStars realiza centenas de milhares de torneios por ano e não publica uma lista com todos eles.
- **A coleta de desempenho é cara.** O SharkScope limita o número de consultas por dia (140 na conta usada no projeto), e o prazo de entrega deixa pouco tempo de coleta. A amostra final tem 120 posições sorteadas (§5).

Por isso o desenho evita depender de uma lista completa e concentra o esforço de coleta em poucos conglomerados.

---

## 2. População, unidades e variáveis

### 2.1 População-alvo

> Inscrições de jogadores em **torneios MTT regulares com buy-in de US\$ 1,00 ou mais** (excluindo freerolls, torneios abaixo de US\$ 1,00, Spin & Go, Sit & Go e torneios satélite assim como Cash Game) do **PokerStars.com**, com início entre **17/10/2026 20:00** e **21/10/2026 00:00** (76 h, horário de Brasília).
>
> O período é limitado pela fonte da listagem. O lobby do PokerStars só mostra parte dos torneios já encerrados (em 13/10/2026, apenas 9 no dia inteiro), então não serve como moldura. A busca de torneios do SharkScope mostra todos, mas só a partir de 17/10/2026 18:24. O período começa às 20:00 de 17/10, o primeiro início de bloco de 2 h dentro dessa janela, e termina antes do prazo da análise (23/10). Os períodos anteriores (01/10 a 14/10 e 11/10 a 20/10) foram abandonados antes de qualquer sorteio de torneios (ver [`fase0_sorteio_blocos.md`](fase0_sorteio_blocos.md)).
>
> Os torneios abaixo de US\$ 1,00 ficam fora pois têm comportamento atípico (muitos inscritos, na maioria jogadores recreativos, prêmios irrisórios e ROI pouco informativo). Eles também são **descartados na listagem** de cada bloco, antes do sorteio do 2º estágio.

A unidade sorteada é a **inscrição** (o par jogador × torneio), então um mesmo jogador pode aparecer mais de uma vez na população, em torneios diferentes, e quem joga mais tem mais chance de ser sorteado. O parâmetro de interesse, porém, é o **ROI médio por jogador distinto**. Para corrigir a diferença de chance, cada jogador recebe o peso de multiplicidade $`1/f_i`$, em que $`f_i`$ é o número de torneios que ele jogou no período (§7.5). A versão *por inscrição* ($`f_i = 1`$), que pondera os jogadores pela frequência com que jogam, é reportada como análise de sensibilidade.

**Re-entries:** dentro de um mesmo torneio, o jogador conta **uma única vez**, por mais entradas que tenha feito. O ROI do SharkScope é um atributo do jogador, e não da entrada; se cada entrada contasse como uma unidade, quem faz re-entry teria mais chance de ser sorteado e um mesmo valor de $y$ poderia aparecer duplicado no conglomerado. O número de entradas fica registrado como variável auxiliar (`n_entradas`). Na análise, discutimos a diferença em relação ao ROI médio *por jogador distinto* (ver [§14](#14-limitações-e-considerações-éticas)).

### 2.2 Hierarquia de unidades

| Nível | Unidade | Notação | Total na população | Na amostra |
|---|---|---|---|---|
| 1º estágio (UPA) | Bloco de tempo de 2 h | $j$ | $B$ | $b$ |
| Estratos (dentro do bloco) | Faixa de buy-in | $h = 1,\dots,H$ | — | — |
| 2º estágio (USA) | Torneio | $k$ | $`N_{jh}`$ | $`n_{jh}`$ |
| 3º estágio (UTA) | Jogador distinto inscrito no torneio | $i$ | $`M_k`$ | $`m_k`$ |

### 2.3 Estratos de buy-in

| Estrato | Faixa de buy-in |
|---|---|
| $h=1$ — Micro | US\$ 1,00 a 4,99 |
| $h=2$ — Low | US\$ 5,00 a 24,99 |
| $h=3$ — Mid/High | US\$ 25,00 ou mais |

### 2.4 Variáveis de interesse

| Variável | Definição | Fonte |
|---|---|---|
| $`y_{ki}`$ — ROI | *Total ROI* (%) do jogador no SharkScope na **janela fixa de 01/10/2025 a 30/09/2026**, considerando só o PokerStars | SharkScope |
| $`\ell_{ki}`$ — Lucro | *Profit* (US\$) no mesmo filtro | SharkScope |
| $`d_{ki}`$ — Lucrativo | $`d_{ki} = 1`$ se $`\ell_{ki} > 0`$; caso contrário, $0$ | Derivada |
| $`M_k`$ | Número de inscritos no torneio $k$, **aproximado pelo total de entradas** mostrado pela fonte (ver nota abaixo) | Listagem do SharkScope (`n_entradas_fonte`) |
| `n_entradas` | Número de entradas do jogador sorteado no torneio (auxiliar) | Lista de inscritos |
| $`f_i`$ | Número de torneios do jogador no período, aproximado por `n_jogos_dia` × 76/24 (mínimo 1) | SharkScope (`n_jogos_dia`, média de jogos por dia) |
| $`N_{jh}`$ | Número de torneios do estrato $h$ no bloco $j$ | Listagem do SharkScope |

> O filtro do SharkScope (período e rede) deve ser **idêntico** para todos os jogadores e registrado na planilha. Por isso a janela do ROI é fixada em datas absolutas, e não relativa ao dia da consulta.
>
> **Simplificação adotada:** o número exibido pela fonte é o total de *entradas*, incluindo re-entries. No projeto, ele é usado como $`M_k`$, ou seja, número de inscritos e número de entradas são tratados como a mesma coisa. Em torneios com re-entry (Bounty Builder, Progressive KO etc.), isso superestima o número de jogadores distintos e dá mais peso a esses torneios. A limitação é discutida na [§14](#14-limitações-e-considerações-éticas).

---

## 3. Por que um estágio temporal

Na versão anterior do plano, a primeira etapa era sortear torneios dentro de cada estrato. Para isso seria preciso listar **todos** os torneios do período, o que não é viável.

A solução é sortear **blocos de tempo** antes dos torneios. Construir a lista de todos os blocos é fácil: 76 h divididas em blocos de 2 h dão $B = 38$ blocos. A lista de torneios só precisa ser montada **dentro dos blocos sorteados**. Essa é a lógica clássica da amostragem por áreas, aplicada ao tempo: em vez de listar a população inteira, listamos só as áreas sorteadas.

Ganhos adicionais:

- O efeito do horário (público diferente de madrugada e no horário nobre europeu ou brasileiro) passa a fazer parte do desenho.
- A estratificação por buy-in é aplicada **dentro de cada bloco**, o que garante que todos os estratos estejam representados.

**Variante opcional:** estratificar os blocos por *dia útil × fim de semana* e/ou *período do dia* antes do sorteio. As fórmulas da [§7](#7-estimadores) passam a valer dentro de cada estrato temporal, e os resultados são somados no final.

---

## 4. Delineamento amostral

```
População: inscrições em MTTs do PokerStars no período
│
├── 1º estágio — UPA: blocos de 2 h
│      AAS sem reposição de b blocos entre B
│
├── Estratificação dentro de cada bloco sorteado
│      Torneios do bloco classificados em H faixas de buy-in
│
├── 2º estágio — USA: torneios
│      AAS sem reposição de n_jh torneios entre N_jh, em cada (bloco, estrato)
│
└── 3º estágio — UTA: jogadores
       AAS sem reposição de m_k jogadores na lista de jogadores distintos de cada torneio
       (M_k aproximado pelo total de entradas, §2.4)
       → consulta de ROI e lucro no SharkScope
```

Todos os sorteios usam **amostragem aleatória simples sem reposição (AASs)**, com semente registrada para garantir reprodutibilidade.

---

## 5. Tamanho e alocação da amostra

Restrição: cota de 140 consultas por dia no SharkScope.

**Alocação final:**

| Parâmetro | Valor | Justificativa |
|---|---|---|
| $B$ | 38 | 76 h (17/10 20:00 a 21/10 00:00) em blocos de 2 h |
| $b$ | 6 sorteados, **4 efetivos** | Mínimo razoável para estimar a variância entre blocos. Os blocos 34 e 36 não puderam ser listados e foram perdidos (ver [§11](#11-erros-não-amostrais)) |
| $H$ | 3 | Faixas de buy-in |
| $`n_{jh}`$ | 2, mais torneios extras se preciso | **Mínimo de 2** com respondentes para estimar a variância entre torneios no estrato (torneios extras: ver abaixo) |
| $`m_k`$ | 5 | Cálculo de $n$ da §5.1 (eram 2 titulares e 3 reservas) |
| **Total** | $4 \times 3 \times 2 \times 5 = \mathbf{120}$ posições, **140** com os 4 torneios extras | Esperavam-se cerca de 110 respondentes; a resposta observada (≈ 39%) levou aos torneios extras (abaixo) |

> Com $`n_{jh} = 1`$ ou $`m_k = 1`$ não é possível estimar a componente de variância correspondente sem suposições extras (como colapsar estratos). Por isso o mínimo é 2 em cada estágio, também depois da não resposta.

**Trade-off:** para a mesma quantidade de consultas, sortear mais torneios com menos jogadores em cada um reduz a variância quando a correlação intraclasse $\rho$ é positiva. A busca de torneios dos blocos 5 e 8 já saiu da janela do SharkScope, mas a lista de resultados de um torneio pode continuar acessível pelo ID.

**Torneios extras (22/10, antes de novas consultas).** A taxa de resposta observada foi de 20/51 ≈ 39%, e três células ficaram abaixo dos mínimos. Regra: enquanto uma célula tiver menos de 2 torneios com $`m_k \ge 2`$ respondentes, sorteia-se o próximo torneio da mesma permutação da célula (`sortear_amostra.R torneio-extra`) e consultam-se as 5 primeiras posições da permutação dele. Os $n$ primeiros de uma permutação aleatória formam uma AAS de tamanho $n$, então a célula continua sendo uma AAS. Torneios sem lista de resultados acessível ou com menos de 2 respondentes ficam fora da estimação (não resposta de USA), e o peso $`N_{jh}/n_{jh}`$ usa os torneios com respondentes. Se a célula esgotar os $`N_{jh}`$ torneios sem chegar ao mínimo, ela é colapsada com o estrato vizinho do mesmo bloco (low → micro; micro e mid_high → low), somando $`N_{jh}`$ e $`n_{jh}`$, o que superestima um pouco a variância (técnica de estratos colapsados). Ver [ADR-011](../.ai/modelagem.md).

### 5.1 Cálculo do tamanho da amostra

O dimensionamento usa a **proporção de lucrativos** $P$, porque para ela existe um pior caso conhecido ($p = 0{,}5$). O desvio-padrão do ROI no SharkScope só é conhecido depois da coleta (o do Kaggle, 46 p.p., vem de dados sintéticos e limitados). Com margem de erro $e$ a 95% e o efeito do planejamento aproximado por Kish (§9):

$$n = \frac{z^2\,p(1-p)}{e^2}\,\bigl[1 + \rho\,(m-1)\bigr], \qquad \text{com FCPF desprezível } (\hat M_0 \approx 144\,000).$$

| Margem $e$ | $\rho = 0$ | $\rho = 0{,}05$, $m = 4$ | $\rho = 0{,}05$, $m = 5$ | $\rho = 0{,}10$, $m = 5$ |
|---|---:|---:|---:|---:|
| ±0,12 | 67 | 77 | 80 | 94 |
| **±0,10** | **96** | **111** | **116** | **135** |
| ±0,08 | 150 | 173 | 180 | 210 |

Para $e = \pm 0{,}10$, são necessários de 96 a 116 jogadores. O máximo disponível é $24 \times 5 = 120$ (as 5 posições já anotadas em cada torneio). Por isso $`m_k = 5`$, sem reservas: com cerca de 110 respondentes e $\rho = 0{,}05$, a margem fica em ≈ ±0,10. A decisão foi tomada antes de qualquer consulta de ROI. As 5 posições são as 5 primeiras da mesma permutação sorteada, então continuam sendo uma AAS ([log](../data/raw/sharkscope/log_coleta.csv), evento `decisao_m_k`).

> **Limite que o $n$ não resolve:** com $b = 4$ blocos, o IC usa $t$ com $b - 1 = 3$ graus de liberdade (§8.3). Como $t_{3;\,0{,}975}/z_{0{,}975} = 1{,}62$, a margem real pode ficar até 60% maior do que a da tabela, por mais jogadores que sejam consultados.

---

## 6. Protocolo de coleta

### Fase 0 — Sorteio dos blocos

1. Gerar a lista dos $B$ blocos (`AAAA-MM-DD HH:00`, em UTC ou horário de Brasília; o fuso deve ser registrado).
2. Sortear $b$ blocos com semente fixa (ver [§12](#12-implementação-de-referência-python)).

### Fase 1 — Listagem dos torneios dentro dos blocos sorteados

3. Para cada bloco sorteado, listar **todos** os MTTs com início no intervalo, usando a busca de torneios do SharkScope. Registrar ID, buy-in, horário de início e número total de entradas.

   > **Disponibilidade da listagem:** só liste um bloco depois que ele terminar. O lobby do PokerStars **não** serve como fonte, porque mostra só parte dos torneios encerrados. A janela de torneios do SharkScope parece andar com o tempo (em 19/10/2026 às 23:24, começava em 17/10 18:24, cerca de 53 h antes). Por isso, liste cada bloco o quanto antes, começando pelos mais antigos, e registre a fonte e a data de cada listagem.
4. **Descartar** freerolls e torneios com buy-in abaixo de US\$ 1,00, registrando quantos foram descartados por bloco. Depois, classificar os torneios restantes nos estratos e contar $`N_{jh}`$.
5. Sortear $`n_{jh}`$ torneios por estrato.

### Fase 2 — Sorteio dos jogadores

6. Em cada torneio sorteado, sortear uma ordem de posições de 1 a $`M_k`$ na lista de resultados do SharkScope (1 = campeão), que já tem ordem fixa antes do sorteio. As $`m_k`$ primeiras são os titulares (as seguintes, se houver, são a ordem de reservas; com $`m_k = 5`$ não há reservas, §5.1). Assim, não é preciso transcrever a lista inteira. O $`M_k`$ usado nos estimadores continua sendo o total de entradas da listagem (§2.4).
7. Anotar o nickname de cada posição, seguindo a ordem. Se a posição não existir na lista (a lista pode ter menos linhas que $`M_k`$ por causa das re-entries) ou repetir um jogador já sorteado no torneio, ela é pulada e entra a próxima da ordem. Cada jogador conta uma vez por torneio.
8. Anotar também os 10 primeiros colocados de cada torneio sorteado (`top10_torneios.csv`), para uma comparação futura com a amostra aleatória. Esse grupo **não** é uma amostra probabilística e não entra nos estimadores.

### Fase 3 — Consulta no SharkScope

9. Consultar, por dia, no máximo o número de nicknames permitido pela cota, seguindo uma ordem aleatória (não agrupar por estrato, para que a passagem do tempo não se confunda com o estrato).
10. Registrar ROI, lucro, `n_jogos_dia` (obrigatório para o peso $`1/f_i`$, §7.5), data da consulta e o filtro usado.

### Registro

Cada sorteio, decisão e não resposta deve ficar registrado em [`data/raw/sharkscope/log_coleta.csv`](../data/raw/sharkscope/log_coleta.csv).

---

## 7. Estimadores

### 7.1 Total no torneio

$$\bar{y}_k = \frac{1}{m_k}\sum_{i=1}^{m_k} y_{ki}, \qquad \hat{T}_k = M_k\,\bar{y}_k$$

### 7.2 Total no estrato $h$ do bloco $j$

$$\hat{Y}_{jh} = \frac{N_{jh}}{n_{jh}} \sum_{k=1}^{n_{jh}} \hat{T}_k$$

### 7.3 Total no bloco $j$

$$\hat{Y}_j = \sum_{h=1}^{H} \hat{Y}_{jh}$$

### 7.4 Total populacional (estimador expansão / Horvitz–Thompson)

$$\hat{Y} = \frac{B}{b}\sum_{j=1}^{b} \hat{Y}_j$$

A probabilidade de inclusão de cada inscrição $(j,h,k,i)$ é

$$\pi_{jhki} = \frac{b}{B}\cdot\frac{n_{jh}}{N_{jh}}\cdot\frac{m_k}{M_k},$$

e $`\hat{Y} = \sum w_{jhki}\, y_{jhki}`$, com peso amostral $w = 1/\pi$.

### 7.5 Número de inscrições e média (estimador razão)

O número total de inscrições $`M_0`$ é desconhecido e também é estimado, aplicando a mesma fórmula com $`y_{ki} \equiv 1`$:

$$\hat{M}_0 = \frac{B}{b}\sum_{j}\sum_{h}\frac{N_{jh}}{n_{jh}}\sum_{k} M_k$$

O ROI médio por inscrição é o **estimador razão**:

$$\hat{R}_{\text{insc}} = \frac{\hat{Y}}{\hat{M}_0} = \frac{\sum w\,y}{\sum w}$$

O **ROI médio por jogador distinto**, parâmetro de interesse (§2.1), aplica a mesma fórmula às variáveis $`y_{ki}/f_i`$ e $`1/f_i`$. Um jogador com $`f_i`$ inscrições no período aparece $`f_i`$ vezes na população de inscrições, então a soma de $`y/f`$ sobre as inscrições é a soma de $`y`$ sobre os jogadores:

$$\boxed{\;\hat{\bar{Y}} = \hat{R} = \frac{\sum w\,y_i/f_i}{\sum w/f_i}\;}$$

$`f_i`$ é aproximado por `n_jogos_dia` × 76/24, com mínimo 1, porque o jogador sorteado jogou ao menos aquele torneio. A aproximação usa a média de jogos por dia da janela do ROI (1 ano), e não a das 76 h.

### 7.6 Proporção de lucrativos

É o mesmo estimador, aplicado à variável indicadora $`d_{ki}`$:

$$\hat{P} = \frac{\sum w\, d_i/f_i}{\sum w/f_i}$$

---

## 8. Estimação da variância

### 8.1 Variância do total (estimador não viesado para três estágios)

Seguindo a decomposição por estágios de Cochran (1977, cap. 10–11) e Thompson (2012, cap. 13):

$$
\widehat{\mathrm{Var}}(\hat{Y}) =
\underbrace{B^2\left(1-\frac{b}{B}\right)\frac{s_u^2}{b}}_{\text{entre blocos}}
\;+\;
\frac{B}{b}\sum_{j=1}^{b}\widehat{\mathrm{Var}}(\hat{Y}_j)
$$

onde $`s_u^2 = \frac{1}{b-1}\sum_j \left(\hat{Y}_j - \bar{\hat{Y}}\right)^2`$ é a variância amostral dos totais estimados dos blocos e

$$
\widehat{\mathrm{Var}}(\hat{Y}_j) = \sum_{h=1}^{H}\left[
\underbrace{N_{jh}^2\left(1-\frac{n_{jh}}{N_{jh}}\right)\frac{s_{1jh}^2}{n_{jh}}}_{\text{entre torneios}}
+
\underbrace{\frac{N_{jh}}{n_{jh}}\sum_{k=1}^{n_{jh}} M_k^2\left(1-\frac{m_k}{M_k}\right)\frac{s_{2k}^2}{m_k}}_{\text{dentro do torneio}}
\right]
$$

com

- $`s_{1jh}^2`$: variância amostral dos $`\hat{T}_k`$ entre os torneios sorteados do estrato $h$ no bloco $j$;
- $`s_{2k}^2`$: variância amostral de $`y_{ki}`$ entre os jogadores sorteados no torneio $k$.

Os fatores $(1 - b/B)$, $`(1 - n_{jh}/N_{jh})`$ e $`(1 - m_k/M_k)`$ são as **correções para população finita** de cada estágio.

> **Aproximação por conglomerado último.** Quando $b/B$ é pequeno, o primeiro termo sozinho, sem o fator $(1 - b/B)$, já captura quase toda a variância e é um estimador ligeiramente conservador. Aqui $b/B = 4/38 \approx 11\%$ (eram $6/38 \approx 16\%$ antes da perda dos blocos 34 e 36), então a diferença entre as duas versões não é desprezível. É o que fazem `survey` (R) e `samplics` (Python) por padrão. Vale reportar as duas versões.

### 8.2 Variância da média (linearização de Taylor)

Como $`\hat{R} = \hat{Y}/\hat{M}_0`$ é uma razão, linearizamos usando a variável resíduo

$$z_{ki} = \frac{y_{ki} - \hat{R}}{f_i}$$

e aplicamos a fórmula da §8.1 à variável $z$:

$$\widehat{\mathrm{Var}}(\hat{R}) \approx \frac{\widehat{\mathrm{Var}}(\hat{Z})}{\hat{N}^{\,2}}, \qquad \hat{N} = \frac{B}{b}\sum_j\sum_h\frac{N_{jh}}{n_{jh}}\sum_k \frac{M_k}{m_k}\sum_i \frac{1}{f_i}$$

Por inscrição, $`f_i = 1`$ e $`\hat{N} = \hat{M}_0`$. Implementação: `estimar_media_tres_estagios()` em [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R).

### 8.3 Intervalos de confiança

$$\hat{R} \pm t_{\,gl;\,0{,}975}\,\sqrt{\widehat{\mathrm{Var}}(\hat{R})}$$

Com poucos conglomerados primários, use graus de liberdade $gl = b - 1 = 3$ ($`t_{3;0{,}975} \approx 3{,}182`$) em vez de $z = 1{,}96$. Com $b/B$ pequeno, a variância é estimada essencialmente a partir dos $b$ totais de bloco, por isso os gl vêm do número de blocos, e não do número de torneios ou de jogadores. Para $\hat{P}$, também é recomendável o intervalo de Wilson ou o logit, adaptados ao tamanho efetivo de amostra $`n_{\text{ef}} = n / \text{EPA}`$.

---

## 9. Efeito do planejamento (EPA/DEFF)

$$\text{EPA} = \frac{\widehat{\mathrm{Var}}(\hat{R})}{\widehat{\mathrm{Var}}_{\text{AAS}}(\bar{y})},
\qquad
\widehat{\mathrm{Var}}_{\text{AAS}}(\bar{y}) = \left(1-\frac{n}{\hat{N}}\right)\frac{s_y^2}{n}$$

com $`s_y^2`$ ponderada pelos pesos finais $`w/f_i`$ e $`\hat{N}`$ da §8.2.

- $\text{EPA} > 1$: o desenho complexo é **menos** eficiente que uma AAS com o mesmo $n$, por efeito dos conglomerados.
- $\text{EPA} < 1$: a estratificação compensa a perda causada pelos conglomerados.

Com $`m_k`$ constante, vale a aproximação de Kish, que relaciona o EPA à correlação intraclasse $\rho$:

$$\text{EPA} \approx 1 + (m - 1)\,\rho \quad\Rightarrow\quad \hat{\rho} \approx \frac{\text{EPA} - 1}{m - 1}$$

Uma hipótese a investigar é se jogadores do mesmo torneio têm desempenho correlacionado ($\rho > 0$), já que o buy-in e o horário selecionam perfis de habilidade parecidos.

---

## 10. Baseline: dataset Kaggle

O dataset do Kaggle é tratado como **população finita conhecida**, o que permite simular repetidamente os planos amostrais.

1. Usar as mesmas faixas de estrato da §2.3, aplicadas ao buy-in médio do jogador (`avg_buyin`). Nenhum jogador do Kaggle tem buy-in médio abaixo de US\$ 1,00, então o corte da população de campo não remove ninguém.
2. Calcular os parâmetros verdadeiros: $`\bar{Y}_{\text{Kaggle}}`$ e $`P_{\text{Kaggle}}`$. A unidade do Kaggle já é o jogador, como no parâmetro de campo.
3. Rodar $R = 5\,000$ réplicas de:
   - **AASs** de tamanho $n = 120$, o mesmo $n$ do campo (§5);
   - **Estratificada simples** por faixa de buy-in, com alocação proporcional (e, como variante didática, por quartis de `skill`).
4. Comparar, nas simulações, vício, EQM, erro-padrão médio e cobertura empírica do IC de 95%.
5. O dataset não tem identificador de torneio, então o desenho em conglomerados não pode ser simulado nele. O EPA do plano em três estágios vem só da amostra de campo.

> As estimativas do Kaggle e do SharkScope **não** se referem à mesma população. A comparação é **metodológica** (precisão, EPA, comportamento dos estimadores), não uma comparação direta das médias.

---

## 11. Erros não amostrais

| Problema | Tratamento |
|---|---|
| **Perfil privado / opt-out** no SharkScope | Não resposta, sem substituição (com $`m_k = 5`$ não há reservas, §5.1): $`m_k`$ passa a ser o número de respondentes do torneio, sob a hipótese de não resposta aleatória dentro do torneio. Registrar a taxa por estrato. Célula com menos de 2 torneios com $`m_k \ge 2`$ recebe torneios extras da mesma permutação, ou é colapsada com o estrato vizinho (§5). |
| **Jogador "Anônimo"** na lista de resultados | Não pode ser consultado nem identificado. É tratado como perfil privado (não resposta) e entra na taxa de não resposta. São 6 das 120 posições sorteadas originalmente. |
| **`n_jogos_dia` ausente** | Sem ele não há peso $`1/f_i`$ (§7.5). Anotar em toda consulta. |
| **Jogador com poucos torneios** (ROI instável) | Registrar o número de torneios do jogador no período. Fazer análise de sensibilidade excluindo quem tem menos de 30 torneios. |
| **Mesmo jogador sorteado em dois torneios** | Manter os dois registros (a unidade é a inscrição) e reaproveitar a consulta sem gastar cota. |
| **Torneio cancelado ou com poucos inscritos** ($`M_k < m_k`$) | Excluir da lista do bloco antes do sorteio e documentar o critério. |
| **Erro na listagem do bloco** (torneio omitido) | Conferir a listagem do SharkScope com a agenda oficial do PokerStars e reconciliar. |
| **Defasagem temporal** (o ROI muda entre os dias de consulta) | Usar a janela fixa de 01/10/2025 a 30/09/2026 para todos os jogadores (§2.4), em vez de "últimos 12 meses" relativo à data da consulta. |
| **Re-entry** (jogador com várias entradas no mesmo torneio) | Contar o jogador uma vez na lista deduplicada e registrar `n_entradas` (§2.1). |
| **Listagem indisponível ou incompleta** | O período foi redefinido duas vezes porque a fonte não cobria todos os blocos (lobby sem 01/10 a 10/10; lobby incompleto; SharkScope só a partir de 17/10 18:24). A regra é redefinir o período **antes** do sorteio dos torneios e refazer o sorteio dos blocos com a mesma semente (§2.1). Durante a coleta, listar cada bloco antes que ele saia da janela do SharkScope (§6). |
| **Bloco sorteado que não pôde ser listado** (não resposta de UPA) | Os blocos 34 e 36 (20/10, 14:00–16:00 e 18:00–20:00) ficaram fora do alcance da busca do SharkScope antes de serem listados. Eles são tratados como não resposta de UPA: a estimação usa os $b = 4$ blocos listados, com peso $B/b = 38/4$, sem substituição e sem novo sorteio. A hipótese é que a perda não tem relação com o ROI, porque veio do acesso à fonte. Ressalva: os dois blocos perdidos são de terça à tarde e à noite. Ver [`fase0_sorteio_blocos.md` §7](fase0_sorteio_blocos.md#7-perda-dos-blocos-34-e-36). |

---

## 12. Implementação de referência (Python)

> A implementação oficial é a em R ([`R/sorteio.R`](../R/sorteio.R) e [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R)). Este código em Python é só uma referência: com a mesma semente, o `numpy` sorteia unidades diferentes das do R, e o estimador abaixo está na versão por inscrição ($`f_i = 1`$).

### 12.1 Sorteios reprodutíveis

```python
import numpy as np
import pandas as pd

SEMENTE = 164363
rng = np.random.default_rng(SEMENTE)

# 1º estágio: blocos de 2 h em 76 h
blocos = pd.date_range("2026-10-17 20:00", periods=38, freq="2h")  # 17/10 20:00 a 21/10 00:00
blocos_sorteados = rng.choice(blocos, size=6, replace=False)

# 2º estágio: dentro de cada (bloco, estrato)
def sortear_torneios(lista_torneios: pd.DataFrame, n: int = 2) -> pd.DataFrame:
    return lista_torneios.sample(n=min(n, len(lista_torneios)), random_state=rng.integers(1e9))

# 3º estágio: titulares (+ reservas, se houver)
def sortear_jogadores(M_k: int, m: int = 5, reservas: int = 0) -> list[int]:
    return rng.permutation(np.arange(1, M_k + 1))[: m + reservas].tolist()
```

### 12.2 Estimadores e variância

```python
import numpy as np
import pandas as pd

def total_e_var(df: pd.DataFrame, col: str, B: int):
    """Total HT e variância não viesada para o desenho de 3 estágios.
    Colunas exigidas: bloco, estrato, torneio, N_jh, M_k, <col>."""
    tor = (df.groupby(["bloco", "estrato", "torneio"])
             .agg(m=(col, "size"), M=("M_k", "first"), N=("N_jh", "first"),
                  ybar=(col, "mean"),
                  s2=(col, lambda s: s.var(ddof=1) if len(s) > 1 else 0.0))
             .reset_index())
    tor["T"] = tor.M * tor.ybar
    tor["w"] = tor.M**2 * (1 - tor.m / tor.M) * tor.s2 / tor.m       # dentro do torneio

    sb = (tor.groupby(["bloco", "estrato"])
             .agg(n=("T", "size"), N=("N", "first"), somaT=("T", "sum"),
                  s1=("T", lambda s: s.var(ddof=1)), somaw=("w", "sum"))
             .reset_index())
    sb["Y"] = sb.N / sb.n * sb.somaT
    sb["v"] = sb.N**2 * (1 - sb.n / sb.N) * sb.s1 / sb.n + sb.N / sb.n * sb.somaw

    bl = sb.groupby("bloco").agg(Y=("Y", "sum"), v=("v", "sum"))
    b = len(bl)
    Y = B / b * bl.Y.sum()
    v = B**2 * (1 - b / B) * bl.Y.var(ddof=1) / b + B / b * bl.v.sum()
    return Y, v


def estimar_media(df: pd.DataFrame, col: str, B: int, t: float = 3.182):  # t_{b-1}, b = 4
    """Estimador razão (média por inscrição), EP linearizado, IC e EPA."""
    M0, _ = total_e_var(df.assign(_um=1.0), "_um", B)
    Y, _ = total_e_var(df, col, B)
    R = Y / M0
    _, vz = total_e_var(df.assign(_z=df[col] - R), "_z", B)
    var_R = vz / M0**2
    n = len(df)
    var_aas = (1 - n / M0) * df[col].var(ddof=1) / n
    ep = np.sqrt(var_R)
    return {"estimativa": R, "ep": ep, "ic95": (R - t * ep, R + t * ep),
            "M0_hat": M0, "epa": var_R / var_aas}


# Uso:
# df = pd.read_csv("data/processed/amostra_sharkscope.csv")
# df["lucrativo"] = (df["lucro"] > 0).astype(float)
# estimar_media(df, "roi", B=38)
# estimar_media(df, "lucrativo", B=38)
```

> **Validação cruzada:** confira o estimador pontual e o EP com o pacote `survey` do R. Use `svydesign(ids = ~bloco + torneio, weights = ~peso, data = df)`, com `peso = (B/b) * (N_jh/n_jh) * (M_k/m_k)`. Essa é a aproximação por conglomerado último; ela deve ficar próxima do resultado de `estimar_media`.

---

## 13. Estrutura do repositório e dicionário de dados

```
.
├── R/
│   ├── dados.R                      # leitura e validação (Kaggle, listagem → moldura, top 10, coleta)
│   ├── sorteio.R                    # blocos, torneios por (bloco, estrato), posições dos jogadores
│   ├── estimadores_aas.R            # AAS e AAS estratificada (Kaggle)
│   ├── estimadores_dois_estagios.R  # núcleo de dois estágios (Thompson §13.1) e EPA
│   ├── estimadores_tres_estagios.R  # plano de campo: blocos → torneios → jogadores
│   └── simulacao_kaggle.R
├── scripts/                         # sortear_amostra.R, estimar_campo.R, simular_kaggle.R
├── tests/testthat/                  # um teste por módulo; exemplos do Thompson
├── data/raw/
│   ├── kaggle/                      # dataset do Kaggle (fora do Git)
│   └── sharkscope/                  # blocos, listagem, torneios, jogadores, coleta, top 10, log
└── docs/                            # Metodologia, fases 0 e 1, relatório
```

O formato de cada planilha de campo está em [`data/raw/README.md`](../data/raw/README.md). A planilha que entra nos estimadores é **`coleta_jogadores.csv`**, com uma linha por posição sorteada:

| Coluna | Descrição |
|---|---|
| `estrato`, `bloco_id`, `torneio_id` | Célula e torneio de origem |
| `n_inscritos` | $`M_k`$ (total de entradas da listagem) |
| `ordem`, `posicao`, `tipo` | Ordem do sorteio, posição na lista de resultados, `titular` |
| `nickname` | Nickname na lista de resultados (§14) |
| `data_consulta`, `respondeu` | Data da consulta; `FALSE` para perfil privado ou "Anônimo" |
| `roi`, `lucro` | Total ROI (%) e Profit (US\$) no filtro fixo (§2.4) |
| `n_jogos_dia` | Média de jogos por dia, para $`f_i`$ (§7.5) |

---

## 14. Limitações e considerações éticas

- **Unidade de inscrição × jogador.** Jogadores frequentes têm maior probabilidade de inclusão. O ROI *por jogador distinto* corrige isso com o peso $`1/f_i`$ (§7.5), mas $`f_i`$ é aproximado pela média de jogos por dia da janela de 1 ano, e não contado nas 76 h do período. Se a frequência de um jogador nas 76 h for diferente da média dele no ano, o peso fica errado. A comparação com a versão por inscrição mostra quanto o resultado depende desse peso.
- **$`M_k`$ aproximado pelas entradas.** O tamanho de cada torneio é o total de entradas, com re-entries (§2.4). Em torneios com re-entry, $`M_k`$ fica maior que o número de jogadores distintos, e o peso $`M_k/m_k`$ desses torneios fica inflado. O sorteio dos jogadores continua sendo feito na lista sem repetições.
- **Poucos conglomerados primários** ($b = 4$ efetivos, de 6 sorteados): os graus de liberdade são baixos e o IC fica largo. Isso é esperado, e discutir esse ponto faz parte da análise. A perda dos blocos 34 e 36 (terça à tarde e à noite) deixa o horário de dia útil depois das 14h representado só pelo bloco 24.
- **ROI histórico tem alta variância** e cauda pesada. Considere reportar também a mediana e fazer análise de sensibilidade com ROI winsorizado.
- **Validade externa:** os resultados valem para MTTs do PokerStars.com no período escolhido, e não para o poker online em geral. O período tem só 76 h (sábado à noite, domingo, segunda e terça), limitado pela janela do SharkScope e pelo prazo. Não cobre uma semana inteira nem eventos que acontecem só em outros dias. Os 4 blocos efetivos são domingo 04–06 h e 10–12 h, segunda 18–20 h e terça 06–08 h.
- **Termos de uso:** toda a coleta no SharkScope é **manual e respeita a cota da conta**. Não se usa scraping automatizado nem do SharkScope nem do PokerStars.
- **Privacidade:** nicknames são pseudônimos públicos, escolhidos pelo próprio jogador e exibidos abertamente no PokerStars e no SharkScope. Sozinhos, não identificam a pessoa e não são dados pessoais identificáveis (PII). Por isso, ficam no repositório como aparecem na fonte, o que permite conferir a coleta. Nenhum outro dado do jogador, além do que o SharkScope mostra publicamente, é coletado.

---

## 15. Referências

- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
- COCHRAN, W. G. *Sampling Techniques*. 3. ed. New York: Wiley, 1977.
- KISH, L. *Survey Sampling*. New York: Wiley, 1965.
- LOHR, S. L. *Sampling: Design and Analysis*. 3. ed. Boca Raton: CRC Press, 2022.
- SÄRNDAL, C.-E.; SWENSSON, B.; WRETMAN, J. *Model Assisted Survey Sampling*. New York: Springer, 1992.
- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
