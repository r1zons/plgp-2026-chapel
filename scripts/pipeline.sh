#!/usr/bin/env bash
set -euo pipefail

# Полностью воспроизводимый минимальный pipeline.
# Пример: ./scripts/pipeline.sh 1000 42

N="${1:-100}"
SEED="${2:-1}"

make build
./bin/bc_compare --command=Generate --n="${N}" --seed="${SEED}"
./bin/bc_compare --command=Run --n="${N}" --seed="${SEED}"
make test
