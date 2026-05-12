#!/usr/bin/env bash
set -euo pipefail

N="${N:-400}"
SEED="${SEED:-42}"
AVG_DEGREE="${AVG_DEGREE:-16}"
PARTS_VALUES="${PARTS_VALUES:-1 2 4 8 12}"

OUT_DIR="results/partitioned_parts_logs"
CSV_PATH="results/partitioned_parts_summary.csv"
mkdir -p "${OUT_DIR}" "results"

echo "Building binary..."
make build

echo "n,seed,avgDegree,partitionedParts,brandesTime,parallelBrandesTime,partitionedBrandesTime,partitionedParallelBrandesTime,partitionedParallelForwardTime,partitionedParallelBackwardTime,partitionedParallelMessageTime" > "${CSV_PATH}"

for parts in ${PARTS_VALUES}; do
  log_file="${OUT_DIR}/run_n${N}_seed${SEED}_avg${AVG_DEGREE}_parts${parts}.log"
  echo "Running parts=${parts} -> ${log_file}"

  ./bin/bc_compare \
    --command=Run \
    --n="${N}" \
    --seed="${SEED}" \
    --mode=benchmark \
    --avgDegree="${AVG_DEGREE}" \
    --partitionedParts="${parts}" | tee "${log_file}"

  brandes_time=$(awk -F': ' '/^Brandes time:/ {print $2; exit}' "${log_file}")
  parallel_brandes_time=$(awk -F': ' '/^Parallel Brandes time:/ {print $2; exit}' "${log_file}")
  partitioned_brandes_time=$(awk -F': ' '/^Partitioned Brandes time:/ {print $2; exit}' "${log_file}")
  partitioned_parallel_brandes_time=$(awk -F': ' '/^Partitioned Parallel Brandes time:/ {print $2; exit}' "${log_file}")
  partitioned_parallel_forward_time=$(awk -F': ' '/^Partitioned Parallel forward BFS time:/ {print $2; exit}' "${log_file}")
  partitioned_parallel_backward_time=$(awk -F': ' '/^Partitioned Parallel backward time:/ {print $2; exit}' "${log_file}")
  partitioned_parallel_message_time=$(awk -F': ' '/^Partitioned Parallel message time:/ {print $2; exit}' "${log_file}")

  echo "${N},${SEED},${AVG_DEGREE},${parts},${brandes_time},${parallel_brandes_time},${partitioned_brandes_time},${partitioned_parallel_brandes_time},${partitioned_parallel_forward_time},${partitioned_parallel_backward_time},${partitioned_parallel_message_time}" >> "${CSV_PATH}"
done

echo "Done."
echo "Logs: ${OUT_DIR}"
echo "CSV:  ${CSV_PATH}"
