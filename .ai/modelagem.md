# Decisões de Modelagem

Registro, no formato ADR, das decisões estatísticas do plano
([`docs/plano_projeto.md`](../docs/plano_projeto.md)). As referências completas estão em [`docs/referencias.md`](../docs/referencias.md).

## ADR-001: Delineamento de campo, estratificada em dois estágios

Estratos: 3 faixas de buy-in (Micro/Nano < US$5; Low US$5–24,99; Mid/High
>= US$25). 1º estágio: AAS sem reposição de torneios (n_h >= 2). 2º estágio:
AAS sem reposição de jogadores (m_hk >= 2) + lista de reserva ordenada.
A estratificação é uma partição, não um estágio (Thompson, p. 171).
Por que 3 estratos e não 5: ver [`docs/notas/estratificacao_buyin.md`](../docs/notas/estratificacao_buyin.md).

## ADR-002: Estimador da média por jogador

- M0 conhecido (inscritos de todos os torneios da moldura): mu = Σ tau_h / M0, não viesado (Thompson §13.1, p. 174).
- M0 desconhecido: estimador razão combinado mu_R = Σ tau_h / Σ M̂_h (Thompson p. 175; Bolfarine eq. 8.13).
- Nunca dividir pela soma dos inscritos apenas dos torneios sorteados.
- `metodo = "auto"` escolhe entre os dois conforme a moldura.

## ADR-003: Variância

Thompson eq. 13.6 por estrato, somada entre estratos (§11.1) e dividida por
M0². O termo dentro dos torneios leva M_hk² (torneios de tamanhos diferentes).
No estimador razão, o termo entre torneios usa os resíduos yhat − r·M
(Bolfarine Prop. 8.1).

## ADR-004: IC

IC t com gl = Σ n_h − H no campo (convenção usual para planos complexos,
fora dos dois livros); Satterthwaite na AAS estratificada (Thompson eq. 11.4).

## ADR-005: EPA

EPA = Var(plano) / Var_AAS, com Var_AAS = (1 − n/M0) s_y²/n e s_y² estimada
na amostra de campo com os pesos amostrais (Bolfarine §3.4). rho_int =
(EPA − 1)/(m̄ − 1) (Bolfarine eq. 8.26). O Kaggle **não** entra no EPA de
campo: são populações diferentes. No Kaggle, o EPA empírico compara a AAS
estratificada com a AAS na mesma população.

## ADR-006: Não resposta (perfis privados)

Substituição pelo próximo da reserva do mesmo torneio. Hipótese: não
resposta aleatória dentro do torneio; m_hk = número de respondentes. Reportar
a taxa por estrato e discutir o viés residual (Thompson §14.5).

## ADR-007: Dataset do Kaggle

- Colunas: `realized_roi` → `roi`; `profitable` → `lucrativo` (equivale a ROI > 0
  em 100% das linhas); `avg_buyin` → estrato por faixa de buy-in.
- Dados sintéticos (`skill` é a vantagem verdadeira, latente). Sem ID de torneio:
  só é possível simular AAS e AAS estratificada; o plano em dois estágios fica
  só no campo.
- Estratificação principal: faixas de `avg_buyin` iguais às do campo, para manter
  a comparabilidade. Resultado: EPA ≈ 0,98, porque o ROI não varia entre as faixas.
- Estratificação alternativa (didática): quartis de `skill`, EPA ≈ 0,95. Ela não
  é reproduzível em campo, onde `skill` não é observável.
- Ressalva: `avg_buyin` é a média do jogador ao longo de vários torneios; no campo,
  o estrato é o buy-in do torneio. As duas classificações não são idênticas.
- Licença: não informada na página. O CSV fica fora do git.
