# CLAUDE.md

Este arquivo orienta o Claude Code (claude.ai/code) ao trabalhar neste repositório.

## Overview

Projeto de Amostragem (Estatística, Unicamp, 2026): compara planos de
amostragem direta de elementos (AAS e AAS estratificada, simulados por Monte
Carlo sobre um dataset do Kaggle) com uma amostragem estratificada em dois
estágios aplicada em campo no SharkScope (torneios = UPA, jogadores = USA).
Parâmetros: ROI médio por jogador e proporção de jogadores lucrativos.

É um projeto de análise, não um serviço. A entrega é um relatório e slides.
O plano completo, com fórmulas, está em `docs/plano_projeto.md`.

Docs mais profundos:
- `.ai/contexto.md`: visão geral do fluxo e índice
- `.ai/padroes-codigo.md`: padrões de R e de testes
- `.ai/modelagem.md`: decisões estatísticas (ADRs)
- `docs/referencias.md`: cada fórmula → livro/seção/equação

## Commands

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'       # testes unitários
Rscript scripts/simular_kaggle.R --help                 # Monte Carlo no Kaggle
Rscript scripts/sortear_amostra.R torneios --help       # sorteio de campo
Rscript scripts/estimar_campo.R --help                  # estimação em dois estágios
Rscript -e 'rmarkdown::render("docs/relatorio.Rmd")'    # relatório
```

## Architecture

```
R/dados.R                     leitura/validação (Kaggle, moldura, inscritos, coleta)
R/sorteio.R                   1º estágio (torneios) e 2º estágio (jogadores + reserva)
R/estimadores_aas.R           AAS, AAS estratificada, gl de Satterthwaite
R/estimadores_dois_estagios.R tau_h, mu (não viesado / razão), variância, EPA, rho_int
R/simulacao_kaggle.R          Monte Carlo de AAS/AAS estratificada na população do Kaggle
```

Regras que não podem ser quebradas (ver `.ai/modelagem.md`):

- A média por jogador divide por M0 da **população** (ou por M̂0 no estimador razão), nunca pela soma dos inscritos dos torneios sorteados.
- A variância em dois estágios inclui o fator M_hk² no termo dentro dos torneios (torneios de tamanhos diferentes).
- O EPA é calculado na amostra do SharkScope, nunca contra a variância do Kaggle.
- Os testes em `tests/testthat/test-estimadores-*.R` reproduzem os exemplos do Thompson. Se um deles quebrar, a fórmula está errada.
