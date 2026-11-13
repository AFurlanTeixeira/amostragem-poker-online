# Decisões de Modelagem

Registro, no formato ADR, das decisões estatísticas do projeto. O delineamento
de campo e as fórmulas estão em [`docs/Metodologia.md`](../docs/Metodologia.md);
o [`docs/plano_projeto.md`](../docs/plano_projeto.md) é a versão inicial (dois
estágios). As referências completas estão em [`docs/referencias.md`](../docs/referencias.md).

## ADR-001: Delineamento de campo, estratificada em três estágios

1º estágio (UPA): AAS sem reposição de b = 6 blocos de 2 h entre B = 38
(4 efetivos, ADR-008). Estratos: 3 faixas de buy-in (Micro US$ 1–4,99; Low
US$ 5–24,99; Mid/High >= US$ 25), aplicadas **dentro de cada bloco**, formando
células (bloco × estrato). 2º estágio (USA): AAS sem reposição de n_jh = 2
torneios por célula. 3º estágio (UTA): AAS sem reposição de m_k = 5 jogadores
por torneio (ADR-010). A estratificação é uma partição, não um estágio
(Thompson, p. 171). Substitui o plano inicial em dois estágios (torneio →
jogador), que exigia listar todos os torneios do período.
Por que 3 estratos e não 5: ver [`docs/notas/estratificacao_buyin.md`](../docs/notas/estratificacao_buyin.md).

## ADR-002: Estimador da média

- Campo: estimador razão R = Ŷ / M̂0 (Metodologia §7.5), porque só os blocos
  sorteados são listados e o M0 dos 38 blocos é desconhecido
  (`estimar_media_tres_estagios()`).
- Pesos por célula, w = (B/b)(N_jh/n_jh)(M_k/m_k), nunca um N_h/n_h único
  por estrato somando blocos diferentes.
- Nunca dividir pela soma dos inscritos apenas dos torneios sorteados.
- `estimar_media_dois_estagios()` (não viesado com M0 conhecido, ou razão)
  fica como núcleo validado contra os exemplos do Thompson.

## ADR-003: Variância

Metodologia §8.1 (Cochran cap. 11): B²(1 − b/B) s_u²/b entre blocos +
(B/b) Σ_j Var(Ŷ_j). Var(Ŷ_j) soma, por célula, os termos de Thompson eq. 13.6;
o termo dentro dos torneios leva M_k² (torneios de tamanhos diferentes).
No estimador razão, a variância é a do total de z_i = (y_i − R)/f_i,
dividida por M̂0² (linearização; Bolfarine Prop. 8.1).

## ADR-004: IC

IC t com gl = b − 1 = 3 no campo: com b/B pequeno, a variância é estimada
essencialmente a partir dos b totais de bloco. Isso é conservador, e o relatório
deve discutir que o IC é largo por causa do número de blocos, não do número de
jogadores. Satterthwaite na AAS estratificada (Thompson eq. 11.4). O EP
linearizado é otimista com poucos blocos; o EP por jackknife é reportado ao
lado (ADR-014).

## ADR-005: EPA

EPA = Var(plano) / Var_AAS, com Var_AAS = (1 − n/N̂) s_y²/n e s_y² estimada
na amostra de campo com os pesos finais (ADR-002, incluindo 1/f_i do ADR-009)
(Bolfarine §3.4). O Kaggle **não** entra no EPA de campo: são populações
diferentes. No Kaggle, o EPA empírico compara a AAS estratificada com a AAS
na mesma população.

O EPA é separado em duas partes (Kish, 1992; `epa_ponderado()`):
`epa_pesos` = 1 + CV²(w) = n Σw²/(Σw)², a perda só pela variação dos pesos, e
`epa_conglomerado` = EPA / `epa_pesos`, o que sobra. No campo (por jogador),
`epa_pesos` = 4,67: o n efetivo de Kish é 67/4,67 ≈ 14, e os 5 maiores pesos
somam cerca de metade de Σw. A fórmula de Kish supõe pesos não relacionados
com y, o que não vale aqui (peso 1/f_i e ROI andam juntos), então
`epa_conglomerado` (0,10 no ROI, 2,35 no lucrativo estrito) é só um resíduo
aritmético, sem leitura como efeito de conglomeração.

rho_int = (EPA − 1)/(m̄ − 1) (Bolfarine eq. 8.26) **não é interpretável** neste
plano e fica só como registro: a aproximação supõe conglomerados de mesmo
tamanho e pesos iguais, usa m̄ por torneio (2,79) enquanto a variância é
estimada entre blocos, e dá valores fora de [−1/(m̄ − 1), 1] no campo. O EPA
estimado numa única amostra também subestima o real (em média, cerca de
metade dele na simulação do ADR-013), então a leitura é qualitativa.

## ADR-006: Não resposta (perfis privados e "Anônimo")

Sem reservas desde o ADR-010: o jogador que não responde sai, e m_k passa a
ser o número de respondentes do torneio (mínimo 2). Hipótese: não resposta
aleatória dentro do torneio. Células abaixo do mínimo recebem torneios
extras (ADR-011). Reportar a taxa por estrato e discutir o viés
residual (Thompson §14.5). A sensibilidade a essa hipótese está no ADR-015.

## ADR-007: Dataset do Kaggle

- Colunas: `realized_roi` → `roi`; `profitable` → `lucrativo` (equivale a ROI > 0
  em 100% das linhas); `avg_buyin` → estrato por faixa de buy-in.
- Dados sintéticos (`skill` é a vantagem verdadeira, latente). Sem ID de torneio:
  diretamente, só é possível simular AAS e AAS estratificada. O plano em
  estágios é simulado numa população sintética com a estrutura do campo (ADR-013).
- Estratificação principal: faixas de `avg_buyin` iguais às do campo, para manter
  a comparabilidade. Resultado: EPA ≈ 1,00 (n = 120), porque o ROI não varia
  entre as faixas.
- Estratificação alternativa (didática): quartis de `skill`, EPA ≈ 0,96. Ela não
  é reproduzível em campo, onde `skill` não é observável.
- Alocações proporcional e de Neyman, as duas arredondadas pelos maiores
  restos (`arredondar_alocacao()`), para que Σ n_h = n e o EPA compare planos
  de mesmo tamanho. O `round()` com mínimo de 2 por estrato dava n = 68 para
  n = 67 e inflava o ganho da estratificação em cerca de 1,5%.
- Ressalva: `avg_buyin` é a média do jogador ao longo de vários torneios; no campo,
  o estrato é o buy-in do torneio. As duas classificações não são idênticas.
- Tamanho da amostra simulada: n = 120, o mesmo do campo (ADR-010).
- Licença: não informada na página. O CSV fica fora do git.

## ADR-008: Perda dos blocos 34 e 36 (não resposta de UPA)

Os blocos 34 (20/10 14:00–16:00) e 36 (20/10 18:00–20:00) não foram listados
a tempo: em 22/10 o custo de busca do SharkScope não alcança mais esses
horários. Decisão: b efetivo = 4 (blocos 5, 8, 24 e 30), peso do 1º estágio
B/b = 38/4 = 9,5 e s_u² com 3 gl. Sem substituição: a listagem feita por
engano de 16:00–18:00 e 20:00–22:00 (blocos 35 e 37) foi descartada, porque
trocar UPAs por escolha tira a base probabilística do 1º estágio. Hipótese:
perda não relacionada ao ROI (causa: acesso à fonte). Ressalva: os blocos
perdidos são de terça à tarde e à noite, e dia útil depois das 14h fica
representado só pelo bloco 24. Discutir no relatório. Não se redefine o
período (os torneios dos outros blocos já foram sorteados).

## ADR-009: Parâmetro, ROI médio por jogador distinto

O plano sorteia inscrições (jogador × torneio), e quem joga mais tem mais
chance de entrar. Para estimar a média **por jogador**, cada respondente
recebe o peso de multiplicidade 1/f_i, com f_i = número de torneios do
jogador no período, aproximado por `n_jogos_dia` × 76/24 (mínimo 1;
`frequencia_no_periodo()`). R = Ŷ(y/f) / Ŷ(1/f). Aproximação: `n_jogos_dia`
é a média da janela do ROI (1 ano), não das 76 h. Reportar também a versão
por inscrição (`unidade = "inscricao"`) como sensibilidade.

## ADR-010: Tamanho da amostra, m_k = 5 e n = 120

Dimensionado pela proporção de lucrativos (pior caso p = 0,5), porque o DP
do ROI no SharkScope é desconhecido antes da coleta: n = z² p(1−p)/e² × EPA,
com EPA ≈ 1 + ρ(m − 1). Para e = ±0,10 e ρ entre 0 e 0,05: n ≈ 96 a 116.
O máximo sem reabrir os torneios é 24 × 5 = 120 (5 posições já anotadas por
torneio). Decisão (22/10, antes de qualquer ROI): m_k = 5 titulares, sem
reserva, cerca de 110 respondentes e margem de ≈ ±0,10. As 5 posições são os
5 primeiros da mesma permutação, então continuam sendo uma AAS. Cota de 140
consultas por dia: a coleta cabe em 1 dia. O n não resolve os gl = 3 (ADR-004).

## ADR-011: Torneios extras nas células com não resposta

A taxa de resposta observada em 22/10 foi de 20/51 ≈ 39%, não os ~92% do
ADR-010, e três células (bloco 5 low, bloco 5 micro, bloco 8 low) ficaram
abaixo dos mínimos de `validar_tamanhos()`. Regra (22/10, antes de novas
consultas): enquanto uma célula tiver menos de 2 torneios com m_k ≥ 2
respondentes, sorteia-se o próximo torneio da permutação da célula
(`estender_torneios()`, mesma seed) e consultam-se as 5 primeiras posições da
permutação dele. Torneio sem lista de resultados acessível no SharkScope ou
com 0 ou 1 respondente fica fora da estimação (não resposta de USA). Os n
primeiros de uma permutação são uma AAS de tamanho n, e o peso N_jh/n_jh usa
os torneios com respondentes. Hipótese: não resposta aleatória dentro da
célula. Se a célula esgotar os N_jh torneios sem chegar ao mínimo, colapsa-se
com o estrato vizinho do mesmo bloco (low → micro; micro e mid_high → low),
com N_jh e n_jh somados (técnica de estratos colapsados: a variância fica
superestimada; Cochran, 1977, §5A.12). Vale também para os blocos 24 e 30.
Não resolve os gl = 3 nem o viés de perfis privados.

## ADR-012: IC logit para as proporções

Com P̂ perto de 1 e gl = 3 (t = 3,18), o IC de Wald passa de 1 (lucrativos:
0,854 ± 0,232 → [0,62; 1,09]). Para `lucrativo` e `lucrativo_estrito`, o IC
principal é o logit (`ic_logit()`): IC t em logit(P̂), com EP pelo método
delta, EP/(P̂(1 − P̂)), mesmos gl, e volta à escala de proporção. É
assimétrico e fica em (0, 1), como `survey::svyciprop(method = "logit")`.
O Wald é reportado ao lado. Alternativa mais conservadora não adotada:
Korn–Graubard. O ROI médio continua com o IC de Wald (sem limites).

## ADR-013: Plano em três estágios no Kaggle (população sintética)

O Kaggle não tem horário nem ID de torneio (ADR-007), então a estrutura do
campo é construída (`montar_populacao_blocos()`, seed 164363): B = 38 blocos;
em cada bloco e estrato, N_jh sorteado entre os N_jh observados nos 4 blocos
listados do SharkScope e M_k reamostrado dos M_k observados no estrato. Cada
torneio é preenchido por sorteio sem reposição, com probabilidades desiguais
(proporcionais a `tournaments_played`), entre os jogadores do Kaggle do mesmo
estrato de `avg_buyin`. Um jogador pode estar em vários torneios, e f_i é a contagem
exata, então o parâmetro por jogador distinto é conhecido. Sorteios e
estimadores são os do campo. O sorteio oficial (b = 6, n_jh = 2, m_k = 5)
simula a não resposta com as taxas observadas por estrato, como Bernoulli
(aleatória dentro da célula), e aplica a regra do ADR-011. O Monte Carlo
roda sem não resposta, com b = 4, 6 e 12. Limitações: os torneios são
preenchidos ao acaso dentro do estrato, então não há correlação intraclasse
real (ρ ≈ 0 por construção), e as diferenças entre blocos vêm só de N_jh e
M_k. O EPA medido reflete a variação dos pesos e o número de UPAs, não um
efeito de horário. A população fica só com os jogadores sorteados para algum
torneio (21.793 dos 45.000).

## ADR-014: EP por jackknife ao lado do linearizado; componentes de variância

**Jackknife.** Na simulação do ADR-013, a variância linearizada de R̂ capta só
de 50% a 64% da variância real por jogador (63% a 80% por inscrição). As
fórmulas por estágio estão certas (a variância dos totais é bem estimada:
razão de 0,97 a 1,05 em `scripts/checar_variancia_kaggle.R`); o
déficit está na razão. Com o N verdadeiro no denominador, a razão sobe para
0,79–0,92: mais da metade do déficit vem de dividir por N̂², e N̂ tem CV de
cerca de 50% com b = 4. O jackknife de blocos JK1, v = ((b − 1)/b) Σ_j
(R̂_(j) − R̂)² (Wolter, 2007, cap. 4), fica entre 0,94 e 1,04 da variância
real. Decisão: `variancia` continua sendo a linearizada (ADR-003), que é a
fórmula do curso e a validada contra o Thompson, e o EP JK1
(`variancia_jk1`) é reportado ao lado, com o IC correspondente (t no ROI,
logit nas proporções, gl = b − 1). Nas proporções, a leitura prudente é a do
JK1. Ressalva: nem o JK1 leva a cobertura a 95% com 4 blocos (cerca de 94% no
ROI e 91% nos lucrativos), porque a variância estimada tem 3 gl e R̂ é
assimétrico. Alternativa não adotada: trocar a variância principal pelo JK1,
o que mudaria todos os resultados já reportados sem resolver a cobertura.

**Componentes.** As duas parcelas da fórmula do ADR-003 não são componentes de
variância: E[s_u²] = S_u² + V̄ (Cochran, 1977, cap. 10–11), então o 1º termo
já carrega a variação de dentro dos blocos. A pergunta "quanto da variância
vem de cada estágio" é respondida pelos estimadores não viesados dos
componentes (`componentes` em `total_tres_estagios()`): entre blocos com
(s_u² − v̄), entre torneios com (s_1² − w̄), dentro dos torneios com w̄,
que somam a mesma variância. Negativo lê-se como zero. Com b = 4 e
n_jh = 2 são muito instáveis: servem para dizer que o componente entre
blocos não é distinguível de zero, não para ordenar os estágios. Os `termos`
continuam disponíveis, rotulados como parcelas da fórmula. Verificação
(`scripts/checar_variancia_kaggle.R`): na população sintética, sem efeito de
horário, o componente verdadeiro entre blocos é 0,1% a 0,2% da variância e o
de dentro dos torneios, 99%; os estimadores recuperam isso, enquanto o 1º
termo da fórmula fica em 90% da variância estimada. Ressalva: isso vale
para o total com R verdadeiro. Na razão (linearizada em torno de R̂ e
dividida por N̂²), os componentes "entre" ficam negativos em média na
simulação (−9% a −13% entre blocos, −37% a −42% entre torneios, com b = 4):
a subestimação da variância linearizada recai sobre eles. No campo, eles
tendem a subestimar o que vem dos blocos e dos torneios.

## ADR-015: Sensibilidade à não resposta

A correção do plano (m_k = respondentes, ADR-006) supõe não resposta aleatória
dentro do torneio, e a taxa é de 55%. Duas análises descritivas, sem variância
própria (`R/nao_resposta.R`), medem quanto a hipótese pesa:

- **Limites de pior caso** (Manski, 1989), para as proporções: os não
  respondentes recebem 0 e depois 1. Por inscrição (f_i = 1), porque
  `n_jogos_dia` de quem não respondeu é desconhecido. Os torneios com 0 ou 1
  respondente voltam a entrar, então os limites não usam o mesmo conjunto de
  torneios da estimativa observada, e ela pode, em tese, cair fora deles.
  Campo: lucrativos em [0,41; 0,95] (observada 0,87); estrito em
  [0,38; 0,91] (observada 0,80).
- **Ajuste por posição no torneio**: duas classes (metade de cima e de baixo
  da lista de resultados) dentro da célula, com fator r_célula / r_classe
  sobre o peso final. É uma heurística inspirada nas classes de ajuste de
  peso (Lohr, 2022, cap. 8), não o ajuste canônico, que substituiria o fator
  M_k/m_k em vez de multiplicá-lo. A posição é a única covariável conhecida
  para quem não respondeu. Campo (por jogador): ROI de 17,5 para 15,1;
  lucrativos de 0,854 para 0,849.

Leitura: a não resposta ligada à posição no torneio explica pouco (cerca de
2 p.p. no ROI). O risco maior é o que nenhuma covariável observada capta
(perfil público associado a ser vencedor), e para ele só os limites de pior
caso valem: sem hipótese, a proporção de lucrativos está entre 0,41 e 0,95.

## ADR-016: Sementes derivadas com colisão (limitação registrada)

`semente_derivada()` soma os códigos dos caracteres da chave ponderados pela
posição. Para IDs de torneio numéricos de 10 dígitos, essa soma assume poucas
centenas de valores: os 83 torneios da moldura geram 66 sementes distintas, e
entre os 32 sorteados há 2 pares com a mesma semente. Torneios com a mesma
semente partem do mesmo fluxo aleatório e, com M_k parecidos, recebem as
mesmas posições: 4039583402 (M = 114) e 4039583321 (M = 112) receberam
exatamente 71, 19, 95, 42 e 103.
Consequência: cada torneio continua sendo uma AAS de posições, então pesos e
estimativa pontual não mudam, mas os sorteios do 3º estágio **não são todos
independentes entre torneios**, como a fórmula de variância supõe. O efeito
numérico no campo é pequeno (4039583402 ficou fora da estimação, com 1
respondente). Decisão: a função **não** é alterada, porque o sorteio de campo
já foi executado e precisa continuar reproduzível com a semente 164363; a
limitação é declarada no relatório. A simulação do ADR-013 usa as mesmas
funções e herda a colisão (800 torneios, 319 sementes); como ali os jogadores
são alocados ao acaso às posições, posições iguais em torneios diferentes não
criam dependência nos valores. Em um novo levantamento, usar um hash de
verdade (por exemplo, `digest::digest2int()`).
