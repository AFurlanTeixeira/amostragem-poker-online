# Plano de Projeto: Comparação Metodológica de Planos Amostrais no Poker Online (Dataset Secundário vs. Coleta de Campo via SharkScope)

*Versão 2 — revisada com base em Thompson (2012) e Bolfarine & Bussab (2005).*

---

## Visão geral

O projeto usa **duas fontes de dados com papéis metodológicos distintos**:

1. **Dataset do Kaggle (população conhecida):** como todos os registros estão disponíveis, ele funciona como uma população finita conhecida. Sobre ela simulam-se, por Monte Carlo, planos de amostragem direta de elementos (AAS e AAS estratificada), e o viés e a variância reais dos estimadores podem ser medidos.
2. **Coleta de campo (SharkScope):** aplicação prática de uma **amostragem estratificada em dois estágios** (*stratified two-stage sampling*), em que os torneios são as unidades primárias (conglomerados) e os jogadores, as unidades secundárias.

> **Observação.** As duas fontes vêm de populações diferentes (outro site, outro período, outros jogadores). Portanto, a comparação entre elas é de **delineamentos e estimativas**. O Efeito do Planejamento (EPA) é calculado **somente dentro da população do SharkScope** (ver §4.4).

### Como funciona a amostragem em dois estágios no SharkScope

1. **Estratificação (faixa de buy-in):** os torneios da moldura são divididos em $H = 3$ estratos. A estratificação é uma partição da população, não um estágio de seleção.
2. **1º estágio — Unidade Primária de Amostragem (UPA):** em cada estrato, sorteiam-se **torneios** por AAS sem reposição. O torneio é o *conglomerado*.
3. **2º estágio — Unidade Secundária de Amostragem (USA):** em cada torneio sorteado, sorteiam-se **jogadores** (*nicknames*) da lista de inscritos, também por AAS sem reposição.
4. **Coleta:** para cada jogador sorteado, consulta-se o histórico no SharkScope e registram-se o **ROI** e o **lucro**.

---

## 1. Propósito e objetivos do estudo

1. **Comparação de delineamentos amostrais:** comparar os planos de amostragem direta de elementos (AAS e AAS estratificada, simulados no dataset do Kaggle) com um plano complexo aplicado em campo, a **amostragem estratificada em dois estágios** no SharkScope.
2. **Estimação de parâmetros de desempenho:** estimar o **ROI médio por jogador ($\mu$)** e a **proporção de jogadores lucrativos ($P$)** dentro do limite diário de consultas da plataforma.
3. **Estimação sob amostragem complexa:** aplicar os estimadores de total, média e variância da amostragem estratificada em dois estágios, com o Fator de Correção para População Finita (FCPF) nos dois estágios.
4. **Efeito do Planejamento (EPA/DEFF):** medir a perda (ou o ganho) de eficiência causada pelo agrupamento em torneios e pela estratificação, em comparação com uma AAS do mesmo número de jogadores **na mesma população**.
5. **Entregáveis:** relatório técnico e apresentação em slides, num ciclo de **20 dias**.

---

## 2. Moldura amostral e fontes de dados

### 2.1 Fonte 1: dataset do Kaggle (população conhecida)

* **Dataset:** [*Poker Tournament Survival — Skill vs. Variance*](https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship) (autor: `sergionefedov`). Arquivo `poker_tournament_survival.csv`: 45.000 jogadores × 17 colunas, sem valores ausentes.
* **Natureza:** dados **sintéticos**. A coluna `skill` é descrita como a "vantagem verdadeira de longo prazo" do jogador, uma variável latente que não existe em dados observados.
* **Unidade elementar:** o jogador, com o histórico agregado de 10 a 1.567 torneios. É análoga a um perfil consultado no SharkScope.
* **Variáveis usadas:** `realized_roi` (ROI, %), `profitable` (1 se ROI > 0) e `avg_buyin` (buy-in médio, em US$, para estratificar).
* **Parâmetros verdadeiros:** $\mu = -31{,}88\%$ (DP de 45,96 p.p.; ROI limitado entre −100% e +400%) e $P = 0{,}1939$.
* **Função:** servir de população finita conhecida para simular, por Monte Carlo, a **AAS** e a **AAS estratificada**. Como os parâmetros reais são conhecidos, é possível medir o viés, a variância e a cobertura dos intervalos de confiança.
* **Estratificação:**
  * **Principal:** faixas de `avg_buyin` iguais às do campo (§3.1): micro com 1.060 jogadores, low com 14.652 e mid/high com 29.288.
  * **Alternativa, só didática:** quartis de `skill`, que mostram o ganho de estratificar por uma variável correlacionada com o ROI. Ela não é reproduzível em campo, onde `skill` não é observável.
* **Limitações:**
  * O dataset não tem identificador de torneio. Por isso o plano em dois estágios não pode ser simulado nele e só é aplicado no campo.
  * `avg_buyin` é uma média por jogador, enquanto no campo o estrato é o buy-in do torneio.
  * A licença não aparece na página do Kaggle.
* **Resultado preliminar** (n = 60, 5.000 réplicas): o EPA da estratificação por buy-in foi de cerca de 0,98, sem ganho, porque o ROI médio é praticamente o mesmo nas três faixas. Por quartis de `skill`, o EPA foi de cerca de 0,95. A cobertura do IC de 95% ficou entre 94% e 95% em todos os casos.

### 2.2 Fonte 2: coleta de campo (SharkScope)

* **Função:** moldura real para aplicar a **amostragem estratificada em dois estágios**.
* **Período de referência:** os torneios concluídos numa janela fixa (por exemplo, uma semana). A listagem completa precisa ser montada **antes** do sorteio.
* **Unidade primária (UPA / conglomerado):** torneio.
* **Unidade secundária e elementar (USA):** jogador (*nickname*) inscrito no torneio.
* **Restrição operacional:** de 5 a 10 consultas por dia no SharkScope, o que limita a amostra de campo a $n \approx 50$ a $100$ jogadores no total.

---

## 3. Delineamento da amostragem estratificada em dois estágios

```
[ População: torneios do período de referência ]
              │
              ├── Estratificação por buy-in (h = 1, 2, 3)   ← partição, não estágio
              │
              ├── 1º estágio: AAS sem reposição de n_h torneios (UPA) em cada estrato
              │
              └── 2º estágio: AAS sem reposição de m_hk jogadores (USA) em cada torneio sorteado
```

### 3.1 Estratos ($H = 3$)

| Estrato | Faixa de buy-in |
| --- | --- |
| $h = 1$ — Micro/Nano | US\$ 0,00 a US\$ 4,99 |
| $h = 2$ — Low | US\$ 5,00 a US\$ 24,99 |
| $h = 3$ — Mid/High | US\$ 25,00 ou mais |

### 3.2 Primeiro estágio (UPA)

* **Procedimento:** em cada estrato $h$, monta-se a lista dos $N_h$ torneios do período, com o número de inscritos $M_{hk}$ de cada um, quando disponível.
* **Sorteio:** AAS sem reposição de $n_h$ torneios por estrato, com **$n_h \ge 2$**, o mínimo para estimar a variância entre torneios.

### 3.3 Segundo estágio (USA)

* **Procedimento:** para cada torneio $k$ sorteado no estrato $h$, obtém-se a lista dos $M_{hk}$ inscritos.
* **Sorteio:** AAS sem reposição de $m_{hk}$ jogadores, com **$m_{hk} \ge 2$**, o mínimo para estimar a variância dentro do torneio. Sorteia-se também uma **lista ordenada de reserva**, que será usada em caso de não resposta (§5.1).

### 3.4 Dimensionamento sugerido

Exemplo: $3$ estratos $\times$ $5$ torneios $\times$ $4$ jogadores $= 60$ consultas, que cabem em cerca de 8 a 12 dias de coleta. Pela aproximação $\text{EPA} \approx 1 + \rho_{int}(\bar m - 1)$ (Bolfarine & Bussab, eq. 8.26), quando a correlação intraclasse é positiva é mais eficiente **sortear mais torneios com menos jogadores em cada um** do que o contrário.

---

## 4. Estrutura matemática e estimadores

### 4.1 Notação

| Símbolo | Significado |
| --- | --- |
| $N_h$, $n_h$ | número de torneios no estrato $h$ (população e amostra) |
| $M_{hk}$, $m_{hk}$ | número de jogadores no torneio $k$ do estrato $h$ (população e amostra) |
| $y_{hki}$ | ROI do jogador $i$ do torneio $k$ do estrato $h$ |
| $M_h = \sum_{k=1}^{N_h} M_{hk}$ | total de jogadores no estrato $h$ |
| $M_0 = \sum_h M_h$ | total de jogadores na população |
| $\mu = \tau / M_0$ | ROI médio por jogador (parâmetro de interesse) |

### 4.2 Estimadores pontuais

**Média amostral e total estimado de cada torneio** (Thompson, eq. 13.1):

$$\bar y_{hk} = \frac{1}{m_{hk}} \sum_{i=1}^{m_{hk}} y_{hki}, \qquad \hat y_{hk} = M_{hk}\, \bar y_{hk}$$

**Total estimado no estrato $h$** (Thompson, eq. 13.2; não viesado):

$$\hat\tau_h = \frac{N_h}{n_h} \sum_{k=1}^{n_h} M_{hk}\, \bar y_{hk}$$

**Total estimado na população** (Thompson, §11.1; os estratos são independentes):

$$\hat\tau = \sum_{h=1}^{H} \hat\tau_h$$

**Média por jogador.** A forma depende de o total de jogadores $M_0$ ser conhecido ou não:

* **(a) $M_0$ conhecido** (os inscritos de todos os torneios da moldura aparecem no lobby). O estimador é não viesado (Thompson, p. 174):

$$\hat\mu = \frac{\hat\tau}{M_0}, \qquad M_0 = \sum_{h=1}^{H} \sum_{k=1}^{N_h} M_{hk}$$

* **(b) $M_0$ desconhecido.** Usa-se o estimador razão combinado (Thompson, p. 175; Bolfarine & Bussab, eq. 8.13). Ele é viesado, mas o viés é desprezível em amostras grandes:

$$\hat\mu_R = \frac{\sum_h \hat\tau_h}{\sum_h \hat M_h}, \qquad \hat M_h = \frac{N_h}{n_h} \sum_{k=1}^{n_h} M_{hk}$$

> **Atenção.** O denominador **não** pode ser a soma dos inscritos apenas dos torneios sorteados, $\sum_{k \in s} M_{hk}$. O numerador estima um total populacional e o denominador também precisa estar na escala da população.

**Proporção de jogadores lucrativos.** Define-se a variável indicadora $y_{hki} = 1$ se ROI $> 0$ e $0$ caso contrário. Com isso, $\hat P$ é obtido pelas **mesmas fórmulas** da média, e o mesmo vale para sua variância (Bolfarine & Bussab, §7.5).

> **Interpretação.** $\mu$ é a **média dos ROIs individuais**. Ela é diferente do ROI agregado (lucro total ÷ buy-ins totais), que é uma razão de totais e exigiria registrar também o total investido por jogador.

### 4.3 Variância e intervalo de confiança

**Variância estimada do total no estrato $h$** (Thompson, eq. 13.6). O primeiro termo mede a variação **entre torneios**; o segundo, a variação **dentro dos torneios**. Cada termo tem seu próprio FCPF:

$$\hat V(\hat\tau_h) = N_h^2 \left(1 - \frac{n_h}{N_h}\right) \frac{s_{uh}^2}{n_h} + \frac{N_h}{n_h} \sum_{k=1}^{n_h} M_{hk}^2 \left(1 - \frac{m_{hk}}{M_{hk}}\right) \frac{s_{hk}^2}{m_{hk}}$$

com:

$$s_{uh}^2 = \frac{1}{n_h - 1} \sum_{k=1}^{n_h} \left(\hat y_{hk} - \bar{\hat y}_h\right)^2 \quad \text{(Thompson, eq. 13.7)}$$

$$s_{hk}^2 = \frac{1}{m_{hk} - 1} \sum_{i=1}^{m_{hk}} \left(y_{hki} - \bar y_{hk}\right)^2 \quad \text{(Thompson, eq. 13.8)}$$

**Variância da média.** Como os estratos são sorteados de forma independente, as variâncias se somam (Thompson, §11.1–11.2):

$$\hat V(\hat\mu) = \frac{1}{M_0^2} \sum_{h=1}^{H} \hat V(\hat\tau_h)$$

**Forma equivalente com pesos.** Com $W_h = M_h / M_0$ (a proporção de **jogadores** no estrato) e $\bar M_h = M_h / N_h$:

$$\hat V(\hat\mu) = \sum_{h=1}^{H} W_h^2 \left[ \left(1 - \frac{n_h}{N_h}\right) \frac{s_{1h}^2}{n_h} + \frac{1}{n_h N_h} \sum_{k=1}^{n_h} \left(\frac{M_{hk}}{\bar M_h}\right)^2 \left(1 - \frac{m_{hk}}{M_{hk}}\right) \frac{s_{hk}^2}{m_{hk}} \right]$$

Aqui, $s_{1h}^2$ é a variância amostral de $\hat y_{hk} / \bar M_h$. O fator $(M_{hk}/\bar M_h)^2$ é indispensável porque os torneios têm tamanhos diferentes; ele só some quando todos os torneios têm o mesmo número de inscritos.

**Caso (b), estimador razão.** No primeiro termo, substitui-se $\hat y_{hk}$ pelos resíduos $e_{hk} = \hat y_{hk} - \hat\mu_R M_{hk}$, e a variância desses resíduos é calculada dentro de cada estrato. Depois, divide-se por $\hat M_0^2 = \left(\sum_h \hat M_h\right)^2$ (Thompson, p. 175; Bolfarine & Bussab, Proposição 8.1).

**Intervalo de confiança de 95%:**

$$\hat\mu \pm t_{gl;\,0{,}975} \sqrt{\hat V(\hat\mu)}$$

Com poucas UPAs, usa-se a distribuição $t$ com graus de liberdade aproximados (Thompson, §11.3, aproximação de Satterthwaite). Na prática, é comum adotar $gl \approx \sum_h n_h - H$. Como o ROI costuma ter distribuição assimétrica e de cauda pesada, o relatório deve discutir essa limitação da aproximação normal.

### 4.4 Efeito do Planejamento (EPA / DEFF)

O EPA compara a variância do mesmo estimador, **na mesma população**, sob o plano adotado e sob a AAS (Bolfarine & Bussab, §3.4):

$$\text{EPA} = \frac{\hat V(\hat\mu)}{\hat V_{AAS}(\bar y)}, \qquad \hat V_{AAS}(\bar y) = \left(1 - \frac{n}{M_0}\right) \frac{s_y^2}{n}, \qquad n = \sum_{h,k} m_{hk}$$

Aqui, $s_y^2$ é a variância entre jogadores, estimada **a partir da própria amostra do SharkScope** (ponderada pelos pesos amostrais). O EPA **não** é calculado com a variância do Kaggle.

**Interpretação** (Bolfarine & Bussab, eq. 8.24 e 8.26):

$$\text{EPA} \approx 1 + \rho_{int}(\bar m - 1)$$

* $\text{EPA} > 1$: o agrupamento em torneios custa eficiência ($\rho_{int} > 0$).
* $\text{EPA} < 1$: o ganho da estratificação por buy-in supera a perda causada pelo agrupamento.

A correlação intraclasse estimada, $\hat\rho_{int} \approx (\text{EPA} - 1)/(\bar m - 1)$, deve ser apresentada no relatório.

### 4.5 Métricas de comparação

| Fonte / plano | Estimativa | Variância | IC 95% | Observação |
| --- | --- | --- | --- | --- |
| Kaggle: AAS (Monte Carlo) | $\bar y$ | $V_{AAS}$ | cobertura empírica | parâmetro real conhecido: viés e EQM exatos |
| Kaggle: AAS estratificada (Monte Carlo) | $\bar y_{es}$ | $V_{AE}$ | cobertura empírica | EPA da estratificação $= V_{AE}/V_{AAS}$ (Bolfarine & Bussab, §4.3.4) |
| SharkScope: estratificada em dois estágios | $\hat\mu$ (ou $\hat\mu_R$) | $\hat V(\hat\mu)$ | $t$ com $gl$ aproximado | EPA e $\hat\rho_{int}$ calculados na própria amostra |

---

## 5. Erros não amostrais e viés de seleção

1. **Perfis privados (não resposta).**
   * Se um jogador sorteado tiver perfil privado, ele é **substituído** pelo próximo nome da **lista de reserva sorteada no mesmo torneio**. O termo correto é "substituição": em amostragem, "reposição" significa sorteio com reposição.
   * A substituição só evita viés se a não resposta for aleatória **dentro de cada torneio**. Essa suposição deve ser declarada no relatório. Sob ela, $m_{hk}$ passa a ser o número de respondentes do torneio.
   * Se os perfis privados forem sistematicamente diferentes (por exemplo, jogadores profissionais com ROI mais alto), resta um viés de não resposta (Thompson, §14.5). Registre e reporte a **taxa de não resposta por estrato** e discuta o sentido provável desse viés.
2. **Efeito do agrupamento.**
   * Jogadores do mesmo torneio tendem a ter perfis de habilidade parecidos ($\rho_{int} > 0$). O estimador de variância em dois estágios não remove essa dependência; ele a **incorpora**, e por isso a variância tende a ser maior do que na AAS. É exatamente isso que o EPA mede (§4.4).
3. **Cobertura da moldura.** Torneios fora da janela de referência ou fora do que o SharkScope rastreia não pertencem à população-alvo. As conclusões valem apenas para a população efetivamente coberta.

---

## 6. Cronograma operacional (20 dias)

| Período | Etapa | Atividades principais |
| --- | --- | --- |
| **Dias 1 a 3** | **Fase 0: Planejamento e sorteio** | • Tratamento do dataset do Kaggle e simulações de Monte Carlo (AAS e AAS estratificada).<br>• Definição da janela de referência, montagem da moldura de torneios por estrato ($N_h$, $M_{hk}$).<br>• Sorteio dos torneios (1º estágio) e das listas de jogadores e de reserva (2º estágio). |
| **Dias 4 a 13** | **Fase 1: Coleta de campo** | • Consulta diária de 5 a 10 *nicknames* no SharkScope.<br>• Registro de ROI (%), lucro (US\$) e status de resposta (perfil público ou privado). |
| **Dias 14 a 16** | **Fase 2: Análise e comparação** | • Cálculo de $\hat\mu$ (ou $\hat\mu_R$), $\hat P$ e suas variâncias, separando os componentes entre torneios e dentro dos torneios.<br>• IC 95%, EPA e $\hat\rho_{int}$.<br>• Comparação com os resultados das simulações no Kaggle. |
| **Dias 17 e 18** | **Fase 3: Relatório** | • Redação do relatório: amostragem direta de elementos vs. amostragem estratificada em dois estágios, discussão da não resposta e das limitações. |
| **Dias 19 e 20** | **Fase 4: Slides e revisão** | • Apresentação com tabelas comparativas e gráficos dos componentes de variância.<br>• Revisão final. |

---

## Referências

* NEFEDOV, S. *Poker Tournament Survival — Skill vs. Variance* [conjunto de dados]. Kaggle. Disponível em: <https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship>.
* THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
  * Cap. 11: amostragem estratificada, §11.1–11.3 (p. 141–146).
  * Cap. 13: delineamentos em múltiplos estágios, §13.1, eq. 13.1–13.8 (p. 171–175); estimador razão (p. 175); decomposição da variância, eq. 13.10 (p. 179).
  * §14.5: erros não amostrais e não resposta (p. 190–193).
* BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
  * §3.4: definição do Efeito do Planejamento (EPA).
  * §4.3.4: EPA na amostragem estratificada.
  * §7.5: estimação de proporções em conglomerados.
  * Cap. 8: amostragem em dois estágios; Teorema 8.1; estimador razão (eq. 8.13, Proposição 8.1); EPA e correlação intraclasse (eq. 8.24–8.26).
