# Current architecture

Stable:
- NaiveBC: correctness oracle for small graphs
- BrandesBC: sequential reference
- BrandesBCParallel: source-parallel version
- PartitionedBrandes: serial single-process message-passing simulation with per-part state

Experimental:
- PartitionedBrandesParallel: shared-memory partition-parallel variant

Do not break:
- public CLI
- make test
- sparse graph default
- per-part state memory model

Current next goal:
- implement 2D messages[fromPart][toPart]
- then coforall over partitions per BFS/backward level
