# Referências: fórmula → fonte

| Fórmula / conceito | Implementação | Fonte |
|---|---|---|
| Total do torneio ŷ_hk = M_hk ȳ_hk | `resumir_torneios()` | Thompson eq. 13.1 |
| Total do estrato τ̂_h = (N_h/n_h) Σ ŷ_hk | `estimar_media_dois_estagios()` | Thompson eq. 13.2 |
| Variância em dois estágios (entre + dentro, com FCPF) | `variancia_entre()`, `variancia_dentro()` | Thompson eq. 13.6–13.8 |
| Soma das variâncias entre estratos | `estimar_media_dois_estagios()` | Thompson §11.1–11.2 |
| Média por jogador μ̂ = τ̂/M0 | `metodo = "nao_viesado"` | Thompson §13.1, p. 174 |
| Estimador razão μ̂_R | `metodo = "razao"` | Thompson p. 175; Bolfarine eq. 8.13, Prop. 8.1 |
| Proporção como média de indicadora | `variavel = "lucrativo"` | Bolfarine §7.5 |
| Plano em três estágios: total HT e variância por estágio (entre blocos + Σ dentro dos blocos) | `total_tres_estagios()` | Cochran cap. 10–11; Metodologia §7–8 |
| Componentes de variância não viesados (entre blocos com s_u² − v̄; entre torneios com s_1² − w̄; dentro dos torneios), porque E[s_u²] = S_u² + V̄ | `total_tres_estagios()` (`componentes`) | Cochran cap. 10–11; Metodologia §8.3 |
| Razão por jogador com peso de multiplicidade 1/f_i; linearização | `estimar_media_tres_estagios()` | Metodologia §7.5 e §8.2; Lohr cap. 9 |
| Estratos colapsados (célula sem o mínimo de torneios juntada à vizinha; variância superestimada) | `colapsar_celula()` | Cochran §5A.12 |
| Tamanho da amostra com EPA ≈ 1 + ρ(m − 1) | Metodologia §5.1 | Kish (1965); Bolfarine eq. 8.26 |
| AAS com FCPF | `estimar_media_aas()` | Thompson cap. 2; Bolfarine cap. 3 |
| AAS estratificada | `combinar_estratos()` | Thompson eq. 11.1–11.3; Bolfarine cap. 4 |
| gl de Satterthwaite | `gl_satterthwaite()` | Thompson eq. 11.4 |
| EPA (DEFF) | `calcular_epa()`, `resumir_simulacao()` | Bolfarine §3.4, §4.3.4 |
| EPA ≈ 1 + ρ_int(m̄ − 1) | `calcular_epa()` | Bolfarine eq. 8.24–8.26 |
| EPA dos pesos 1 + CV²(w) = n Σw²/(Σw)² e EPA restante (conglomerados) | `epa_ponderado()` | Kish (1992) |
| Jackknife JK1 de UPAs (retira um bloco por vez) | `estimar_media_tres_estagios()` (`variancia_jk1`) | Wolter (2007), cap. 4 |
| Alocação ótima de Neyman, n_h ∝ N_h S_h | `alocacao_neyman()` | Cochran §5.5 |
| Alocação proporcional, n_h ∝ N_h; arredondamento pelos maiores restos para Σ n_h = n | `alocacao_proporcional()`, `arredondar_alocacao()` | Cochran cap. 5; Bolfarine cap. 4 |
| Não resposta | `taxa_nao_resposta()` | Thompson §14.5 |
| Limites de pior caso da não resposta (0 e 1 para os não respondentes) | `limites_pior_caso()` | Manski (1989) |
| Ajuste da não resposta por classes (posição no torneio dentro da célula) | `ajustar_por_posicao()` | Lohr cap. 8 |
| Estimação em domínios (estrato como subpopulação, mesmo estimador razão no subconjunto) | `estimar_dominios_estratos()` | Lohr §4.3; Cochran §2.13 |

## Bibliografia

- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
- COCHRAN, W. G. *Sampling Techniques*. 3. ed. New York: Wiley, 1977.
- KISH, L. *Survey Sampling*. New York: Wiley, 1965.
- KISH, L. Weighting for unequal P_i. *Journal of Official Statistics*, v. 8, n. 2, p. 183–200, 1992.
- MANSKI, C. F. Anatomy of the selection problem. *Journal of Human Resources*, v. 24, n. 3, p. 343–360, 1989.
- WOLTER, K. M. *Introduction to Variance Estimation*. 2. ed. New York: Springer, 2007.
- LOHR, S. L. *Sampling: Design and Analysis*. 3. ed. Boca Raton: CRC Press, 2022.
- NEFEDOV, S. *Poker Tournament Survival — Skill vs. Variance* [conjunto de dados]. Kaggle. <https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship>.
