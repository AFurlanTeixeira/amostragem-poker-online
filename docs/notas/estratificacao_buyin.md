## Escolha do número de estratos de buy-in

**Decisão:** usar $H = 3$ estratos de buy-in na coleta de campo e na simulação com o dataset do Kaggle:

| Estrato | Faixa de buy-in |
|---|---|
| Micro/Nano | US\$ 0,00 a US\$ 4,99 |
| Low | US\$ 5,00 a US\$ 24,99 |
| Mid/High | US\$ 25,00 ou mais |

**Alternativa avaliada e descartada:** $H = 5$ estratos (Micro/Nano < US\$ 5; Low US\$ 5–9,99; Mid-Low US\$ 10–24,99; Mid-High US\$ 25–99,99; High ≥ US\$ 100).

### 1. Os estratos não diferem quanto ao ROI

A estratificação só reduz a variância do estimador quando as médias dos estratos são diferentes entre si: a variância da média estratificada depende apenas da variabilidade *dentro* dos estratos (Thompson, 2012, §11.4; Bolfarine & Bussab, §4.3.4). No dataset do Kaggle (45.000 jogadores, população conhecida), o ROI médio e a proporção de lucrativos são praticamente iguais em todas as faixas de buy-in, tanto com 3 quanto com 5 estratos.

**Com 5 estratos:**

| Estrato | % dos jogadores | ROI médio | DP do ROI | P(lucrativo) |
|---|---|---|---|---|
| Micro (< US\$ 5) | 2,4% | −31,9% | 43,1 | 0,20 |
| Low (US\$ 5–9,99) | 7,4% | −32,8% | 46,3 | 0,18 |
| Mid-Low (US\$ 10–24,99) | 25,1% | −32,3% | 45,4 | 0,19 |
| Mid-High (US\$ 25–99,99) | 49,1% | −31,6% | 46,0 | 0,20 |
| High (≥ US\$ 100) | 15,9% | −31,6% | 47,0 | 0,20 |

**Com 3 estratos:**

| Estrato | % dos jogadores | ROI médio | DP do ROI | P(lucrativo) |
|---|---|---|---|---|
| Micro (< US\$ 5) | 2,4% | −31,9% | 43,1 | 0,20 |
| Low (US\$ 5–24,99) | 32,6% | −32,4% | 45,6 | 0,19 |
| Mid/High (≥ US\$ 25) | 65,1% | −31,6% | 46,2 | 0,20 |

A correlação entre ROI e buy-in médio na população é de 0,0006.

### 2. Simulação: nenhum ganho de eficiência

Simulação de Monte Carlo com AAS e AAS estratificada (alocação proporcional), n = 60, 5.000 réplicas, seed = 42 (`scripts/simular_kaggle.R`):

| Estratificação | EPA no ROI | EPA em P | Cobertura do IC 95% (estratificada) |
|---|---|---|---|
| 3 estratos de buy-in | 0,98 | 0,99 | 94,4% / 94,0% |
| 5 estratos de buy-in | 1,00 | 1,02 | 94,4% / 94,3% |
| Quartis de `skill` (referência didática) | 0,95 | 0,94 | 95,1% / 94,8% |

Com 5 estratos, o EPA chega a ficar ligeiramente acima de 1: o mínimo de 2 unidades no estrato Micro e o arredondamento da alocação desviam a amostra da proporcionalidade, sem nenhum ganho em troca. Para comparar, estratificar por uma variável de fato associada ao ROI (`skill`, correlação de 0,23) dá EPA ≈ 0,95, próximo de $1 - R^2 \approx 1 - 0{,}23^2$. Isso mostra que o problema não está no método, mas na falta de associação entre buy-in e ROI.

### 3. Custo amostral no plano em dois estágios

Na coleta de campo, cada estrato precisa de pelo menos $n_h = 2$ torneios para estimar a variância entre torneios (§3.2 do plano). Com o orçamento de cerca de 60 consultas ao SharkScope:

| | 3 estratos | 5 estratos |
|---|---|---|
| Torneios por estrato × jogadores por torneio | 5 × 4 | 3 × 4 |
| Total de torneios ($\sum n_h$) | 15 | 15 |
| Graus de liberdade do IC ($\sum n_h - H$) | 12 | 10 |
| gl da variância entre torneios, por estrato ($n_h - 1$) | 4 | 2 |

Mais estratos dividem o mesmo orçamento em mais partes. Isso deixa a variância de cada estrato estimada com pouquíssimos graus de liberdade e alarga o IC (quantil $t$ maior), sem ganho de precisão que compense.

### 4. Viabilidade da moldura

Torneios com buy-in ≥ US\$ 100 são relativamente raros no lobby. Na janela de referência, o estrato High pode ter $N_h$ pequeno demais para sortear 3 torneios. Isso exigiria aumentar a janela ou recombinar estratos depois da coleta.

### Conclusão

Os 3 estratos atendem ao objetivo didático de aplicar e avaliar a estratificação, preservam graus de liberdade para a estimação da variância em dois estágios e são viáveis na moldura do SharkScope. A divisão em 5 estratos não traria ganho de precisão, segundo a população de referência, e aumentaria o custo amostral.

**Ressalva:** a evidência vem do dataset do Kaggle, que é sintético e usa o buy-in *médio* do jogador. No campo, o estrato é o buy-in do *torneio*. A comparação do ROI médio entre os 3 estratos de campo, na seção de resultados, servirá para verificar se a conclusão se mantém nos dados reais.

**Referências:** THOMPSON, S. K. *Sampling*. 3. ed. Wiley, 2012, §11.4–11.5. BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. Blucher, 2005, §4.3.4.
