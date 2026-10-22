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
jogadores. Satterthwaite na AAS estratificada (Thompson eq. 11.4).

## ADR-005: EPA

EPA = Var(plano) / Var_AAS, com Var_AAS = (1 − n/N̂) s_y²/n e s_y² estimada
na amostra de campo com os pesos finais (ADR-002, incluindo 1/f_i do ADR-009)
(Bolfarine §3.4). rho_int = (EPA − 1)/(m̄ − 1) (Bolfarine eq. 8.26). O Kaggle
**não** entra no EPA de campo: são populações diferentes. No Kaggle, o EPA
empírico compara a AAS estratificada com a AAS na mesma população.

## ADR-006: Não resposta (perfis privados e "Anônimo")

Sem reservas desde o ADR-010: o jogador que não responde sai, e m_k passa a
ser o número de respondentes do torneio (mínimo 2). Hipótese: não resposta
aleatória dentro do torneio. Reportar a taxa por estrato e discutir o viés
residual (Thompson §14.5).

## ADR-007: Dataset do Kaggle

- Colunas: `realized_roi` → `roi`; `profitable` → `lucrativo` (equivale a ROI > 0
  em 100% das linhas); `avg_buyin` → estrato por faixa de buy-in.
- Dados sintéticos (`skill` é a vantagem verdadeira, latente). Sem ID de torneio:
  só é possível simular AAS e AAS estratificada; o plano em estágios fica
  só no campo.
- Estratificação principal: faixas de `avg_buyin` iguais às do campo, para manter
  a comparabilidade. Resultado: EPA ≈ 0,98, porque o ROI não varia entre as faixas.
- Estratificação alternativa (didática): quartis de `skill`, EPA ≈ 0,95. Ela não
  é reproduzível em campo, onde `skill` não é observável.
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
