# Relatório parcial — Amostragem estratificada em três estágios no poker online

**ME430 — Técnicas de Amostragem** · Estatística, Unicamp · 2º semestre de 2026<br>
**Situação em:** 23/10/2026 (coleta de campo encerrada; análise preliminar)<br>
**Grupo:** 
Arthur Agostinho Furlan Teixeira RA: 164363

---

## Resumo

Estimamos o ROI médio por jogador distinto e a proporção de jogadores lucrativos entre os inscritos em MTTs do PokerStars (buy-in ≥ US\$ 1,00) de 17/10/2026 20:00 a 21/10/2026 00:00. O plano tem três estágios: blocos de 2 h (UPA), torneios estratificados por buy-in dentro de cada bloco (USA) e jogadores (UTA), com ROI e lucro consultados no SharkScope.

Foram sorteados 6 dos 38 blocos, mas só 4 puderam ser listados. Nesses 4 blocos foram sorteados 32 torneios (24 originais e 8 extras, para compensar a não resposta) e 160 posições. Responderam 72 posições (45%). A estimação usa 67 respondentes em 24 torneios.

| Parâmetro (por jogador distinto) | Estimativa | EP | IC 95% |
|---|---:|---:|---|
| ROI médio (%) | 17,47 | 5,50 | [−0,04; 34,98] (t, 3 gl) |
| Proporção de lucrativos (ROI > 0) | 0,854 | 0,073 | [0,476; 0,974] (logit) |
| Proporção com ROI > 0 e lucro > 0 | 0,723 | 0,181 | [0,128; 0,979] (logit) |

Mais de 80% da variância vem da variação **entre blocos**, e com b = 4 os intervalos têm só 3 graus de liberdade. As estimativas devem ser lidas como as dos **jogadores com perfil público no SharkScope**: a não resposta é de 55% e provavelmente seletiva (§6).

---

## 1. Objetivo e parâmetros

O trabalho compara dois tipos de plano amostral: a amostragem direta de elementos (AAS e AAS estratificada), simulada por Monte Carlo num dataset do Kaggle, e a amostragem em três estágios aplicada em campo. Este relatório parcial trata só da parte de campo. Os parâmetros são:

- $`\bar Y`$: **ROI médio por jogador distinto**, em %. ROI é o *Total ROI* do SharkScope, no PokerStars, na janela fixa de 01/10/2025 a 30/09/2026.
- $`P`$: **proporção de jogadores lucrativos**, em duas versões: ROI > 0 (`lucrativo`, a mesma definição do Kaggle) e ROI > 0 com lucro > 0 (`lucrativo_estrito`).

O delineamento completo está em [`Metodologia.md`](Metodologia.md), e as decisões estatísticas, em formato ADR, em [`.ai/modelagem.md`](../.ai/modelagem.md).

---

## 2. População e plano amostral

### 2.1 População e hierarquia de unidades

A população é a das **inscrições** (pares jogador × torneio) em MTTs regulares do PokerStars com buy-in ≥ US\$ 1,00 e início no período de referência (76 h). Ficam de fora freerolls, Spin & Go, Sit & Go, satélites e cash game.

| Estágio | Unidade | População | Amostra |
|---|---|---|---|
| 1º (UPA) | Bloco de tempo de 2 h | $`B = 38`$ | $`b = 6`$ sorteados, **4 efetivos** |
| Estratificação, dentro do bloco | Faixa de buy-in $`h`$: micro (1–4,99), low (5–24,99), mid/high (≥ 25) | $`H = 3`$ | — |
| 2º (USA) | Torneio $`k`$ | $`N_{jh}`$ | $`n_{jh}`$ |
| 3º (UTA) | Jogador $`i`$ (posição na lista de resultados) | $`M_k`$ (total de entradas) | $`m_k = 5`$ |

O estágio temporal resolve um problema de moldura: não existe uma lista de todos os torneios do período, mas a lista dos 38 blocos é trivial. Por isso só é preciso listar os torneios **dentro dos blocos sorteados**, a mesma lógica da amostragem por áreas (Cochran, 1977, cap. 10–11).

### 2.2 Moldura dos blocos efetivos

Os torneios dos blocos 5, 8, 24 e 30 foram listados na busca do SharkScope, com 83 torneios elegíveis ($`N_{jh}`$):

| Bloco | Horário (Brasília) | Micro | Low | Mid/High | Total |
|---|---|---:|---:|---:|---:|
| 5 | dom 18/10, 04:00–06:00 | 7 | 8 | 3 | 18 |
| 8 | dom 18/10, 10:00–12:00 | 8 | 8 | 5 | 21 |
| 24 | seg 19/10, 18:00–20:00 | 9 | 11 | 7 | 27 |
| 30 | ter 20/10, 06:00–08:00 | 3 | 9 | 5 | 17 |

A classificação em estratos é feita por `estratificar_buyin()` ([`R/dados.R:49-51`](../R/dados.R#L49-L51)), e a moldura de torneios elegíveis, por `montar_moldura()` ([`R/dados.R:127`](../R/dados.R#L127)).

---

## 3. Execução da coleta

### 3.1 Sorteios

Todos os sorteios são AAS sem reposição feitos com `sample.int()` do R, semente **164363**. Cada célula (bloco, estrato) e cada torneio recebe uma semente derivada da semente principal ([`semente_derivada()`, `R/sorteio.R:203`](../R/sorteio.R#L203)). Assim, o sorteio de uma unidade não muda quando outras unidades entram depois.

| Estágio | Função | Linha do sorteio |
|---|---|---|
| Blocos ($`b = 6`$ de $`B = 38`$) | `sortear_blocos()` | [`R/sorteio.R:66`](../R/sorteio.R#L66): `sample.int(nrow(blocos), b)` |
| Torneios ($`n_{jh} = 2`$ por célula) | `sortear_torneios()` | [`R/sorteio.R:107-108`](../R/sorteio.R#L107-L108): `sample.int(nrow(da_celula), tamanho)` |
| Torneios extras (§3.3) | `estender_torneios()` | [`R/sorteio.R:133-150`](../R/sorteio.R#L133-L150) |
| Posições ($`m_k = 5`$ de 1 a $`M_k`$) | `sortear_jogadores()` | [`R/sorteio.R:182`](../R/sorteio.R#L182): `sample.int(M_k, tamanho)` |

Os 6 blocos sorteados foram 5, 8, 24, 30, 34 e 36. Em vez de transcrever a lista de inscritos, o 3º estágio sorteia **posições** na lista de resultados do torneio (1 = campeão), que já tem ordem fixa antes do sorteio.

Os sorteios usam uma propriedade da AAS sem reposição: **os $`n`$ primeiros elementos de uma permutação aleatória formam uma AAS de tamanho $`n`$**. O `sample.int()` sem reposição sorteia em sequência, então pedir $`n + 1`$ elementos com a mesma semente devolve os mesmos $`n`$ primeiros e mais um. Essa propriedade justificou duas decisões:

- passar $`m_k`$ de 2 titulares e 3 reservas para 5 titulares (ADR-010);
- sortear torneios extras numa célula sem alterar os já sorteados (ADR-011). `estender_torneios()` confere isso explicitamente ([`R/sorteio.R:143-145`](../R/sorteio.R#L143-L145)) e para com erro se a permutação não reproduzir os torneios já sorteados.

### 3.2 Perda de UPAs: blocos 34 e 36

Em 22/10, os blocos 34 (ter 20/10, 14:00–16:00) e 36 (ter 20/10, 18:00–20:00) já não podiam ser listados, porque o custo de busca do SharkScope não alcançava mais esses horários. Os dois foram tratados como **não resposta de UPA**, sem substituição (ADR-008):

- $`b = 4`$ efetivo, peso do 1º estágio $`B/b = 38/4 = 9{,}5`$;
- hipótese: a perda se deve ao acesso à fonte e não tem relação com o ROI, então os 4 blocos restantes são tratados como uma AAS de 4 em 38.

### 3.3 Não resposta e torneios extras

A não resposta acontece quando o perfil é privado no SharkScope ou quando a posição sorteada é um jogador "Anônimo", que não pode ser consultado. Na primeira rodada de consultas (22/10), a taxa de resposta foi de 20/51 ≈ 39%, bem abaixo dos ≈ 92% supostos no dimensionamento (ADR-010). Com isso, várias células ficaram abaixo dos mínimos de estimação, que são 2 torneios por célula e 2 respondentes por torneio. Sem esses mínimos, não é possível estimar a componente de variância correspondente.

**Regra (ADR-011), registrada no [log](../data/raw/sharkscope/log_coleta.csv) antes de novas consultas:** enquanto uma célula tiver menos de 2 torneios com $`m_k \ge 2`$ respondentes, sorteia-se o próximo torneio da permutação da célula. Se a célula esgotar os $`N_{jh}`$ torneios, ela é colapsada com o estrato vizinho do mesmo bloco. A regra foi aplicada duas vezes:

| Data | Célula | Torneios extras | Respondentes nos extras |
|---|---|---|---|
| 22/10 | bloco 5, low | 4039583266 | 3 |
| 22/10 | bloco 5, micro | 4039582664 | 2 |
| 22/10 | bloco 8, low | 4039582706, 4039581466 | 2, 3 |
| 23/10 | bloco 24, micro | 4040085450, 4040093364 | 3, 4 |
| 23/10 | bloco 30, low | 4040087687 | 3 |
| 23/10 | bloco 30, micro | 4040092069 (último da célula) | 3 |

No fim, as 12 células têm exatamente 2 torneios com $`m_k \ge 2`$, e nenhum colapso foi necessário. Os torneios com 0 ou 1 respondente ficam **registrados** na coleta, mas fora da estimação, como não resposta de USA:

- 1 respondente: 4039583402, 4039582436, 4039583060, 4040087659 e 4040093464;
- 0 respondentes: 4038334525, 4040092391 e 4040093393.

A exclusão está em [`R/estimadores_tres_estagios.R:114-117`](../R/estimadores_tres_estagios.R#L114-L117):

```r
chave <- paste(resp$bloco_id, resp$estrato, resp$torneio_id, sep = "|")
fica <- as.numeric(table(chave)[chave]) >= M_MINIMO_POR_TORNEIO
excluidos <- unique(resp$torneio_id[!fica])
resp <- resp[fica, , drop = FALSE]
```

Em seguida, $`n_{jh}`$ passa a contar só os torneios que ficam ([linha 144](../R/estimadores_tres_estagios.R#L144)), o que redistribui o peso dos torneios perdidos entre os que ficaram na mesma célula. A suposição por trás disso é que a não resposta é aleatória dentro da célula (Thompson, 2012, §14.5).

**Taxa de não resposta** (`taxa_nao_resposta()`, [`R/estimadores_dois_estagios.R:199-210`](../R/estimadores_dois_estagios.R#L199-L210)):

| Estrato | Posições consultadas | Sem dados | Taxa de não resposta |
|---|---:|---:|---:|
| Micro | 60 | 38 | 63,3% |
| Low | 60 | 34 | 56,7% |
| Mid/High | 40 | 16 | 40,0% |
| **Total** | **160** | **88** (8 Anônimos) | **55,0%** |

Cada bloco teve 18 respondentes em 40 posições. A não resposta cai à medida que o buy-in sobe, o que é compatível com jogadores de stakes mais altos terem perfil público com mais frequência.

### 3.4 Casos particulares

- **Jogador sorteado em dois torneios (`ralfrolf`, bloco 30, low e mid/high).** Os dois registros são mantidos, porque a unidade amostral é a inscrição. Cada registro foi sorteado de forma independente, em células diferentes, e o peso de multiplicidade $`1/f_i`$ (§4.3) corrige a contagem dupla. Remover um deles mudaria as probabilidades de inclusão depois do sorteio e puxaria a estimativa para o perfil dos jogadores ocasionais. Por isso há 72 respondentes como inscrições e 71 jogadores distintos.
- **ROI positivo com lucro negativo** (9 registros, entre eles `MuoMadre`, `daveyboy1967` e `ralfrolf`). Os valores foram conferidos no SharkScope. Isso acontece quando o jogador ganha, em média por torneio, nos buy-ins baratos e perde muito nos caros. É o que separa as duas definições de lucrativo.
- **`MuoMadre`, ROI de 1064,4%.** O valor foi conferido e mantido. Por ser extremo, entra na análise de sensibilidade (§5.3).

---

## 4. Estimadores: teoria, fórmulas e implementação

### 4.1 Probabilidades de inclusão e pesos

Cada estágio é uma AAS sem reposição, então a probabilidade de inclusão de uma inscrição é o produto das probabilidades condicionais de cada estágio (Cochran, 1977, cap. 10):

$$\pi_{jhki} = \frac{b}{B}\cdot\frac{n_{jh}}{N_{jh}}\cdot\frac{m_k}{M_k}, \qquad w_{jhki} = \frac{1}{\pi_{jhki}} = \frac{B}{b}\cdot\frac{N_{jh}}{n_{jh}}\cdot\frac{M_k}{m_k}.$$

Na estimação por jogador, o peso ainda é dividido por $`f_i`$ (§4.3). O código está em [`R/estimadores_tres_estagios.R:145`](../R/estimadores_tres_estagios.R#L145):

```r
w <- (B / num$b) * as.numeric(N_jh[celula] / n_cel[celula]) * resp$n_inscritos / m_k / f
```

**Exemplo:** `ActionSal417` está no torneio 4039583280 (bloco 5, low), com $`N_{jh} = 8`$, $`n_{jh} = 2`$, $`M_k = 180`$ e $`m_k = 4`$ respondentes. Com `n_jogos_dia` = 21,7, $`f_i = 21{,}7 \times 76/24 = 68{,}72`$, e

$$w = 9{,}5 \times \frac{8}{2} \times \frac{180}{4} \,\Big/\, 68{,}72 = \frac{1710}{68{,}72} = 24{,}88.$$

### 4.2 Estimador do total por estágios (Horvitz–Thompson)

O total é estimado de dentro para fora (Thompson, 2012, eq. 13.1–13.2; Cochran, 1977, cap. 11):

$$\hat T_k = M_k\,\bar y_k, \qquad \hat Y_{jh} = \frac{N_{jh}}{n_{jh}}\sum_{k} \hat T_k, \qquad \hat Y_j = \sum_h \hat Y_{jh}, \qquad \hat Y = \frac{B}{b}\sum_{j=1}^{b} \hat Y_j = \sum w\,y.$$

Implementação: `total_tres_estagios()` em [`R/estimadores_tres_estagios.R:44-82`](../R/estimadores_tres_estagios.R#L44-L82).

```r
tor$T <- tor$M * as.numeric(tapply(a, torneio, mean)[chave])     # linha 56: T_k = M_k ybar_k
Y = (N / nrow(d)) * sum(d$T),                                    # linha 63: Y_jh
total = (B / b) * sum(blocos$Y_j),                               # linha 77: Y
```

### 4.3 Média por jogador distinto: estimador razão com peso de multiplicidade

Como a unidade sorteada é a inscrição, quem joga mais torneios tem mais chance de entrar na amostra. Um jogador com $`f_i`$ inscrições no período aparece $`f_i`$ vezes na população. Atribuindo $`y_i/f_i`$ a cada uma dessas inscrições, a soma das $`f_i`$ inscrições dá $`y_i`$. Portanto:

$$\sum_{\text{inscrições}} \frac{y}{f} = \sum_{\text{jogadores}} y_i, \qquad \sum_{\text{inscrições}} \frac{1}{f} = N_{\text{jogadores}}.$$

O número de jogadores (ou de inscrições) da população também é desconhecido e precisa ser estimado. A média é então o **estimador razão** (Thompson, 2012, p. 175; Bolfarine e Bussab, 2005, eq. 8.13):

$$\hat{\bar Y} = \hat R = \frac{\hat Y(y/f)}{\hat Y(1/f)} = \frac{\sum w\,y_i/f_i}{\sum w/f_i}.$$

$`f_i`$ é aproximado por `n_jogos_dia` × 76/24, com mínimo 1 ([`frequencia_no_periodo()`, `R/estimadores_tres_estagios.R:25-27`](../R/estimadores_tres_estagios.R#L25-L27)). Na amostra, $`f_i`$ vai de 6,6 a 166,3, com mediana 34,4. A versão **por inscrição** usa $`f_i = 1`$ e serve de sensibilidade.

```r
num <- total_tres_estagios(resp, y / f, N_jh, B)   # linha 136
den <- total_tres_estagios(resp, 1 / f, N_jh, B)   # linha 137
estimativa <- num$total / den$total                # linha 139
```

O denominador estimado é $`\hat N \approx 6{.}098`$ jogadores distintos no período. Por inscrição, ele é $`\hat M_0 \approx 140{.}296`$ inscrições.

### 4.4 Proporções

Uma proporção é a média de uma variável indicadora (Bolfarine e Bussab, 2005, §7.5), então $`\hat P`$ usa o mesmo estimador da §4.3 com $`y_i = d_i`$:

$$\hat P = \frac{\sum w\, d_i/f_i}{\sum w/f_i}, \qquad d_i = \mathbb 1(\text{ROI}_i > 0) \ \text{ ou } \ d_i = \mathbb 1(\text{ROI}_i > 0 \text{ e } \text{lucro}_i > 0).$$

As duas indicadoras são criadas em [`R/dados.R:202-203`](../R/dados.R#L202-L203).

### 4.5 Variância: decomposição por estágios e linearização

A variância do total soma um termo por estágio, e cada termo tem sua correção para população finita (Cochran, 1977, cap. 11; Thompson, 2012, eq. 13.6–13.8):

$$
\widehat{\mathrm{Var}}(\hat Y) =
\underbrace{B^2\Bigl(1-\tfrac{b}{B}\Bigr)\frac{s_u^2}{b}}_{\text{entre blocos}}
+ \frac{B}{b}\sum_{j=1}^{b}\sum_{h}\Biggl[
\underbrace{N_{jh}^2\Bigl(1-\tfrac{n_{jh}}{N_{jh}}\Bigr)\frac{s_{1jh}^2}{n_{jh}}}_{\text{entre torneios}}
+ \underbrace{\frac{N_{jh}}{n_{jh}}\sum_{k} M_k^2\Bigl(1-\tfrac{m_k}{M_k}\Bigr)\frac{s_{2k}^2}{m_k}}_{\text{dentro dos torneios}}
\Biggr]
$$

- $`s_u^2`$ é a variância amostral dos $`\hat Y_j`$ entre os blocos.
- $`s_{1jh}^2`$ é a variância amostral dos $`\hat T_k`$ na célula.
- $`s_{2k}^2`$ é a variância amostral de $`y`$ entre os respondentes do torneio.

O fator $`M_k^2`$ é necessário porque os torneios têm tamanhos diferentes.

| Termo | Código |
|---|---|
| Entre torneios | `variancia_entre()`, [`R/estimadores_dois_estagios.R:65-68`](../R/estimadores_dois_estagios.R#L65-L68): `N_h^2 * (1 - n_h / N_h) * stats::var(z) / n_h` |
| Dentro dos torneios | `variancia_dentro()`, [`R/estimadores_dois_estagios.R:52-54`](../R/estimadores_dois_estagios.R#L52-L54): `(N_h / length(M)) * sum(M^2 * (1 - m / M) * s2 / m)` |
| Entre blocos e soma | [`R/estimadores_tres_estagios.R:75-78`](../R/estimadores_tres_estagios.R#L75-L78): `B^2 * (1 - b / B) * stats::var(blocos$Y_j) / b` e `entre_blocos + (B / b) * sum(blocos$v_j)` |

**Linearização de Taylor.** $`\hat R`$ é uma razão de dois totais estimados. A variância dele é aproximada pela variância do total da variável resíduo $`z_i = (y_i - \hat R)/f_i`$, dividida pelo quadrado do denominador (Lohr, 2022, cap. 9; Thompson, 2012, p. 175):

$$\widehat{\mathrm{Var}}(\hat R) \approx \frac{\widehat{\mathrm{Var}}(\hat Z)}{\hat N^{2}}, \qquad \hat Z = \sum w\,\frac{y_i - \hat R}{f_i}.$$

```r
lin <- total_tres_estagios(resp, (y - estimativa) / f, N_jh, B)   # linha 140
variancia <- lin$variancia / den$total^2                          # linha 141
```

Essa implementação foi validada contra os exemplos do Thompson (2012, §13.1, Exemplos 1 e 2) em [`tests/testthat/test-estimadores-tres-estagios.R`](../tests/testthat/test-estimadores-tres-estagios.R). Com um único bloco ($`b = B = 1`$), o estimador reproduz o Exemplo 2 do livro.

### 4.6 Intervalos de confiança

**ROI: intervalo t com $`gl = b - 1`$.** Com $`b/B`$ pequeno, a variância é estimada essencialmente a partir dos $`b`$ totais de bloco, então os graus de liberdade vêm do número de UPAs, não do número de jogadores (ADR-004):

$$\hat R \pm t_{b-1;\,0{,}975}\,\mathrm{EP}(\hat R), \qquad t_{3;\,0{,}975} = 3{,}182.$$

O intervalo é calculado em `montar_resultado()` ([`R/estimadores_aas.R:69-80`](../R/estimadores_aas.R#L69-L80)), e os graus de liberdade, na [linha 149](../R/estimadores_tres_estagios.R#L149) de `estimadores_tres_estagios.R`.

**Proporções: intervalo logit (ADR-012).** O intervalo de Wald é simétrico e não respeita o limite [0, 1]. Com $`\hat P`$ perto de 1 e só 3 gl, ele passa de 1: $`0{,}854 \pm 3{,}182 \times 0{,}0729 = [0{,}622;\ 1{,}086]`$. O intervalo logit é calculado na escala $`\ell = \log\{\hat P/(1-\hat P)\}`$, com erro-padrão pelo método delta, e depois volta para a escala de proporção:

$$\mathrm{EP}_\ell = \frac{\mathrm{EP}(\hat P)}{\hat P(1-\hat P)}, \qquad \mathrm{IC} = \Bigl[\mathrm{logit}^{-1}(\ell - t\,\mathrm{EP}_\ell);\ \mathrm{logit}^{-1}(\ell + t\,\mathrm{EP}_\ell)\Bigr].$$

O resultado é assimétrico e fica sempre dentro de (0, 1). É o mesmo método de `svyciprop(method = "logit")` do pacote `survey` (Lumley, 2010). Implementação: `ic_logit()`, [`R/estimadores_aas.R:94-101`](../R/estimadores_aas.R#L94-L101):

```r
ep_logit <- resultado$erro_padrao / (p * (1 - p))
limites <- stats::qlogis(p) + c(-1, 1) * t_crit * ep_logit
stats::setNames(stats::plogis(limites), c("li", "ls"))
```

**Conta para a proporção de lucrativos:**
- $`\ell = \log(0{,}8541/0{,}1459) = 1{,}767`$;
- $`\mathrm{EP}_\ell = 0{,}0729/(0{,}8541 \times 0{,}1459) = 0{,}585`$;
- $`\ell \pm 3{,}182 \times 0{,}585 = [-0{,}095;\ 3{,}629]`$;
- voltando à escala de proporção: $`[0{,}476;\ 0{,}974]`$.

### 4.7 Efeito do planejamento (EPA) e correlação intraclasse

O EPA compara a variância do plano com a de uma AAS de mesmo tamanho (Kish, 1965; Bolfarine e Bussab, 2005, §3.4). A variância da AAS é estimada na própria amostra de campo, com os pesos finais (ADR-005):

$$\mathrm{EPA} = \frac{\widehat{\mathrm{Var}}(\hat R)}{\bigl(1 - n/\hat N\bigr)\, s_y^2/n}, \qquad \mathrm{EPA} \approx 1 + (\bar m - 1)\,\rho \;\Rightarrow\; \hat\rho = \frac{\mathrm{EPA} - 1}{\bar m - 1}.$$

A aproximação de Kish é a eq. 8.26 de Bolfarine e Bussab (2005). Implementação: `epa_ponderado()`, [`R/estimadores_dois_estagios.R:174-190`](../R/estimadores_dois_estagios.R#L174-L190).

---

## 5. Resultados

Os números desta seção vêm de `Rscript scripts/estimar_campo.R --unidade jogador` e `--unidade inscricao` ([`scripts/estimar_campo.R`](../scripts/estimar_campo.R)), aplicados a [`coleta_jogadores.csv`](../data/raw/sharkscope/coleta_jogadores.csv) no commit da coleta encerrada.

### 5.1 Amostra efetiva

| | Sorteado | Usado na estimação |
|---|---:|---:|
| Blocos | 6 | 4 |
| Torneios | 32 | 24 (2 por célula) |
| Posições / respondentes | 160 | 67 inscrições (66 jogadores distintos) |
| Respondentes por torneio ($`\bar m`$) | 5 | 2,79 |

Entre os 72 respondentes, o ROI vai de −24,7% a 1064,4%, com mediana de 17,05% e média simples de 29,98%. 84,7% têm ROI > 0, e 72,2% têm ROI > 0 e lucro > 0.

### 5.2 Estimativas principais (por jogador distinto)

| Parâmetro | Estimativa | EP | IC 95% Wald | IC 95% logit |
|---|---:|---:|---|---|
| ROI médio (%) | 17,47 | 5,50 | [−0,04; 34,98] | — |
| Lucrativos (ROI > 0) | 0,854 | 0,073 | [0,622; **1,086**] | [0,476; 0,974] |
| ROI > 0 e lucro > 0 | 0,723 | 0,181 | [0,145; **1,300**] | [0,128; 0,979] |

Com $`gl = 3`$. Para as proporções, o intervalo principal é o logit.

### 5.3 Análises de sensibilidade

| Cenário | ROI médio (%) | EP | Lucrativos | IC logit | ROI > 0 e lucro > 0 | IC logit |
|---|---:|---:|---:|---|---:|---|
| Por jogador (principal) | 17,47 | 5,50 | 0,854 | [0,476; 0,974] | 0,723 | [0,128; 0,979] |
| Por inscrição ($`f_i = 1`$) | 18,72 | 4,41 | 0,870 | [0,550; 0,974] | 0,804 | [0,365; 0,967] |
| Por jogador, sem `MuoMadre` | 13,25 | 4,35 | — | — | — | — |
| Por inscrição, sem `MuoMadre` | 14,98 | 2,35 | — | — | — | — |

- **Por inscrição, as estimativas sobem um pouco.** Nessa versão, quem joga mais pesa mais, e esses jogadores tendem a ser lucrativos. A diferença é exatamente o efeito que o peso $`1/f_i`$ corrige.
- **Sem `MuoMadre`, o ROI cai cerca de 4 p.p.,** e o IC por jogador fica em [−0,59; 27,09]. Um único valor extremo move a média de forma visível, o que é esperado com 67 respondentes e uma distribuição de cauda longa.
- **Conglomerado último:** usando só o termo entre blocos sem a correção $`(1-b/B)`$, como fazem por padrão os pacotes `survey` e `samplics`, o EP do ROI vai de 5,50 para 5,59. Com $`b/B = 4/38`$, as duas versões ficam próximas.

### 5.4 Decomposição da variância

| Parâmetro | Variância total | Entre blocos | Dentro dos blocos (torneios + jogadores) |
|---|---:|---:|---:|
| ROI médio | 30,27 | 28,01 (**92,5%**) | 2,26 (7,5%) |
| Lucrativos | 0,00532 | 0,00432 (81,2%) | 0,00100 (18,8%) |
| ROI > 0 e lucro > 0 | 0,03291 | 0,03123 (94,9%) | 0,00168 (5,1%) |

A variação entre blocos domina. Na escala linearizada do ROI, os totais $`\hat Z_j`$ dos blocos são −2.218 (bloco 5), 2.156 (bloco 8), 256 (bloco 24) e −194 (bloco 30). Os blocos 5 e 8, os dois de domingo, puxam a estimativa em direções opostas. Isso responde à pergunta 2 do projeto: o horário (UPA) é a principal fonte de incerteza, e aumentar o número de blocos reduziria a variância muito mais do que consultar mais jogadores por torneio.

### 5.5 EPA e correlação intraclasse

| Parâmetro | EPA (por jogador) | $`\hat\rho`$ | EPA (por inscrição) | $`\hat\rho`$ |
|---|---:|---:|---:|---:|
| ROI médio | 0,44 | −0,31 | 0,32 | −0,38 |
| Lucrativos | 2,85 | 1,03 | 2,13 | 0,63 |
| ROI > 0 e lucro > 0 | 10,96 | 5,56 | 3,97 | 1,66 |

**Interpretação com cautela.** Valores de $`\hat\rho`$ fora de [−1/($`\bar m`$ − 1), 1] mostram que a aproximação de Kish não vale aqui. Ela supõe conglomerados de mesmo tamanho e pesos iguais, mas no campo $`\bar m = 2{,}79`$, os pesos variam de 1,7 a 1.000, e a variância vem quase toda de apenas 4 blocos. O EPA da proporção estrita, por exemplo, reflete sobretudo a diferença entre os blocos 5 e 24. A leitura qualitativa é que, para as proporções, o plano é bem menos eficiente que uma AAS de mesmo n (EPA > 1). Para o ROI, a variância amostral $`s_y^2`$ é inflada pelo valor extremo do `MuoMadre`, o que derruba o EPA.

---

## 6. Discussão e limitações

1. **Viés de não resposta.** 55% das posições ficaram sem dados. A correção por célula pressupõe que a não resposta é aleatória dentro da célula, mas quem mantém perfil público no SharkScope tende a ser o jogador mais regular e mais vencedor. Isso é coerente com a proporção de lucrativos muito alta (≈ 85%) para um jogo em que o rake faz a maioria perder. No Kaggle, com dados sintéticos, $`P = 0{,}19`$ e o ROI médio é −31,9%, mas as populações não são comparáveis diretamente. A ressalva principal é que as estimativas descrevem os **jogadores com perfil público**.
2. **Poucas UPAs.** Com $`b = 4`$, o IC do ROI usa t com 3 gl (3,18 contra 1,96), e a variância entre blocos domina (§5.4). Os blocos perdidos (34 e 36, terça à tarde e à noite) deixam o horário comercial de dia útil representado só pelo bloco 24.
3. **Viés de sobrevivência e janela do ROI.** O ROI é o da janela de 12 meses, não o do período de 76 h, e quem perde muito tende a parar de jogar e tem menos chance de estar ativo no período.
4. **Aproximações nas variáveis do plano.** $`M_k`$ é o total de entradas, com re-entries, e por isso superestima os jogadores distintos em torneios com re-entry. $`f_i`$ vem da média de jogos por dia em 12 meses, não das 76 h. As duas aproximações afetam os pesos.
5. **Valor extremo.** O ROI de 1064,4% (`MuoMadre`) foi conferido, mas sozinho desloca a média em cerca de 4 p.p. (§5.3).

## 7. Próximos passos

- Rodar de novo a simulação do Kaggle com n = 120, o tamanho do campo, e montar a comparação AAS × AAS estratificada × plano de campo (pergunta 4).
- Anotar o top 10 dos 8 torneios extras ([`top10_torneios.csv`](../data/raw/sharkscope/top10_torneios.csv)), que fica fora do plano amostral e serve para uma comparação descritiva.
- Completar a referência da técnica de estratos colapsados (ADR-011), que não chegou a ser usada.
- Levar estes resultados para o [`relatorio.Rmd`](relatorio.Rmd) final, com gráficos da distribuição do ROI e dos componentes de variância.

## 8. Reprodutibilidade

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'      # testes, incluindo os exemplos do Thompson
Rscript scripts/estimar_campo.R --unidade jogador      # estimativas principais (§5.2)
Rscript scripts/estimar_campo.R --unidade inscricao    # sensibilidade (§5.3)
```

Todos os sorteios, decisões e não respostas estão registrados, com data e semente, em [`data/raw/sharkscope/log_coleta.csv`](../data/raw/sharkscope/log_coleta.csv). Os registros de cada fase estão em [`fase0_sorteio_blocos.md`](fase0_sorteio_blocos.md) e [`fase1_torneios_sorteados.md`](fase1_torneios_sorteados.md).

---

## Referências

- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
- COCHRAN, W. G. *Sampling Techniques*. 3. ed. New York: Wiley, 1977.
- KISH, L. *Survey Sampling*. New York: Wiley, 1965.
- LOHR, S. L. *Sampling: Design and Analysis*. 3. ed. Boca Raton: CRC Press, 2022.
- LUMLEY, T. *Complex Surveys: A Guide to Analysis Using R*. Hoboken: Wiley, 2010.
- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
- NEFEDOV, S. *Poker Tournament Survival — Skill vs. Variance* [conjunto de dados]. Kaggle. <https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship>.

**Correspondência entre fórmulas e fontes**

| Fórmula / conceito | Seção | Fonte |
|---|---|---|
| Probabilidade de inclusão e peso em três estágios | §4.1 | Cochran (1977), cap. 10–11 |
| Total do torneio e do estrato | §4.2 | Thompson (2012), eq. 13.1–13.2 |
| Variância por estágios (entre + dentro, com FCPF) | §4.5 | Thompson (2012), eq. 13.6–13.8; Cochran (1977), cap. 11 |
| Estimador razão | §4.3 | Thompson (2012), p. 175; Bolfarine e Bussab (2005), eq. 8.13, Prop. 8.1 |
| Linearização de Taylor da razão | §4.5 | Lohr (2022), cap. 9 |
| Proporção como média de indicadora | §4.4 | Bolfarine e Bussab (2005), §7.5 |
| IC t com gl = b − 1 | §4.6 | Lohr (2022), cap. 9 |
| IC logit para proporção | §4.6 | Lumley (2010) |
| EPA e $`\mathrm{EPA} \approx 1 + \rho(\bar m - 1)`$ | §4.7 | Kish (1965); Bolfarine e Bussab (2005), §3.4 e eq. 8.24–8.26 |
| Não resposta | §3.3 | Thompson (2012), §14.5 |
