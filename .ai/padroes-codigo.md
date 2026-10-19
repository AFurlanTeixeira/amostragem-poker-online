# Padrões de Código

## R

- Documentar toda função com roxygen2, incluindo tipos (`#' @param coleta data.frame`, `#' @return list`).
- Nos comentários, citar a fórmula e a referência (ex.: "Thompson eq. 13.6"), não só descrever o que a função faz.
- `snake_case` para funções e variáveis, com uma exceção: a notação estatística do plano (`N_h`, `M0`, `M_hat_h`) é mantida para o código espelhar as fórmulas. Por isso o `object_name_linter` está desligado no `.lintr`. O `object_usage_linter` também está desligado, porque os módulos são carregados via `source()` e não como pacote.
- Um arquivo `.R` por responsabilidade (ver `CLAUDE.md` → Architecture).
- Sem efeitos colaterais nos estimadores: recebem data.frames e retornam listas ou data.frames novos.
- Resultado padrão de um estimador: `list(estimativa, variancia, erro_padrao, gl, li, ls)` (ver `montar_resultado()`).

## Aleatoriedade e reprodutibilidade

- Toda função que sorteia recebe `seed` explícito e usa `withr_seed()`, que não altera o RNG global.
- O `seed` de cada sorteio e de cada simulação deve ficar registrado no relatório. Os sorteios de campo também ficam versionados em `data/raw/sharkscope/`.

## Testes

- Um `tests/testthat/test-*.R` por módulo de `R/`.
- Estimadores: testar contra os **exemplos resolvidos dos livros** (Thompson §11.2–11.3 e §13.1) e contra casos calculados à mão.
- Simulação: testar propriedades (viés próximo de zero, cobertura perto do nível nominal, EPA < 1 quando os estratos diferem) com tolerância, e não valores exatos.

## O que evitar

- Números mágicos: mínimos como `N_MINIMO_POR_ESTRATO` e `M_MINIMO_POR_TORNEIO` são constantes nomeadas.
- Dividir a média por inscritos só da amostra (ver ADR-002).
- Versionar o dataset do Kaggle (licença a confirmar).
