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
| AAS com FCPF | `estimar_media_aas()` | Thompson cap. 2; Bolfarine cap. 3 |
| AAS estratificada | `combinar_estratos()` | Thompson eq. 11.1–11.3; Bolfarine cap. 4 |
| gl de Satterthwaite | `gl_satterthwaite()` | Thompson eq. 11.4 |
| EPA (DEFF) | `calcular_epa()`, `resumir_simulacao()` | Bolfarine §3.4, §4.3.4 |
| EPA ≈ 1 + ρ_int(m̄ − 1) | `calcular_epa()` | Bolfarine eq. 8.24–8.26 |
| Não resposta | `taxa_nao_resposta()` | Thompson §14.5 |

## Bibliografia

- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
- NEFEDOV, S. *Poker Tournament Survival — Skill vs. Variance* [conjunto de dados]. Kaggle. <https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship>.
