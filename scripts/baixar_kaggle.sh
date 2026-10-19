#!/usr/bin/env bash
# Baixa o dataset do Kaggle para data/raw/kaggle/ (fora do git).
#
# Requer a CLI do Kaggle (`pip install kaggle`) e um token em
# ~/.kaggle/kaggle.json (Kaggle > Settings > API > Create New Token).
#
# Uso:
#   bash scripts/baixar_kaggle.sh
set -euo pipefail

DATASET="sergionefedov/poker-tournament-survivorship"
DESTINO="data/raw/kaggle"

mkdir -p "$DESTINO"
kaggle datasets download -d "$DATASET" -p "$DESTINO" --unzip
echo "Arquivos em $DESTINO:"
ls -la "$DESTINO"
