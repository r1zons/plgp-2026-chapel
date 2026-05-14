#!/usr/bin/env bash
set -euo pipefail

N_VALUES="${N_VALUES:-1000 2000 4000}"
SEED="${SEED:-42}"
AVG_DEGREE="${AVG_DEGREE:-16}"
GRAPH_MODEL="${GRAPH_MODEL:-clustered}"
PARTITION_STRATEGY="${PARTITION_STRATEGY:-community}"
PARTS="${PARTS:-4}"
NUM_COMMUNITIES="${NUM_COMMUNITIES:-${PARTS}}"
INTER="${INTER:-0.05}"

RESULTS_DIR="results"
LOG_DIR="${RESULTS_DIR}/final_benchmark_logs"
CSV_PATH="${RESULTS_DIR}/final_benchmark_summary.csv"
BIN_PATH="./bin/bc_compare"

mkdir -p "${LOG_DIR}"

make build

cat > "${CSV_PATH}" <<'EOF'
n,seed,avgDegree,brandesTotal,parallelBrandesTotal,partitionedParallelTotal,partitionedParallelForwardTime,partitionedParallelBackwardTime,partitionedParallelMessageTime,relaxMessages,dependencyMessages
EOF

extract_field() {
  local label="$1"
  local file="$2"
  awk -F': ' -v key="${label}" '$0 ~ "^" key ": " { value=$2 } END { if (value != "") print value }' "${file}"
}

for n in ${N_VALUES}; do
  log_file="${LOG_DIR}/n_${n}_seed_${SEED}.log"
  "${BIN_PATH}" \
    --command=Run \
    --mode=benchmark \
    --n="${n}" \
    --seed="${SEED}" \
    --avgDegree="${AVG_DEGREE}" \
    --graphModel="${GRAPH_MODEL}" \
    --partitionStrategy="${PARTITION_STRATEGY}" \
    --partitionedParts="${PARTS}" \
    --numCommunities="${NUM_COMMUNITIES}" \
    --interCommunityFraction="${INTER}" \
    --skipNaive=true \
    --runPartitioned=false \
    > "${log_file}"

  brandes_total="$(extract_field "Brandes total" "${log_file}")"
  parallel_brandes_total="$(extract_field "Parallel Brandes total" "${log_file}")"
  partitioned_parallel_total="$(extract_field "Partitioned Parallel Brandes total" "${log_file}")"
  forward_time="$(extract_field "Partitioned Parallel forward BFS time" "${log_file}")"
  backward_time="$(extract_field "Partitioned Parallel backward time" "${log_file}")"
  message_time="$(extract_field "Partitioned Parallel message time" "${log_file}")"
  relax_messages="$(extract_field "RELAX messages sent" "${log_file}")"
  dependency_messages="$(extract_field "DEPENDENCY messages sent" "${log_file}")"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "${n}" \
    "${SEED}" \
    "${AVG_DEGREE}" \
    "${brandes_total}" \
    "${parallel_brandes_total}" \
    "${partitioned_parallel_total}" \
    "${forward_time}" \
    "${backward_time}" \
    "${message_time}" \
    "${relax_messages}" \
    "${dependency_messages}" >> "${CSV_PATH}"
done

echo "Wrote ${CSV_PATH}"
echo "Logs: ${LOG_DIR}"
