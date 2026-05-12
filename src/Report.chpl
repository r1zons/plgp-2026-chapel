/*
  Report.chpl
  Печать отчёта в stdout.
*/
module Report {
  record RunReport {
    var n: int;
    var seed: int;
    var generationSec: real;
    var naiveSec: real;
    var brandesSeqSec: real;
    var brandesParSec: real;
    var brandesPartitionedSec: real;
    var brandesPartitionedParallelSec: real;
    var ranPartitionedParallel: bool;
    var partitionedParts: int;
    var naiveTotalSec: real;
    var brandesSeqTotalSec: real;
    var brandesParTotalSec: real;
    var brandesPartitionedTotalSec: real;
    var brandesPartitionedParallelTotalSec: real;
    var passedSeq: bool;
    var passedPar: bool;
    var passedPartitioned: bool;
    var passedPartitionedParallel: bool;
    var mode: string;
    var graphModel: string;
    var targetAvgDegree: real;
    var actualAvgDegree: real;
    var undirectedEdges: int;
    var directedEdges: int;
    var relaxMessagesSent: int(64);
    var dependencyMessagesSent: int(64);
    var cutEdgeTraversals: int(64);
    var bfsLevelsProcessed: int(64);
    var backwardLevelsProcessed: int(64);
    var partitionedForwardBfsSec: real;
    var partitionedBackwardSec: real;
    var partitionedMessageSec: real;
    var partitionedGatherSec: real;
  }

  proc printRunReport(rep: RunReport) {
    writeln("\n=== Run: Graph Info ===");
    writeln("Graph size: ", rep.n);
    writeln("Seed: ", rep.seed);
    writeln("Run mode: ", rep.mode);
    writeln("Graph model: ", rep.graphModel);
    writeln("Target avg degree: ", rep.targetAvgDegree);
    writeln("Actual avg degree: ", rep.actualAvgDegree);
    writeln("Undirected edges: ", rep.undirectedEdges);
    writeln("Directed edges: ", rep.directedEdges);

    writeln("\n=== Run: Timings ===");
    writeln("Generation time: ", rep.generationSec);
    writeln("Naive time: ", rep.naiveSec);
    writeln("Brandes time: ", rep.brandesSeqSec);
    writeln("Parallel Brandes time: ", rep.brandesParSec);
    writeln("Partitioned Brandes time: ", rep.brandesPartitionedSec);
    writeln("Partitioned Parallel Brandes time: ", if rep.ranPartitionedParallel then rep.brandesPartitionedParallelSec else -1.0);
    writeln("Partitioned parts: ", rep.partitionedParts);
    writeln("Partitioned forward BFS time: ", rep.partitionedForwardBfsSec);
    writeln("Partitioned backward time: ", rep.partitionedBackwardSec);
    writeln("Partitioned message time: ", rep.partitionedMessageSec);
    writeln("Partitioned gather time: ", rep.partitionedGatherSec);

    writeln("\n=== Run: Totals ===");
    writeln("Naive total: ", rep.naiveTotalSec);
    writeln("Brandes total: ", rep.brandesSeqTotalSec);
    writeln("Parallel Brandes total: ", rep.brandesParTotalSec);
    writeln("Partitioned Brandes total: ", rep.brandesPartitionedTotalSec);
    writeln("Partitioned Parallel Brandes total: ", if rep.ranPartitionedParallel then rep.brandesPartitionedParallelTotalSec else -1.0);

    writeln("\n=== Run: Correctness ===");
    writeln("Correctness check seq: ", if rep.passedSeq then "PASS" else "FAIL");
    writeln("Correctness check par: ", if rep.passedPar then "PASS" else "FAIL");
    writeln("Correctness check partitioned: ", if rep.passedPartitioned then "PASS" else "FAIL");
    writeln("Correctness check partitioned parallel: ", if rep.passedPartitionedParallel then "PASS" else "FAIL");

    writeln("\n=== Run: Partitioned Message Stats ===");
    writeln("RELAX messages sent: ", rep.relaxMessagesSent);
    writeln("DEPENDENCY messages sent: ", rep.dependencyMessagesSent);
    writeln("Cut-edge traversals: ", rep.cutEdgeTraversals);
    writeln("BFS levels processed: ", rep.bfsLevelsProcessed);
    writeln("Backward levels processed: ", rep.backwardLevelsProcessed);
  }
}
