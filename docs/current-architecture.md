# Current Architecture Checkpoint

## 1. Stable implementations

The following implementations are considered stable and must not be broken:

- **NaiveBC**: correctness oracle for small graphs.
- **BrandesBC**: sequential reference implementation.
- **BrandesBCParallel**: source-parallel Brandes using `coforall` over source blocks.
- **PartitionedBrandes**: serial single-process message-passing simulation.
- **PartitionedState**: per-part local traversal state.
- **PartitionedMessages**: current message buffer infrastructure.

These components provide the baseline correctness/reference behavior for the project and should remain intact while extending partition-parallel execution.

## 2. Current goal

We want to add a new implementation: **PartitionedBrandesParallel**.

Goal: shared-memory partition-parallel execution inside one node.

This means:

- Graph vertices are split into partitions.
- Each partition owns local `dist/sigma/delta/frontier/nextFrontier`.
- During each BFS level, partitions process their local frontier in parallel.
- During each backward level, partitions process their local dependency work in parallel.
- Cross-part updates are delivered through messages.

## 3. Important distinction

- **Source-parallel Brandes**:
  - Parallelism dimension is **sources**.
  - Tasks compute independent single-source traversals.
  - Uses global graph CSR with per-task traversal arrays.

- **Graph-partitioned Brandes**:
  - Decomposition dimension is **vertex ownership by partition**.
  - State is maintained per owner partition.
  - Cross-part edges use explicit message passing.
  - Current implementation is serial single-process simulation.

- **Graph-partitioned parallel Brandes**:
  - Keeps graph-partitioned ownership/state model.
  - Adds **parallel partition execution** at each forward/backward level.
  - Requires concurrency-safe message transport between partitions.

## 4. Why 2D message buffers are needed

A naive single destination buffer design `messages[dst]` is unsafe under `coforall` partition processing, because multiple source partitions may append to the same destination buffer concurrently.

Intended safe design:

`messages[fromPart][toPart]`

- Each partition `p` writes only to `messages[p][*]`.
- Destination partition `dst` reads from all `messages[*][dst]` during delivery.

This producer-partitioned layout removes multi-writer contention on a single append target and provides a clear ownership discipline for message writes.

## 5. Files that must not be modified in the next step

For the next coding step, do not modify:

- `src/BrandesBC.chpl`
- `src/BrandesBCParallel.chpl`
- `src/PartitionedBrandes.chpl`
- `src/Main.chpl`
- `src/Report.chpl`

## 6. Next intended coding step

The next step after this document will be:

- Add parallel-safe 2D message buffer infrastructure and tests only.

No algorithm integration yet.

## 7. Done when

This task is done when:

- `docs/current-architecture.md` exists.
- It clearly explains the architecture.
- No Chapel source files were changed.
- No tests were weakened.
