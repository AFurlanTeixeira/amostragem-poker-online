# Comparação dos planos amostrais: AAS, AAS estratificada e três estágios

**ME430 — Técnicas de Amostragem** · Estatística, Unicamp · 2º semestre de 2026<br>
**Situação em:** 05/11/2026 (revisado em 12/11/2026: alocação proporcional com Σ n_h = n e linhas de Neyman) · pergunta 4 do projeto · decisões em [ADR-007](../.ai/modelagem.md) e [ADR-013](../.ai/modelagem.md)

Esta comparação junta três peças: os planos de amostragem direta de elementos simulados no Kaggle (AAS e AAS estratificada), o plano de campo em três estágios simulado numa população sintética com a estrutura do SharkScope ([`kaggle_tres_estagios.md`](kaggle_tres_estagios.md)), e o campo ([`relatorio_parcial.md`](relatorio_parcial.md)).

Há dois tamanhos de amostra:

- **n = 120:** o tamanho planejado (ADR-010), que mede o plano como foi desenhado;
- **n = 67:** as inscrições que de fato entraram na estimação de campo depois da não resposta (§5.1 do relatório parcial). Com n = 67, o Kaggle e o campo têm a mesma quantidade de informação, e a diferença que sobra é o efeito do plano.

No plano em três estágios, o n = 67 é aproximado por $`b = 4`$, $`n_{jh} = 2`$ e $`m_k = 3`$ (n = 72). No campo, a não resposta deixou em média $`\bar m = 2{,}79`$ respondentes por torneio.

Para reproduzir:

```bash
Rscript scripts/simular_kaggle.R --estratificar-por buyin --n 120 --n-rep 5000 --seed 42
Rscript scripts/simular_kaggle.R --estratificar-por buyin --n 67  --n-rep 5000 --seed 42
Rscript scripts/simular_kaggle.R --estratificar-por skill --n 120 --n-rep 5000 --seed 42
Rscript scripts/simular_kaggle.R --estratificar-por skill --n 67  --n-rep 5000 --seed 42
Rscript scripts/simular_kaggle_tres_estagios.R --b 4,6,12 --n-rep 5000 --seed 164363         # m_k = 5
Rscript scripts/simular_kaggle_tres_estagios.R --b 4 --m-k 3 --n-rep 5000 --seed 164363      # m_k = 3
```

Os resultados ficam em `data/processed/simulacao_kaggle_<estrato>_n<n>_<variavel>.csv` e `data/processed/kaggle_tres_estagios_monte_carlo[_mk3].csv`, fora do git.

---

## 1. Tabela comparativa

$`\mathrm{EP}_{MC}`$ é o desvio-padrão das 5.000 estimativas (o EP real), $`\mathrm{EP}_{est} = \sqrt{\overline{\widehat{\mathrm{Var}}}}`$ é o EP que o estimador anuncia em média, e o EPA empírico é $`\mathrm{Var}_{MC}(\text{plano}) / \mathrm{Var}_{MC}(\text{AAS de mesmo } n)`$. O plano em três estágios é avaliado por jogador distinto, o parâmetro principal.

### 1.1 ROI médio (%)

| Fonte | Plano | n | $`\mathrm{EP}_{MC}`$ | $`\mathrm{EP}_{est}`$ | Cobertura | EPA |
|---|---|---:|---:|---:|---:|---:|
| Kaggle | AAS | 120 | 4,20 | 4,19 | 94,6% | 1 |
| Kaggle | AAS estratificada (buy-in, proporcional) | 120 | 4,20 | 4,19 | 94,9% | 1,00 |
| Kaggle | AAS estratificada (buy-in, Neyman) | 120 | 4,17 | 4,18 | 94,6% | 0,98 |
| Kaggle | AAS estratificada (skill, proporcional) | 120 | 4,06 | 4,08 | 94,8% | 0,96 |
| Kaggle | AAS estratificada (skill, Neyman) | 120 | 4,07 | 4,07 | 94,9% | 0,96 |
| Kaggle sintético | Três estágios ($`b = 4`$, $`m_k = 5`$) | 120 | 9,60 | 6,82 | 93,3% | 6,75 |
| Kaggle | AAS | 67 | 5,64 | 5,59 | 94,3% | 1 |
| Kaggle | AAS estratificada (buy-in, proporcional) | 67 | 5,70 | 5,62 | 94,4% | 1,02 |
| Kaggle | AAS estratificada (buy-in, Neyman) | 67 | 5,61 | 5,60 | 94,5% | 0,99 |
| Kaggle | AAS estratificada (skill, proporcional) | 67 | 5,54 | 5,49 | 94,7% | 0,96 |
| Kaggle | AAS estratificada (skill, Neyman) | 67 | 5,47 | 5,46 | 95,0% | 0,94 |
| Kaggle sintético | Três estágios ($`b = 4`$, $`m_k = 3`$) | 72 | 11,58 | 8,22 | 93,3% | 5,94 |
| **SharkScope** | **Três estágios (campo)** | **67** | — | **5,50** | — | **0,44*** |

### 1.2 Proporção de lucrativos

| Fonte | Plano | n | $`\mathrm{EP}_{MC}`$ | $`\mathrm{EP}_{est}`$ | Cobertura Wald | Cobertura logit | EPA |
|---|---|---:|---:|---:|---:|---:|---:|
| Kaggle | AAS | 120 | 0,036 | 0,036 | 94,9% | — | 1 |
| Kaggle | AAS estratificada (buy-in, proporcional) | 120 | 0,036 | 0,036 | 95,5% | — | 1,00 |
| Kaggle | AAS estratificada (buy-in, Neyman) | 120 | 0,036 | 0,036 | 95,3% | — | 1,01 |
| Kaggle | AAS estratificada (skill, proporcional) | 120 | 0,035 | 0,035 | 94,7% | — | 0,96 |
| Kaggle | AAS estratificada (skill, Neyman) | 120 | 0,035 | 0,035 | 94,2% | — | 0,92 |
| Kaggle sintético | Três estágios ($`b = 4`$, $`m_k = 5`$) | 120 | 0,086 | 0,061 | 89,8% | 94,6% | 6,35 |
| Kaggle | AAS | 67 | 0,048 | 0,048 | 95,0% | — | 1 |
| Kaggle | AAS estratificada (buy-in, proporcional) | 67 | 0,049 | 0,048 | 94,5% | — | 1,02 |
| Kaggle | AAS estratificada (buy-in, Neyman) | 67 | 0,049 | 0,048 | 94,9% | — | 1,02 |
| Kaggle | AAS estratificada (skill, proporcional) | 67 | 0,048 | 0,047 | 95,0% | — | 0,98 |
| Kaggle | AAS estratificada (skill, Neyman) | 67 | 0,046 | 0,046 | 94,1% | — | 0,93 |
| Kaggle sintético | Três estágios ($`b = 4`$, $`m_k = 3`$) | 72 | 0,105 | 0,073 | 85,9% | 93,9% | 5,57 |
| **SharkScope** | **Três estágios (campo)** | **67** | — | **0,073** | — | — | **2,85*** |

\* EPA estimado numa única amostra (§5.5 do relatório parcial); no campo não existe $`\mathrm{EP}_{MC}`$ nem cobertura, porque o valor verdadeiro é desconhecido.

**As populações não são as mesmas.** O Kaggle inteiro tem 45.000 jogadores (ROI médio −31,88%, P = 0,194). A população sintética do plano em três estágios usa os 21.793 jogadores sorteados para algum torneio (ROI −33,96%, P = 0,169). O campo descreve os jogadores com perfil público no SharkScope. O que se compara são as propriedades dos planos (EP, cobertura, EPA), não as médias.

---

## 2. Leitura

1. **A estratificação por buy-in não traz ganho** (EPA de 0,98 a 1,02, nas duas alocações), porque o ROI médio é praticamente o mesmo nas três faixas ([nota](notas/estratificacao_buyin.md)). Por skill, o ganho é pequeno: de 2% a 4% com alocação proporcional e de 4% a 8% com a de Neyman. As diferenças entre n = 120 e n = 67, e os EPA pouco acima de 1, estão dentro do ruído de Monte Carlo: com 5.000 réplicas, a razão de duas variâncias tem EP de cerca de 0,03. As duas alocações somam exatamente n (arredondamento pelos maiores restos), então a comparação com a AAS é de mesmo tamanho.
2. **A perda de amostra pela não resposta aumentou o EP em cerca de 34%.** Passar de n = 120 para n = 67 aumenta o EP da AAS por um fator de 1,34 (de 4,20 para 5,64 no ROI), igual a $`\sqrt{120/67} = 1{,}34`$. Esse é só o custo em variância. O viés de não resposta, que no campo provavelmente existe (quem tem perfil público tende a ganhar mais), não aparece aqui, porque a simulação não tem não resposta.
3. **O plano em três estágios é de 5,6 a 6,8 vezes menos eficiente que uma AAS de mesmo n.** Com ρ ≈ 0 por construção, a perda vem da variação dos pesos ([`kaggle_tres_estagios.md`](kaggle_tres_estagios.md) §4). É o preço de não ter moldura: a AAS e a AAS estratificada só são possíveis no Kaggle porque cada linha é um jogador; no SharkScope, é preciso passar por blocos e torneios.
4. **Só os planos de elementos têm EP confiável.** Na AAS e na AAS estratificada, $`\mathrm{EP}_{est} \approx \mathrm{EP}_{MC}`$ e a cobertura fica em 94–96%. No plano em três estágios, o EP estimado capta só metade da variância ($`\widehat{\mathrm{Var}}/\mathrm{Var}_{MC} \approx 0{,}50`$ nos dois tamanhos), e a cobertura de Wald cai para 86–93%. O jackknife de blocos (JK1) acerta a variância em média (razão de 0,91 a 0,95), mas melhora pouco a cobertura. O IC logit traz as proporções de volta para 94–95%.
5. **O EPA do campo não é comparável ao simulado.** No campo, o EPA estimado foi 0,44 no ROI e 2,85 nos lucrativos, contra 5,9 e 5,6 na simulação de mesmo tamanho. Três razões: a aproximação de Kish não vale com $`\bar m = 2{,}79`$ e pesos de 1,7 a 1.000; o `MuoMadre` infla $`s_y^2`$ e derruba o EPA do ROI; e, na própria simulação, o EPA estimado numa amostra fica em média na metade do real (2,9 contra 5,9 no ROI com $`m_k = 3`$). Por isso, a afirmação apoiada pelos dados é qualitativa: o plano de campo é bem menos eficiente que uma AAS de mesmo n.
