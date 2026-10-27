# Plano em três estágios aplicado ao Kaggle

**ME430 — Técnicas de Amostragem** · Estatística, Unicamp · 2º semestre de 2026<br>
**Situação em:** 23/10/2026 · decisão em [ADR-013](../.ai/modelagem.md) · semente 164363

O plano usado em campo no SharkScope foi aplicado à população do Kaggle, com os mesmos sorteios e os mesmos estimadores: blocos de 2 h, torneios estratificados por buy-in dentro de cada bloco e jogadores. Como o Kaggle é uma população conhecida, dá para verificar o que o campo não permite: se o estimador é não viesado, se o erro-padrão está certo, se o IC cobre o valor verdadeiro com a frequência anunciada e qual é o EPA.

Para reproduzir:

```bash
Rscript scripts/simular_kaggle_tres_estagios.R --n-rep 5000 --b 4,6,12 --seed 164363
```

Os resultados ficam em `data/processed/kaggle_tres_estagios_*.csv`, fora do git, como os demais derivados do Kaggle.

---

## 1. População sintética com a estrutura do campo

O dataset do Kaggle tem uma linha por jogador, sem horário nem ID de torneio (ADR-007). A estrutura de blocos e torneios é construída a partir do campo por `montar_populacao_blocos()` ([`R/simulacao_kaggle_tres_estagios.R:36`](../R/simulacao_kaggle_tres_estagios.R#L36)):

1. **Blocos:** $`B = 38`$, como no período de campo.
2. **Torneios por bloco e estrato:** em cada bloco e estrato, $`N_{jh}`$ é sorteado entre os 4 valores observados no SharkScope nos blocos 5, 8, 24 e 30. O $`M_k`$ de cada torneio é sorteado entre os $`M_k`$ observados no estrato (83 torneios da listagem real).
3. **Jogadores:** os $`M_k`$ lugares de cada torneio são preenchidos por AAS sem reposição entre os jogadores do Kaggle do mesmo estrato (faixa de `avg_buyin`), com probabilidade proporcional a `tournaments_played`. Um jogador pode estar em vários torneios, nunca duas vezes no mesmo. A posição na "lista de resultados" é a ordem de preenchimento.
4. **Frequência $`f_i`$:** é o número exato de inscrições do jogador na população. Por isso o parâmetro **por jogador distinto** é conhecido, e o peso $`1/f_i`$ pode ser avaliado sem a aproximação por `n_jogos_dia` usada em campo. O estimador usa a coluna `f_i` quando ela existe ([`R/estimadores_tres_estagios.R:128-129`](../R/estimadores_tres_estagios.R#L128-L129)).

| | Valor |
|---|---|
| Blocos / torneios | 38 / 800 (micro 257, low 337, mid/high 206) |
| Inscrições ($`M_0`$) | 151.948 |
| Jogadores distintos | 21.793 (dos 45.000 do Kaggle) |
| $`f_i`$ | mediana 2, média 6,97, máximo 178 (micro ≈ 59, low ≈ 6, mid/high ≈ 1,3) |

**Parâmetros verdadeiros** (`parametros_verdadeiros()`, [linha 92](../R/simulacao_kaggle_tres_estagios.R#L92)):

| | ROI médio (%) | Proporção de lucrativos |
|---|---:|---:|
| Por jogador distinto | −33,96 | 0,1692 |
| Por inscrição | −34,92 | 0,1539 |
| Kaggle inteiro (45.000 jogadores, referência) | −31,88 | 0,1939 |

**Limitação da construção:** dentro de cada estrato, os torneios são preenchidos ao acaso. Por isso não existe correlação intraclasse real (ρ ≈ 0 por construção), e as diferenças entre blocos vêm só de $`N_{jh}`$ e $`M_k`$. Um efeito de horário, como o que domina a variância no campo, não está presente aqui.

---

## 2. Sorteio oficial: o campo reproduzido passo a passo

Mesma semente e mesmos tamanhos do campo ($`b = 6`$, $`n_{jh} = 2`$, $`m_k = 5`$), com as funções de campo `sortear_blocos()`, `sortear_torneios()`, `sortear_jogadores()` e `estender_torneios()` (`sortear_amostra_kaggle()`, [linha 156](../R/simulacao_kaggle_tres_estagios.R#L156)).

- **Blocos:** 34, 30, 36, 8, 24 e 5, na ordem do sorteio. São os mesmos do campo, porque a semente e o $`B`$ são os mesmos. Aqui nenhum bloco é perdido.
- **Não resposta:** simulada como Bernoulli por estrato, com as taxas observadas no campo (micro 63,3%, low 56,7%, mid/high 40,0%). É a hipótese do ADR-011: não resposta aleatória dentro da célula.
- **Regra de torneios extras (ADR-011):** `aplicar_torneios_extras()` ([linha 200](../R/simulacao_kaggle_tres_estagios.R#L200)) foi necessária: **13 torneios extras** e **1 colapso**. No bloco 24, o micro esgotou os 3 torneios e foi juntado ao low (`colapsar_celula()`, [linha 240](../R/simulacao_kaggle_tres_estagios.R#L240)).
- **Amostra final:** 49 torneios, 245 posições e 123 respondentes (50%). Ficaram fora da estimação 10 torneios com 1 respondente.

| Parâmetro | Verdadeiro | Estimativa | EP | IC 95% (t, 5 gl) | Cobre? |
|---|---:|---:|---:|---|:---:|
| ROI por jogador (%) | −33,96 | −36,65 | 4,04 | [−47,03; −26,27] | sim |
| Lucrativos por jogador | 0,169 | 0,165 | 0,052 | logit [0,070; 0,341] | sim |
| ROI por inscrição (%) | −34,92 | −24,91 | 3,57 | [−34,09; −15,73] | **não** |
| Lucrativos por inscrição | 0,154 | 0,232 | 0,057 | logit [0,118; 0,406] | sim |

A regra de torneios extras e o colapso funcionaram de ponta a ponta, e o estimador rodou sem ajustes. O IC do ROI por inscrição errou o valor verdadeiro por 0,8 p.p. Um único sorteio não basta para avaliar o plano, e a §3 mostra que esse tipo de erro acontece mais do que os 5% nominais.

---

## 3. Monte Carlo: propriedades do plano

`simular_tres_estagios()` ([linha 267](../R/simulacao_kaggle_tres_estagios.R#L267)) roda **5.000 réplicas** para cada $`b \in \{4, 6, 12\}$, sem não resposta. A réplica $`r`$ usa a semente 164363 + $`r`$. Cada réplica também sorteia uma **AAS de mesmo $`n`$** ($`n = 30b`$) da população de jogadores (ou de inscrições), que serve de referência para o EPA empírico. As medidas são calculadas por `resumir_tres_estagios()` ([linha 318](../R/simulacao_kaggle_tres_estagios.R#L318)):

- $`\text{viés} = \overline{\hat\theta} - \theta`$;
- $`\mathrm{EP}_{MC}`$ = DP das 5.000 estimativas;
- $`\mathrm{EP}_{est} = \sqrt{\overline{\widehat{\mathrm{Var}}}}`$;
- cobertura = fração dos IC que contêm $`\theta`$;
- $`\mathrm{EPA}_{emp} = \mathrm{Var}_{MC}(\text{plano}) / \mathrm{Var}_{MC}(\text{AAS})`$, ao lado da média do EPA estimado em cada réplica (§4.7 do relatório parcial).

### 3.1 Por jogador distinto (parâmetro principal)

| Parâmetro | $`b`$ | Viés | $`\mathrm{EP}_{MC}`$ | $`\mathrm{EP}_{est}`$ | $`\widehat{\mathrm{Var}}/\mathrm{Var}_{MC}`$ | Cobertura Wald | Cobertura logit | EPA empírico | EPA estimado |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ROI (%) | 4 | −0,07 | 9,60 | 6,82 | 0,50 | 93,3% | — | 6,75 | 3,25 |
| ROI (%) | 6 | −0,12 | 8,82 | 6,35 | 0,52 | 92,4% | — | 8,56 | 4,20 |
| ROI (%) | 12 | −0,20 | 7,38 | 5,78 | 0,61 | 92,0% | — | 12,05 | 6,67 |
| Lucrativos | 4 | −0,002 | 0,086 | 0,061 | 0,50 | 89,8% | 94,6% | 6,35 | 3,07 |
| Lucrativos | 6 | −0,002 | 0,078 | 0,057 | 0,53 | 88,0% | 93,1% | 7,76 | 3,91 |
| Lucrativos | 12 | −0,002 | 0,064 | 0,051 | 0,64 | 87,1% | 92,2% | 10,68 | 6,10 |

AAS de mesmo $`n`$, para comparação: EP do ROI de 3,69, 3,01 e 2,13 (b = 4, 6 e 12), com cobertura de 94,5% a 94,7%; EP dos lucrativos de 0,034, 0,028 e 0,020, com cobertura de 94,3% a 95,1%.

### 3.2 Por inscrição (sensibilidade)

| Parâmetro | $`b`$ | Viés | $`\mathrm{EP}_{MC}`$ | $`\mathrm{EP}_{est}`$ | $`\widehat{\mathrm{Var}}/\mathrm{Var}_{MC}`$ | Cobertura Wald | Cobertura logit | EPA empírico | EPA estimado |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ROI (%) | 4 | −0,09 | 6,46 | 5,13 | 0,63 | 94,5% | — | 3,69 | 2,29 |
| ROI (%) | 6 | −0,08 | 5,63 | 4,66 | 0,69 | 93,5% | — | 4,20 | 2,81 |
| ROI (%) | 12 | −0,08 | 4,25 | 3,80 | 0,80 | 94,0% | — | 4,69 | 3,72 |
| Lucrativos | 4 | 0,000 | 0,062 | 0,050 | 0,64 | 92,4% | 95,8% | 3,61 | 2,28 |
| Lucrativos | 6 | 0,000 | 0,054 | 0,045 | 0,70 | 91,9% | 94,7% | 4,08 | 2,80 |
| Lucrativos | 12 | 0,000 | 0,041 | 0,037 | 0,81 | 92,0% | 94,2% | 4,55 | 3,70 |

### 3.3 De onde vem a subestimação da variância

Em 1.500 réplicas extras, a variância estimada do **total** (Horvitz–Thompson) teve média igual à variância real: $`\widehat{\mathrm{Var}}/\mathrm{Var}_{MC}`$ = 1,06 com $`b = 4`$ e 1,00 com $`b = 12`$. Isso confirma que as fórmulas da §4.5 do relatório parcial estão certas. A subestimação aparece só na **razão**: 0,64 com $`b = 4`$ e 0,89 com $`b = 12`$. Ela vem da linearização de Taylor de $`\hat R = \hat Y/\hat N`$, que só é exata assintoticamente e, com poucas UPAs, ignora termos de ordem superior (Lohr, 2022, cap. 9). Com o peso $`1/f_i`$, o efeito é maior: no caso por jogador, a razão fica entre 0,50 e 0,61.

---

## 4. Conclusões

1. **O estimador é praticamente não viesado** em todos os cenários: o viés fica abaixo de 0,6% do valor verdadeiro no ROI e é de no máximo 0,0022 na proporção (1,3% do valor verdadeiro). Isso valida a cadeia de pesos $`w = (B/b)(N_{jh}/n_{jh})(M_k/m_k)/f_i`$, incluindo o peso de multiplicidade.
2. **O plano é bem menos eficiente que uma AAS de mesmo $`n`$, mesmo sem correlação intraclasse:** o EPA empírico vai de 3,6 a 12. Aqui ρ ≈ 0, então a perda vem da **variação dos pesos**. O plano sorteia 2 torneios por estrato e 5 jogadores por torneio, independentemente do tamanho, e os torneios micro têm $`M_k`$ grandes, com jogadores de $`f_i`$ alto. Por jogador, a variação maior dos pesos ($`1/f_i`$ de 1/178 a 1) torna o EPA ainda maior. O EPA cresce com $`b`$ no caso por jogador; não investigamos a causa.
3. **O erro-padrão estimado é otimista.** Ele captura só de 50% a 80% da variância real, e a cobertura nominal de 95% vira 87% a 94,5% com o intervalo de Wald. A cobertura não melhora com $`b`$ nesta faixa. No caso por jogador, ela até cai um pouco (de 93,3% para 92,0% no ROI), porque a subestimação diminui devagar enquanto o t com mais gl fica mais estreito.
4. **O IC logit corrige a cobertura das proporções:** de 87–92% com Wald para 92–96% com logit. Com P ≈ 0,17, o limite superior do Wald quase nunca passa de 1 (no máximo em 0,7% das réplicas). O ganho vem da assimetria do intervalo, não do truncamento.
5. **O EPA estimado numa única amostra subestima o EPA real:** em média, fica entre 48% e 79% dele, pela mesma subestimação da variância do item 3.

**Consequências para o campo** ([relatório parcial](relatorio_parcial.md)):

- **Os intervalos do campo provavelmente são estreitos demais.** O campo usou $`b = 4`$ e tem pesos ainda mais variáveis (de 1,7 a 1.000), então a cobertura real deve ficar abaixo de 95%. Vale reportar isso como limitação e, se houver tempo, comparar com um IC por bootstrap de UPAs ou com a versão de conglomerado último.
- **O logit continua sendo a escolha certa para as proporções** (ADR-012).
- **A dominância da variação entre blocos é real.** No campo, ela foi de 81% a 95% da variância. Aqui, sem efeito de horário, a variância entre blocos é quase nula. Isso indica que o horário (público diferente por bloco) tem efeito no campo, e não é um artefato do estimador.

---

## Referências

- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005. §3.4 (EPA).
- COCHRAN, W. G. *Sampling Techniques*. 3. ed. New York: Wiley, 1977. Cap. 10–11 (amostragem em vários estágios).
- KISH, L. *Survey Sampling*. New York: Wiley, 1965. (Efeito do planejamento e variação dos pesos.)
- LOHR, S. L. *Sampling: Design and Analysis*. 3. ed. Boca Raton: CRC Press, 2022. Cap. 9 (linearização e variância em planos complexos).
- LUMLEY, T. *Complex Surveys: A Guide to Analysis Using R*. Hoboken: Wiley, 2010. (IC logit.)
- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012. Cap. 13 (estimadores em vários estágios) e §14.5 (não resposta).
- NEFEDOV, S. *Poker Tournament Survival — Skill vs. Variance* [conjunto de dados]. Kaggle. <https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship>.
