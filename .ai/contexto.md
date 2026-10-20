# Contexto do Projeto

## Visão Geral

Comparação de planos amostrais no poker online: AAS e AAS estratificada
(simuladas no dataset do Kaggle) vs. amostragem estratificada em dois estágios
(coleta real no SharkScope). Ver [`docs/plano_projeto.md`](../docs/plano_projeto.md) para o plano completo
e [`README.md`](../README.md) para rodar o projeto.

## Stack

- R (>= 4.3), somente base R + `stats` nos módulos
- `optparse` para as CLIs em `scripts/`
- `testthat` para testes; `lintr` no CI
- `rmarkdown` para o relatório

## Fluxo Principal

```
Kaggle (população conhecida) → Monte Carlo AAS / AAS estratificada → viés, EQM, cobertura, EPA empírico
SharkScope: sorteio blocos → listagem dos blocos → sorteio torneios (bloco × estrato)
  → sorteio jogadores (+ reserva) → coleta
  → estimação em dois estágios → IC 95% → EPA e rho_int
```

## Índice de Documentos

| Arquivo | Conteúdo |
|---|---|
| [docs/plano_projeto.md](../docs/plano_projeto.md) | Plano v2: delineamento, fórmulas, cronograma |
| [docs/referencias.md](../docs/referencias.md) | Mapa fórmula → livro/seção/equação |
| [.ai/padroes-codigo.md](padroes-codigo.md) | Padrões de R e de testes |
| [.ai/modelagem.md](modelagem.md) | Decisões estatísticas (ADRs) |
| [data/raw/README.md](../data/raw/README.md) | Fontes de dados e formato das planilhas |
