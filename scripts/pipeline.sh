#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/pipeline.sh <n> <seed>
#   ./scripts/pipeline.sh <n> <seed> <mode>
#   ./scripts/pipeline.sh <n> <seed> <mode> <avgDegree>
#   ./scripts/pipeline.sh <n> <seed> [mode] [avgDegree] [extra --flags ...]

N="${1:-100}"
SEED="${2:-1}"
MODE="${3:-}"
AVG_DEGREE="${4:-16}"
EXTRA_ARGS="${*:5}"

if [[ "${MODE}" == --* ]]; then
  EXTRA_ARGS="${*:3}"
  MODE=""
fi

if [[ -z "${MODE}" ]]; then
  if [[ "${N}" -ge 1000 ]]; then
    MODE="benchmark"
  else
    MODE="correctness"
  fi
fi

make build
./bin/bc_compare --command=Generate --n="${N}" --seed="${SEED}" --avgDegree="${AVG_DEGREE}"
./bin/bc_compare --command=Run --n="${N}" --seed="${SEED}" --avgDegree="${AVG_DEGREE}" --mode="${MODE}" ${EXTRA_ARGS}
make test
