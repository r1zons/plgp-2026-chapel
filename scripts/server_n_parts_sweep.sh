#!/usr/bin/env bash
set -u
set -o pipefail

N_VALUES="${N_VALUES:-1000 2000 3000 4000 5000 6000 7000 8000 9000 10000}"
PARTS_VALUES="${PARTS_VALUES:-1 2 4 8 16 32}"
SEED="${SEED:-42}"
AVG_DEGREE="${AVG_DEGREE:-16}"
INTER="${INTER:-0.05}"

BIN_DIR="bin"
BIN_PATH="${BIN_DIR}/bc_compare"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="results/server/runs/${RUN_ID}"
LOG_DIR="${RUN_DIR}/logs"
SUMMARY_DIR="${RUN_DIR}/summary"
CSV_PATH="${SUMMARY_DIR}/server_n_parts_sweep.csv"
RUN_CONFIG_PATH="${RUN_DIR}/run_config.txt"

mkdir -p "${BIN_DIR}" "${LOG_DIR}" "${SUMMARY_DIR}"

chpl src/Main.chpl -M src -O --fast -o "${BIN_PATH}"

{
  date
  hostname
  git rev-parse HEAD 2>/dev/null || echo "NA"
  echo "N_VALUES=${N_VALUES}"
  echo "PARTS_VALUES=${PARTS_VALUES}"
  echo "SEED=${SEED}"
  echo "AVG_DEGREE=${AVG_DEGREE}"
  echo "INTER=${INTER}"
  echo "command=${BIN_PATH} --command=Run --n=<N> --seed=${SEED} --avgDegree=${AVG_DEGREE} --mode=benchmark --skipNaive=true --runPartitioned=false --runPartitionedParallel=true --partitionedParts=<PARTS> --graphModel=clustered --numCommunities=<PARTS> --interCommunityFraction=${INTER} --partitionStrategy=community"
  chpl --version 2>/dev/null || echo "NA"
} > "${RUN_CONFIG_PATH}"

cat > "${CSV_PATH}" <<'EOF'
n,seed,avgDegree,graphModel,partitionStrategy,partitionedParts,numCommunities,interCommunityFraction,brandesTotal,parallelBrandesTotal,partitionedParallelTotal,partitionedParallelForwardTime,partitionedParallelBackwardTime,partitionedParallelMessageTime,relaxMessages,dependencyMessages,bfsLevels,backwardLevels,parallelSpeedup,partitionedVsBrandesRatio,partitionedVsParallelRatio,logFile,status
EOF

extract_field() {
  local label="$1"
  local file="$2"
  awk -F': ' -v key="${label}" '$0 ~ "^" key ": " { value=$2 } END { if (value != "") print value }' "${file}"
}

safe_value() {
  if [[ -n "${1:-}" ]]; then
    printf '%s' "${1}"
  else
    printf 'NA'
  fi
}

calc_ratio() {
  local numerator="$1"
  local denominator="$2"
  awk -v a="${numerator}" -v b="${denominator}" '
    BEGIN {
      if (a == "" || b == "" || a == "NA" || b == "NA" || b + 0 == 0) {
        print "NA";
      } else {
        print a / b;
      }
    }'
}

total_runs=0
for _n in ${N_VALUES}; do
  for _p in ${PARTS_VALUES}; do
    total_runs=$((total_runs + 1))
  done
done

completed_runs=0
failed_runs=0
current_run=0

for N in ${N_VALUES}; do
  for PARTS in ${PARTS_VALUES}; do
    current_run=$((current_run + 1))
    NUM_COMMUNITIES="${PARTS}"
    LOG_PATH="${LOG_DIR}/sweep_n${N}_p${PARTS}_avg${AVG_DEGREE}_inter${INTER}.log"

    echo "[${current_run}/${total_runs}] N=${N} partitionedParts=${PARTS} numCommunities=${NUM_COMMUNITIES} avgDegree=${AVG_DEGREE} interCommunityFraction=${INTER}"
    echo "log: ${LOG_PATH}"

    if "${BIN_PATH}" \
      --command=Run \
      --n="${N}" \
      --seed="${SEED}" \
      --avgDegree="${AVG_DEGREE}" \
      --mode=benchmark \
      --skipNaive=true \
      --runPartitioned=false \
      --runPartitionedParallel=true \
      --partitionedParts="${PARTS}" \
      --graphModel=clustered \
      --numCommunities="${NUM_COMMUNITIES}" \
      --interCommunityFraction="${INTER}" \
      --partitionStrategy=community \
      > "${LOG_PATH}" 2>&1; then
      status="OK"
      completed_runs=$((completed_runs + 1))
    else
      status="FAILED"
      failed_runs=$((failed_runs + 1))
    fi

    brandes_total="$(extract_field "Brandes total" "${LOG_PATH}")"
    parallel_brandes_total="$(extract_field "Parallel Brandes total" "${LOG_PATH}")"
    partitioned_parallel_total="$(extract_field "Partitioned Parallel Brandes total" "${LOG_PATH}")"
    forward_time="$(extract_field "Partitioned Parallel forward BFS time" "${LOG_PATH}")"
    backward_time="$(extract_field "Partitioned Parallel backward time" "${LOG_PATH}")"
    message_time="$(extract_field "Partitioned Parallel message time" "${LOG_PATH}")"
    relax_messages="$(extract_field "RELAX messages sent" "${LOG_PATH}")"
    dependency_messages="$(extract_field "DEPENDENCY messages sent" "${LOG_PATH}")"
    bfs_levels="$(extract_field "BFS levels processed" "${LOG_PATH}")"
    backward_levels="$(extract_field "Backward levels processed" "${LOG_PATH}")"

    parallel_speedup="$(calc_ratio "${brandes_total}" "${parallel_brandes_total}")"
    partitioned_vs_brandes_ratio="$(calc_ratio "${partitioned_parallel_total}" "${brandes_total}")"
    partitioned_vs_parallel_ratio="$(calc_ratio "${partitioned_parallel_total}" "${parallel_brandes_total}")"

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "${N}" \
      "${SEED}" \
      "${AVG_DEGREE}" \
      "clustered" \
      "community" \
      "${PARTS}" \
      "${NUM_COMMUNITIES}" \
      "${INTER}" \
      "$(safe_value "${brandes_total}")" \
      "$(safe_value "${parallel_brandes_total}")" \
      "$(safe_value "${partitioned_parallel_total}")" \
      "$(safe_value "${forward_time}")" \
      "$(safe_value "${backward_time}")" \
      "$(safe_value "${message_time}")" \
      "$(safe_value "${relax_messages}")" \
      "$(safe_value "${dependency_messages}")" \
      "$(safe_value "${bfs_levels}")" \
      "$(safe_value "${backward_levels}")" \
      "$(safe_value "${parallel_speedup}")" \
      "$(safe_value "${partitioned_vs_brandes_ratio}")" \
      "$(safe_value "${partitioned_vs_parallel_ratio}")" \
      "${LOG_PATH}" \
      "${status}" >> "${CSV_PATH}"
  done
done

echo "Run directory: ${RUN_DIR}"
echo "CSV: ${CSV_PATH}"
echo "Logs: ${LOG_DIR}"
echo "Completed runs: ${completed_runs}"
echo "Failed runs: ${failed_runs}"
