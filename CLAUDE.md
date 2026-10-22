# CLAUDE.md

Este arquivo orienta o Claude Code (claude.ai/code) ao trabalhar neste repositório.

## Overview

Projeto de Amostragem (Estatística, Unicamp, 2026): compara planos de
amostragem direta de elementos (AAS e AAS estratificada, simulados por Monte
Carlo sobre um dataset do Kaggle) com uma amostragem estratificada em três
estágios aplicada em campo no SharkScope (blocos de 2 h = UPA, torneios = USA,
estratificados por buy-in dentro do bloco, jogadores = UTA). Parâmetros: ROI
médio por jogador distinto (peso 1/f_i) e proporção de jogadores lucrativos.

É um projeto de análise, não um serviço. A entrega é um relatório e slides.
O delineamento de campo, com fórmulas, está em [`docs/Metodologia.md`](docs/Metodologia.md);
[`docs/plano_projeto.md`](docs/plano_projeto.md) é o plano inicial, em dois estágios.

Docs mais profundos:
- [`.ai/contexto.md`](.ai/contexto.md): visão geral do fluxo e índice
- [`.ai/padroes-codigo.md`](.ai/padroes-codigo.md): padrões de R e de testes
- [`.ai/modelagem.md`](.ai/modelagem.md): decisões estatísticas (ADRs)
- [`docs/referencias.md`](docs/referencias.md): cada fórmula → livro/seção/equação

## Commands

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'       # testes unitários
Rscript scripts/simular_kaggle.R --help                 # Monte Carlo no Kaggle
Rscript scripts/sortear_amostra.R torneios --help       # sorteio de campo
Rscript scripts/estimar_campo.R --help                  # estimação em três estágios
Rscript -e 'rmarkdown::render("docs/relatorio.Rmd")'    # relatório
```

## Architecture

```
R/dados.R                     leitura/validação (Kaggle, listagem → moldura, top 10, coleta)
R/sorteio.R                   blocos, torneios por (bloco, estrato), posições dos jogadores
R/estimadores_aas.R           AAS, AAS estratificada, gl de Satterthwaite
R/estimadores_dois_estagios.R núcleo de dois estágios (Thompson §13.1), termos de variância, EPA
R/estimadores_tres_estagios.R plano de campo: razão por jogador (1/f_i), variância por estágio
R/simulacao_kaggle.R          Monte Carlo de AAS/AAS estratificada na população do Kaggle
```

Regras que não podem ser quebradas (ver [`.ai/modelagem.md`](.ai/modelagem.md)):

- A média divide por M̂0 (ou N̂ de jogadores) estimado para a **população** de 38 blocos, nunca pela soma dos inscritos dos torneios sorteados.
- Os pesos são por célula (bloco × estrato): w = (B/b)(N_jh/n_jh)(M_k/m_k), nunca um N_h/n_h único somando blocos.
- A variância inclui o termo entre blocos e o fator M_k² no termo dentro dos torneios (torneios de tamanhos diferentes). IC com gl = b − 1.
- O EPA é calculado na amostra do SharkScope, nunca contra a variância do Kaggle.
- Os testes em `tests/testthat/test-estimadores-*.R` reproduzem os exemplos do Thompson. Se um deles quebrar, a fórmula está errada.
