# Contexto do Projeto

## Visão Geral

Comparação de planos amostrais no poker online: AAS e AAS estratificada
(simuladas no dataset do Kaggle) vs. amostragem estratificada em três estágios
(coleta real no SharkScope: blocos de tempo → torneios → jogadores). Ver
[`docs/Metodologia.md`](../docs/Metodologia.md) para o delineamento e
[`README.md`](../README.md) para rodar o projeto.

## Stack

- R (>= 4.3), somente base R + `stats` nos módulos
- `optparse` para as CLIs em `scripts/`
- `testthat` para testes; `lintr` no CI
- `rmarkdown` para o relatório

## Fluxo Principal

```
Kaggle (população conhecida) → Monte Carlo AAS / AAS estratificada → viés, EQM, cobertura, EPA empírico
SharkScope: sorteio blocos → listagem dos blocos → sorteio torneios (bloco × estrato)
  → sorteio jogadores (m_k = 5) → coleta
  → estimação em três estágios (razão, por jogador) → IC 95% (gl = b − 1) → EPA e rho_int
```

## Índice de Documentos

| Arquivo | Conteúdo |
|---|---|
| [docs/Metodologia.md](../docs/Metodologia.md) | Delineamento em três estágios, fórmulas, cálculo de n, protocolo |
| [docs/fase0_sorteio_blocos.md](../docs/fase0_sorteio_blocos.md) | Sorteio dos blocos, andamento e perda dos blocos 34/36 |
| [docs/plano_projeto.md](../docs/plano_projeto.md) | Plano inicial v2 (dois estágios) e cronograma |
| [docs/referencias.md](../docs/referencias.md) | Mapa fórmula → livro/seção/equação |
| [.ai/padroes-codigo.md](padroes-codigo.md) | Padrões de R e de testes |
| [.ai/modelagem.md](modelagem.md) | Decisões estatísticas (ADRs) |
| [data/raw/README.md](../data/raw/README.md) | Fontes de dados e formato das planilhas |
