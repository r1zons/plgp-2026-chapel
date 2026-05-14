# Current Architecture Checkpoint

## 1. Stable implementations

The following implementations are stable and must not be broken:

- **NaiveBC**: correctness oracle for small graphs.
- **BrandesBC**: sequential reference.
- **BrandesBCParallel**: source-parallel Brandes.
- **PartitionedBrandes**: serial single-process partitioned message-passing simulation.
- **PartitionedState**: per-part local traversal state.
- **PartitionedMessages**: includes serial message buffers and parallel-safe 2D message buffers.
- **PartitionedBrandesParallel**: shared-memory partition-parallel Brandes variant.

## 2. Completed milestones

Completed in the current codebase:

- Sparse graph generation by `avgDegree`.
- Clustered sparse graph generation by `avgDegree`, `numCommunities`, and `interCommunityFraction`.
- Partition strategies: contiguous vertex blocks and clustered community-aligned partitions.
- Partition-local traversal state.
- Serial partitioned message-passing Brandes.
- Parallel-safe 2D message buffers.
- `PartitionedBrandesParallel` focused implementation and tests.

## 3. Current next step

The next intended step is to use clustered graphs and community-aligned partitions for focused partitioned Brandes experiments, while keeping Brandes algorithm semantics unchanged.

## 4. Important instruction

- Do **not** reimplement 2D message buffers.
- Do **not** replace existing `PartitionedBrandes`.
- Do **not** modify stable algorithms unless explicitly requested.

## 5. Desired future report lines

When integration is done, report output should include:

- `Partitioned Parallel Brandes time`
- `Partitioned Parallel Brandes total`
- `Correctness check partitioned parallel: PASS/FAIL`

## 6. Current limitation

`PartitionedBrandesParallel` is still single-node shared-memory parallelism.
It is **not** true Chapel multi-locale cluster execution yet.
