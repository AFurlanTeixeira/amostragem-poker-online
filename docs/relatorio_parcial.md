# Relatório parcial — Amostragem estratificada em três estágios no poker online

**ME430 — Técnicas de Amostragem** · Estatística, Unicamp · 2º semestre de 2026<br>
**Situação em:** 23/10/2026 (coleta de campo encerrada; análise preliminar). Revisado em 12/11/2026: EP por jackknife, componentes de variância, sensibilidade à não resposta e limitação das sementes<br>
**Grupo:** 
Arthur Agostinho Furlan Teixeira RA: 164363

---

## Resumo

Estimamos o ROI médio por jogador distinto e a proporção de jogadores lucrativos entre os inscritos em MTTs do PokerStars (buy-in ≥ US\$ 1,00) de 17/10/2026 20:00 a 21/10/2026 00:00. O plano tem três estágios: blocos de 2 h (UPA), torneios estratificados por buy-in dentro de cada bloco (USA) e jogadores (UTA), com ROI e lucro consultados no SharkScope.

Foram sorteados 6 dos 38 blocos, mas só 4 puderam ser listados. Nesses 4 blocos foram sorteados 32 torneios (24 originais e 8 extras, para compensar a não resposta) e 160 posições. Responderam 72 posições (45%). A estimação usa 67 respondentes em 24 torneios.

| Parâmetro (por jogador distinto) | Estimativa | EP linearizado | IC 95% | EP jackknife | IC 95% (jackknife) |
|---|---:|---:|---|---:|---|
| ROI médio (%) | 17,47 | 5,50 | [−0,04; 34,98] (t, 3 gl) | 5,21 | [0,89; 34,05] |
| Proporção de lucrativos (ROI > 0) | 0,854 | 0,073 | [0,476; 0,974] (logit) | 0,116 | [0,233; 0,991] |
| Proporção com ROI > 0 e lucro > 0 | 0,723 | 0,181 | [0,128; 0,979] (logit) | 0,291 | [0,025; 0,996] |

Com b = 4 blocos, os intervalos têm só 3 graus de liberdade, e a variância é estimada a partir de 4 totais de bloco. As estimativas devem ser lidas como as dos **jogadores com perfil público no SharkScope**: a não resposta é de 55% e provavelmente seletiva (§6). O erro-padrão linearizado é **otimista**: numa simulação do mesmo plano no Kaggle, com b = 4, ele captou só de 50% a 64% da variância real, enquanto o jackknife de blocos (JK1) captou de 94% a 102% (§6, item 3). Por isso as duas versões são reportadas lado a lado, e nas proporções o jackknife é a leitura mais prudente: o limite inferior da proporção de lucrativos cai de 0,48 para 0,23.

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

A classificação em estratos é feita por `estratificar_buyin()` ([`R/dados.R`](../R/dados.R)), e a moldura de torneios elegíveis, por `montar_moldura()` ([`R/dados.R`](../R/dados.R)).

---

## 3. Execução da coleta

### 3.1 Sorteios

Todos os sorteios são AAS sem reposição feitos com `sample.int()` do R, semente **164363**. Cada célula (bloco, estrato) e cada torneio recebe uma semente derivada da semente principal ([`semente_derivada()`, `R/sorteio.R`](../R/sorteio.R)). Assim, o sorteio de uma unidade não muda quando outras unidades entram depois.

**Limitação das sementes derivadas (ADR-016).** A função que deriva a semente soma os códigos dos caracteres do identificador, ponderados pela posição. Para IDs de torneio de 10 dígitos, essa soma tem poucos valores possíveis: os 83 torneios da moldura geram só 66 sementes distintas, e entre os 32 torneios sorteados há 2 pares com a mesma semente. Torneios com a mesma semente e tamanhos parecidos recebem as mesmas posições: 4039583402 ($`M_k = 114`$) e 4039583321 ($`M_k = 112`$) receberam 71, 19, 95, 42 e 103. Cada torneio continua sendo uma AAS de posições, então os pesos e as estimativas pontuais não são afetados. O que se perde é a independência dos sorteios do 3º estágio entre esses torneios, que a fórmula de variância supõe. O efeito numérico é pequeno (o 4039583402 ficou fora da estimação, com 1 respondente), e o sorteio não pode ser refeito depois da coleta, então a falha fica registrada como limitação.

| Estágio | Função | Linha do sorteio |
|---|---|---|
| Blocos ($`b = 6`$ de $`B = 38`$) | `sortear_blocos()` | [`R/sorteio.R`](../R/sorteio.R): `sample.int(nrow(blocos), b)` |
| Torneios ($`n_{jh} = 2`$ por célula) | `sortear_torneios()` | [`R/sorteio.R`](../R/sorteio.R): `sample.int(nrow(da_celula), tamanho)` |
| Torneios extras (§3.3) | `estender_torneios()` | [`R/sorteio.R`](../R/sorteio.R) |
| Posições ($`m_k = 5`$ de 1 a $`M_k`$) | `sortear_jogadores()` | [`R/sorteio.R`](../R/sorteio.R): `sample.int(M_k, tamanho)` |

Os 6 blocos sorteados foram 5, 8, 24, 30, 34 e 36. Em vez de transcrever a lista de inscritos, o 3º estágio sorteia **posições** na lista de resultados do torneio (1 = campeão), que já tem ordem fixa antes do sorteio.

Os sorteios usam uma propriedade da AAS sem reposição: **os $`n`$ primeiros elementos de uma permutação aleatória formam uma AAS de tamanho $`n`$**. O `sample.int()` sem reposição sorteia em sequência, então pedir $`n + 1`$ elementos com a mesma semente devolve os mesmos $`n`$ primeiros e mais um. Essa propriedade justificou duas decisões:

- passar $`m_k`$ de 2 titulares e 3 reservas para 5 titulares (ADR-010);
- sortear torneios extras numa célula sem alterar os já sorteados (ADR-011). `estender_torneios()` confere isso explicitamente ([`R/sorteio.R`](../R/sorteio.R)) e para com erro se a permutação não reproduzir os torneios já sorteados.

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

A exclusão está em [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R):

```r
chave <- paste(resp$bloco_id, resp$estrato, resp$torneio_id, sep = "|")
fica <- as.numeric(table(chave)[chave]) >= M_MINIMO_POR_TORNEIO
excluidos <- unique(resp$torneio_id[!fica])
resp <- resp[fica, , drop = FALSE]
```

Em seguida, $`n_{jh}`$ passa a contar só os torneios que ficam ([`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R)), o que redistribui o peso dos torneios perdidos entre os que ficaram na mesma célula. A suposição por trás disso é que a não resposta é aleatória dentro da célula (Thompson, 2012, §14.5).

**Taxa de não resposta** (`taxa_nao_resposta()`, [`R/estimadores_dois_estagios.R`](../R/estimadores_dois_estagios.R)):

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

Na estimação por jogador, o peso ainda é dividido por $`f_i`$ (§4.3). O código está em [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R):

```r
w <- (B / num$b) * as.numeric(N_jh[celula] / n_cel[celula]) * resp$n_inscritos / m_k / f
```

**Exemplo:** `ActionSal417` está no torneio 4039583280 (bloco 5, low), com $`N_{jh} = 8`$, $`n_{jh} = 2`$, $`M_k = 180`$ e $`m_k = 4`$ respondentes. Com `n_jogos_dia` = 21,7, $`f_i = 21{,}7 \times 76/24 = 68{,}72`$, e

$$w = 9{,}5 \times \frac{8}{2} \times \frac{180}{4} \,\Big/\, 68{,}72 = \frac{1710}{68{,}72} = 24{,}88.$$

### 4.2 Estimador do total por estágios (Horvitz–Thompson)

O total é estimado de dentro para fora (Thompson, 2012, eq. 13.1–13.2; Cochran, 1977, cap. 11):

$$\hat T_k = M_k\,\bar y_k, \qquad \hat Y_{jh} = \frac{N_{jh}}{n_{jh}}\sum_{k} \hat T_k, \qquad \hat Y_j = \sum_h \hat Y_{jh}, \qquad \hat Y = \frac{B}{b}\sum_{j=1}^{b} \hat Y_j = \sum w\,y.$$

Implementação: `total_tres_estagios()` em [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R).

```r
tor$T <- tor$M * as.numeric(tapply(a, torneio, mean)[chave])     # T_k = M_k ybar_k
Y = (N / n) * sum(d$T),                                    # Y_jh
total = (B / b) * sum(blocos$Y_j),                               # Y
```

### 4.3 Média por jogador distinto: estimador razão com peso de multiplicidade

Como a unidade sorteada é a inscrição, quem joga mais torneios tem mais chance de entrar na amostra. Um jogador com $`f_i`$ inscrições no período aparece $`f_i`$ vezes na população. Atribuindo $`y_i/f_i`$ a cada uma dessas inscrições, a soma das $`f_i`$ inscrições dá $`y_i`$. Portanto:

$$\sum_{\text{inscrições}} \frac{y}{f} = \sum_{\text{jogadores}} y_i, \qquad \sum_{\text{inscrições}} \frac{1}{f} = N_{\text{jogadores}}.$$

O número de jogadores (ou de inscrições) da população também é desconhecido e precisa ser estimado. A média é então o **estimador razão** (Thompson, 2012, p. 175; Bolfarine e Bussab, 2005, eq. 8.13):

$$\hat{\bar Y} = \hat R = \frac{\hat Y(y/f)}{\hat Y(1/f)} = \frac{\sum w\,y_i/f_i}{\sum w/f_i}.$$

$`f_i`$ é aproximado por `n_jogos_dia` × 76/24, com mínimo 1 ([`frequencia_no_periodo()`, `R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R)). Na amostra, $`f_i`$ vai de 6,6 a 166,3, com mediana 34,4. A versão **por inscrição** usa $`f_i = 1`$ e serve de sensibilidade.

```r
num <- total_tres_estagios(resp, y / f, N_jh, B)
den <- total_tres_estagios(resp, 1 / f, N_jh, B)
estimativa <- num$total / den$total
```

O denominador estimado é $`\hat N \approx 6{.}098`$ jogadores distintos no período. Por inscrição, ele é $`\hat M_0 \approx 140{.}296`$ inscrições.

### 4.4 Proporções

Uma proporção é a média de uma variável indicadora (Bolfarine e Bussab, 2005, §7.5), então $`\hat P`$ usa o mesmo estimador da §4.3 com $`y_i = d_i`$:

$$\hat P = \frac{\sum w\, d_i/f_i}{\sum w/f_i}, \qquad d_i = \mathbb 1(\text{ROI}_i > 0) \ \text{ ou } \ d_i = \mathbb 1(\text{ROI}_i > 0 \text{ e } \text{lucro}_i > 0).$$

As duas indicadoras são criadas em [`R/dados.R`](../R/dados.R).

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
| Entre torneios | `variancia_entre()`, [`R/estimadores_dois_estagios.R`](../R/estimadores_dois_estagios.R): `N_h^2 * (1 - n_h / N_h) * stats::var(z) / n_h` |
| Dentro dos torneios | `variancia_dentro()`, [`R/estimadores_dois_estagios.R`](../R/estimadores_dois_estagios.R): `(N_h / length(M)) * sum(M^2 * (1 - m / M) * s2 / m)` |
| Entre blocos e soma | [`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R): `B^2 * (1 - b / B) * stats::var(blocos$Y_j) / b` e `entre_blocos + dentro_blocos`, com `dentro_blocos <- (B / b) * sum(blocos$v_j)` |

**Linearização de Taylor.** $`\hat R`$ é uma razão de dois totais estimados. A variância dele é aproximada pela variância do total da variável resíduo $`z_i = (y_i - \hat R)/f_i`$, dividida pelo quadrado do denominador (Lohr, 2022, cap. 9; Thompson, 2012, p. 175):

$$\widehat{\mathrm{Var}}(\hat R) \approx \frac{\widehat{\mathrm{Var}}(\hat Z)}{\hat N^{2}}, \qquad \hat Z = \sum w\,\frac{y_i - \hat R}{f_i}.$$

```r
lin <- total_tres_estagios(resp, (y - estimativa) / f, N_jh, B)
variancia <- lin$variancia / den$total^2
```

Essa implementação foi validada contra os exemplos do Thompson (2012, §13.1, Exemplos 1 e 2) em [`tests/testthat/test-estimadores-tres-estagios.R`](../tests/testthat/test-estimadores-tres-estagios.R). Com um único bloco ($`b = B = 1`$), o estimador reproduz o Exemplo 2 do livro.

### 4.6 Intervalos de confiança

**ROI: intervalo t com $`gl = b - 1`$.** Com $`b/B`$ pequeno, a variância é estimada essencialmente a partir dos $`b`$ totais de bloco, então os graus de liberdade vêm do número de UPAs, não do número de jogadores (ADR-004):

$$\hat R \pm t_{b-1;\,0{,}975}\,\mathrm{EP}(\hat R), \qquad t_{3;\,0{,}975} = 3{,}182.$$

O intervalo é calculado em `montar_resultado()` ([`R/estimadores_aas.R`](../R/estimadores_aas.R)), e os graus de liberdade, em `estimar_media_tres_estagios()` ([`R/estimadores_tres_estagios.R`](../R/estimadores_tres_estagios.R)).

**Proporções: intervalo logit (ADR-012).** O intervalo de Wald é simétrico e não respeita o limite [0, 1]. Com $`\hat P`$ perto de 1 e só 3 gl, ele passa de 1: $`0{,}854 \pm 3{,}182 \times 0{,}0729 = [0{,}622;\ 1{,}086]`$. O intervalo logit é calculado na escala $`\ell = \log\{\hat P/(1-\hat P)\}`$, com erro-padrão pelo método delta, e depois volta para a escala de proporção:

$$\mathrm{EP}_\ell = \frac{\mathrm{EP}(\hat P)}{\hat P(1-\hat P)}, \qquad \mathrm{IC} = \Bigl[\mathrm{logit}^{-1}(\ell - t\,\mathrm{EP}_\ell);\ \mathrm{logit}^{-1}(\ell + t\,\mathrm{EP}_\ell)\Bigr].$$

O resultado é assimétrico e fica sempre dentro de (0, 1). É o mesmo método de `svyciprop(method = "logit")` do pacote `survey` (Lumley, 2010). Implementação: `ic_logit()`, [`R/estimadores_aas.R`](../R/estimadores_aas.R):

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

A aproximação de Kish é a eq. 8.26 de Bolfarine e Bussab (2005). O EPA também é separado na parte que vem só da desigualdade dos pesos, $`1 + \mathrm{CV}^2(w) = n\sum w^2/(\sum w)^2`$ (Kish, 1992), e no resto; $`n/(1 + \mathrm{CV}^2(w))`$ é o tamanho efetivo de amostra de Kish. Implementação: `epa_ponderado()`, [`R/estimadores_dois_estagios.R`](../R/estimadores_dois_estagios.R).

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

Com $`gl = 3`$. Para as proporções, o intervalo principal é o logit. Com tão poucas UPAs, a cobertura real dos intervalos deve ficar abaixo de 95% (§6, item 3).

**Jackknife de blocos (JK1), ao lado da linearização (ADR-014).** O JK1 recalcula $`\hat R`$ retirando um bloco por vez: $`\hat v_{JK} = \frac{b-1}{b}\sum_j (\hat R_{(j)} - \hat R)^2`$ (Wolter, 2007, cap. 4). Ele não depende da aproximação de Taylor, e na simulação do Kaggle ficou perto da variância real (§6, item 3).

| Parâmetro | EP linearizado | EP JK1 | IC 95% com o EP JK1 |
|---|---:|---:|---|
| ROI médio (%) | 5,50 | 5,21 | [0,89; 34,05] (t) |
| Lucrativos (ROI > 0) | 0,073 | 0,116 | [0,233; 0,991] (logit) |
| ROI > 0 e lucro > 0 | 0,181 | 0,291 | [0,025; 0,996] (logit) |

No ROI, os dois EP são próximos. Nas proporções, o JK1 é cerca de 60% maior, e os intervalos ficam bem mais largos. Com 4 blocos, o próprio JK1 é uma estimativa instável (3 gl), então a diferença entre os dois mede sobretudo o quanto a variância é mal determinada.

### 5.3 Análises de sensibilidade

| Cenário | ROI médio (%) | EP | Lucrativos | IC logit | ROI > 0 e lucro > 0 | IC logit |
|---|---:|---:|---:|---|---:|---|
| Por jogador (principal) | 17,47 | 5,50 | 0,854 | [0,476; 0,974] | 0,723 | [0,128; 0,979] |
| Por inscrição ($`f_i = 1`$) | 18,72 | 4,41 | 0,870 | [0,550; 0,974] | 0,804 | [0,365; 0,967] |
| Por jogador, sem `MuoMadre` | 13,25 | 4,35 | — | — | — | — |
| Por inscrição, sem `MuoMadre` | 14,98 | 2,35 | — | — | — | — |

- **Por inscrição, as estimativas sobem um pouco.** Nessa versão, quem joga mais pesa mais, e esses jogadores tendem a ser lucrativos. A diferença é exatamente o efeito que o peso $`1/f_i`$ corrige.
- **Sem `MuoMadre`, o ROI cai cerca de 4 p.p.,** e o IC por jogador fica em [−0,59; 27,09] (`--excluir MuoMadre`). Um único valor extremo move a média de forma visível, o que é esperado com 67 respondentes e uma distribuição de cauda longa. Nesse cenário, o EP por JK1 sobe para 7,30 (IC [−9,98; 36,48]), mais um sinal de que a variância é mal determinada com 4 blocos.
- **Conglomerado último:** usando só o termo entre blocos sem a correção $`(1-b/B)`$, como fazem por padrão os pacotes `survey` e `samplics`, o EP do ROI vai de 5,50 para 5,59. Com $`b/B = 4/38`$, as duas versões ficam próximas.

### 5.4 Decomposição da variância

**Os termos da fórmula não são componentes de variância.** O estimador da §4.5 tem duas parcelas, e a primeira concentra quase tudo:

| Parâmetro | Variância estimada | 1º termo, $`B^2(1-b/B)s_u^2/b`$ | 2º termo, $`(B/b)\sum_j \hat v_j`$ |
|---|---:|---:|---:|
| ROI médio | 30,27 | 28,01 (92,5%) | 2,26 (7,5%) |
| Lucrativos | 0,00532 | 0,00432 (81,2%) | 0,00100 (18,8%) |
| ROI > 0 e lucro > 0 | 0,03291 | 0,03123 (94,9%) | 0,00168 (5,1%) |

Esses percentuais **não** dizem que 80% a 95% da variância vem da diferença entre blocos. $`s_u^2`$ é calculada com os totais *estimados* $`\hat Y_j`$, que carregam o erro de amostrar torneios e jogadores dentro do bloco: $`E[s_u^2] = S_u^2 + \bar V`$, em que $`S_u^2`$ é a variância dos totais verdadeiros e $`\bar V`$ é a média das variâncias dentro dos blocos (Cochran, 1977, cap. 10–11). O 1º termo já contém, portanto, quase toda a variação de dentro. A soma das duas parcelas estima a variância total sem viés; a divisão entre elas é só aritmética. A simulação confirma: na população sintética do Kaggle, que não tem efeito de horário e em que o componente verdadeiro entre blocos é de 0,1% a 0,2% da variância, o 1º termo também concentra 90% da variância estimada ([`kaggle_tres_estagios.md`](kaggle_tres_estagios.md) §3.4).

**Componentes de variância.** Para separar as fontes, subtrai-se de cada variância amostral a parte que vem do estágio de baixo. Com $`\bar v`$ igual à média dos $`\hat v_j`$ e $`\bar w`$ igual à média, na célula, de $`M_k^2(1-m_k/M_k)s_{2k}^2/m_k`$:

$$
\underbrace{B^2\Bigl(1-\tfrac{b}{B}\Bigr)\frac{s_u^2-\bar v}{b}}_{\text{entre blocos}}
\;+\;
\underbrace{\Bigl(\tfrac{B}{b}\Bigr)^{2}\sum_{j,h} N_{jh}^2\Bigl(1-\tfrac{n_{jh}}{N_{jh}}\Bigr)\frac{s_{1jh}^2-\bar w_{jh}}{n_{jh}}}_{\text{entre torneios}}
\;+\;
\underbrace{\Bigl(\tfrac{B}{b}\Bigr)^{2}\sum_{j,h} N_{jh}^2\,\frac{\bar w_{jh}}{n_{jh}}}_{\text{dentro dos torneios}}
$$

As três parcelas somam exatamente a variância estimada (`componentes` em `total_tres_estagios()`). Por jogador distinto:

| Parâmetro | Entre blocos | Entre torneios | Dentro dos torneios |
|---|---:|---:|---:|
| ROI médio | 8,79 (29%) | −8,61 (→ 0) | 30,08 (99%) |
| Lucrativos | −0,0042 (→ 0) | 0,0074 (139%) | 0,0021 (40%) |
| ROI > 0 e lucro > 0 | 0,0169 (51%) | 0,0098 (30%) | 0,0062 (19%) |

Um componente estimado negativo se lê como zero. Cada um desses números é a diferença de duas variâncias estimadas com 3 graus de liberdade (4 blocos) ou 1 (2 torneios por célula), então são **muito instáveis**: o componente entre blocos vai de zero a metade da variância conforme a variável, e no ROI sem o `MuoMadre` ele passa de 29% para 50%.

Há ainda um viés conhecido: na simulação do Kaggle, os componentes "entre" calculados desta forma (variável linearizada em torno de $`\hat R`$, dividida por $`\hat N^2`$) ficam negativos em média, porque a subestimação da variância linearizada recai sobre eles ([`kaggle_tres_estagios.md`](kaggle_tres_estagios.md) §3.4). Os valores da tabela tendem, portanto, a subestimar o que vem dos blocos e dos torneios.

**Resposta à pergunta 2 do projeto.** Os dados não permitem dizer que o horário é a principal fonte de incerteza, nem que não é. O que eles mostram é que a variação **dentro dos blocos** (entre torneios e entre jogadores do mesmo torneio) responde por cerca de metade da variância ou mais nas três variáveis, e que o componente entre blocos não é distinguível de zero com b = 4. Na escala linearizada do ROI, os totais $`\hat Z_j`$ dos blocos são −2.218 (bloco 5), 2.156 (bloco 8), 256 (bloco 24) e −194 (bloco 30), mas a variância estimada de $`\hat Z_8`$ dentro do bloco (6,5 milhões, DP ≈ 2.550) é do tamanho do próprio total: a diferença entre os blocos 5 e 8 é compatível com erro de amostragem dentro deles.

A recomendação prática não muda: toda a variância cai com $`1/b`$, porque cada bloco a mais traz também mais torneios e mais jogadores. Sortear mais blocos é a forma mais direta de reduzir a variância e é a única que aumenta os graus de liberdade. O que os componentes acrescentam é que, com o número de blocos fixo, mais torneios por célula e mais respondentes por torneio também ajudariam, ao contrário do que a leitura dos termos sugeria.

### 5.5 EPA e correlação intraclasse

| Parâmetro | EPA (por jogador) | $`\hat\rho`$ | EPA (por inscrição) | $`\hat\rho`$ |
|---|---:|---:|---:|---:|
| ROI médio | 0,44 | −0,31 | 0,32 | −0,38 |
| Lucrativos | 2,85 | 1,03 | 2,13 | 0,63 |
| ROI > 0 e lucro > 0 | 10,96 | 5,56 | 3,97 | 1,66 |

**Desigualdade dos pesos.** Por jogador, $`1 + \mathrm{CV}^2(w) = 4{,}67`$: os 5 maiores pesos somam 53% da soma dos pesos, e o tamanho efetivo de amostra de Kish é de 14,4 em 67 (por inscrição, 2,92 e 22,9). Só a desigualdade dos pesos já levaria a um EPA perto de 4,7 se os pesos não tivessem relação com $`y`$. Como têm (o peso $`1/f_i`$ e o ROI andam juntos), o "resto" do EPA depois de descontar os pesos (0,10 no ROI; 2,35 na proporção estrita) é só aritmética e não mede conglomeração.

**Interpretação com cautela.** Valores de $`\hat\rho`$ fora de [−1/($`\bar m`$ − 1), 1] mostram que a aproximação de Kish não vale aqui. Ela supõe conglomerados de mesmo tamanho e pesos iguais, mas no campo $`\bar m = 2{,}79`$, os pesos variam de 1,7 a 1.000, e a variância é estimada com apenas 4 blocos. O EPA da proporção estrita, por exemplo, reflete sobretudo a diferença entre os totais estimados dos blocos 5 e 24. Por isso $`\hat\rho`$ fica só como registro (ADR-005). A leitura qualitativa é que, para as proporções, o plano é bem menos eficiente que uma AAS de mesmo n (EPA > 1). Para o ROI, a variância amostral $`s_y^2`$ é inflada pelo valor extremo do `MuoMadre`, o que derruba o EPA.

---

## 6. Discussão e limitações

1. **Viés de não resposta.** 55% das posições ficaram sem dados. A correção por célula pressupõe que a não resposta é aleatória dentro da célula, mas quem mantém perfil público no SharkScope tende a ser o jogador mais regular e mais vencedor. Isso é coerente com a proporção de lucrativos muito alta (≈ 85%) para um jogo em que o rake faz a maioria perder. No Kaggle, com dados sintéticos, $`P = 0{,}19`$ e o ROI médio é −31,9%, mas as populações não são comparáveis diretamente. A ressalva principal é que as estimativas descrevem os **jogadores com perfil público**.
2. **Poucas UPAs.** Com $`b = 4`$, o IC do ROI usa t com 3 gl (3,18 contra 1,96), e a variância é estimada a partir de só 4 totais de bloco (§5.4). Os blocos perdidos (34 e 36, terça à tarde e à noite) deixam o horário comercial de dia útil representado só pelo bloco 24.
3. **Intervalos otimistas (estreitos demais).** Um IC de 95% deveria conter o valor verdadeiro em 95% das amostras. Se o erro-padrão é subestimado, o intervalo encolhe na mesma proporção e acerta com menos frequência. No campo não dá para medir isso, porque o valor verdadeiro é desconhecido. Mas o mesmo plano, com os mesmos sorteios e estimadores, foi aplicado a uma população sintética montada com o Kaggle e com a estrutura do campo, em que o valor verdadeiro é conhecido ([`kaggle_tres_estagios.md`](kaggle_tres_estagios.md), ADR-013). Com 5.000 réplicas e $`b = 4`$, como no campo:

   | Parâmetro (por jogador) | Viés | EP real | EP linearizado (média) | $`\widehat{\mathrm{Var}}/\mathrm{Var}`$ linearizada | com $`N`$ verdadeiro | JK1 | Cobertura Wald | Cobertura logit | Cobertura JK1 (t) |
   |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
   | ROI médio (%) | −0,07 | 9,60 | 6,82 | 0,50 | 0,82 | 0,95 | 93,3% | — | 94,0% |
   | Lucrativos | −0,002 | 0,086 | 0,061 | 0,50 | 0,79 | 0,94 | 89,8% | 94,6% | 90,8% |

   Quatro conclusões saem daí:
   - **As estimativas pontuais são confiáveis:** o estimador é praticamente não viesado.
   - **O EP linearizado subestima a incerteza: capta cerca de metade da variância.** A causa não está nas fórmulas da §4.5: para o total, a variância estimada bate com a real. Ela está na razão. Trocar $`\hat N`$ pelo $`N`$ verdadeiro no denominador de $`\widehat{\mathrm{Var}}(\hat Z)/\hat N^2`$ leva a razão de 0,50 para cerca de 0,80: mais da metade do déficit vem de dividir por $`\hat N^2`$, que é ele mesmo muito variável com pesos de cauda pesada. O resto vem dos termos de ordem superior que a linearização ignora (Lohr, 2022, cap. 9). Por inscrição, a subestimação é menor (0,63 com $`b = 4`$ e 0,80 com $`b = 12`$).
   - **O jackknife de blocos (JK1) acerta a variância em média** (razão de 0,94 a 1,02 em todos os cenários), porque recalcula a razão inteira em cada réplica, com o denominador junto. Mas a cobertura do IC t com o EP JK1 melhora pouco (94,0% no ROI e 90,8% nos lucrativos): com 3 gl, o problema que resta é a instabilidade da variância estimada e a assimetria do estimador, não a média dela.
   - **O logit ajuda nas proporções:** a cobertura sobe de 89,8% para 94,6%.

   O campo tem pesos ainda mais variáveis (de 1,7 a 1.000) do que a simulação, então a subestimação ali pode ser igual ou maior. Por isso o EP JK1 é reportado ao lado do linearizado (§5.2, ADR-014). No ROI, os dois ficaram próximos (5,21 e 5,50); nas proporções, o JK1 é cerca de 60% maior. A versão de conglomerado último (§5.3) quase não muda o EP (5,59), então não resolve o problema. **Consequências para as conclusões:**
   - a proporção de lucrativos é alta na estimativa pontual (0,85), mas o limite inferior do IC depende do EP: 0,48 com o linearizado e 0,23 com o JK1. Os dados sustentam que a proporção entre os perfis públicos é bem maior que os 0,19 do Kaggle, mas não que a maioria é lucrativa;
   - o IC do ROI médio encosta em zero nas duas versões ([−0,04; 34,98] e [0,89; 34,05]), e sem o `MuoMadre` inclui zero. Os dados não permitem afirmar que o ROI médio dos jogadores com perfil público é positivo.
4. **Viés de sobrevivência e janela do ROI.** O ROI é o da janela de 12 meses, não o do período de 76 h, e quem perde muito tende a parar de jogar e tem menos chance de estar ativo no período.
5. **Aproximações nas variáveis do plano.** $`M_k`$ é o total de entradas, com re-entries, e por isso superestima os jogadores distintos em torneios com re-entry. $`f_i`$ vem da média de jogos por dia em 12 meses, não das 76 h. As duas aproximações afetam os pesos.
6. **Valor extremo.** O ROI de 1064,4% (`MuoMadre`) foi conferido, mas sozinho desloca a média em cerca de 4 p.p. (§5.3).

## 7. Próximos passos

Feito desde a primeira versão deste relatório:

- a simulação de AAS e AAS estratificada no Kaggle com n = 120 e n = 67, junto com o plano em três estágios ([`comparacao_planos.md`](comparacao_planos.md));
- o EP por jackknife de blocos ao lado do linearizado, com a cobertura avaliada na simulação (§5.2 e §6; ADR-014);
- os componentes de variância (§5.4) e a sensibilidade à não resposta (ADR-015; `Rscript scripts/estimar_campo.R`);
- a comparação descritiva entre o top 10 dos 24 torneios originais e a amostra aleatória ([`notas/aed_top10.md`](notas/aed_top10.md));
- a referência da técnica de estratos colapsados (Cochran, 1977, §5A.12), que não chegou a ser usada no campo.

Falta:

- anotar e consultar o top 10 dos 8 torneios extras;
- fechar o [`relatorio_final.Rmd`](relatorio_final.Rmd) e os slides.

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
