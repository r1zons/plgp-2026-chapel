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
    var ranPartitioned: bool;
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
    var skipNaive: bool;
    var referenceAlgorithm: string;
    var graphModel: string;
    var partitionStrategy: string;
    var targetAvgDegree: real;
    var actualAvgDegree: real;
    var undirectedEdges: int;
    var directedEdges: int;
    var minPartitionSize: int;
    var maxPartitionSize: int;
    var partitionCutEdges: int;
    var partitionCutEdgeRatio: real;
    var connectedParts: bool;
    var relaxMessagesSent: int(64);
    var dependencyMessagesSent: int(64);
    var cutEdgeTraversals: int(64);
    var bfsLevelsProcessed: int(64);
    var backwardLevelsProcessed: int(64);
    var partitionedForwardBfsSec: real;
    var partitionedBackwardSec: real;
    var partitionedMessageSec: real;
    var partitionedGatherSec: real;
    var pparRelaxMessagesSent: int(64);
    var pparDependencyMessagesSent: int(64);
    var pparCutEdgeTraversals: int(64);
    var pparBfsLevelsProcessed: int(64);
    var pparBackwardLevelsProcessed: int(64);
    var pparForwardBfsSec: real;
    var pparBackwardSec: real;
    var pparMessageSec: real;
    var pparGatherSec: real;
  }

  proc printRunReport(rep: RunReport) {
    writeln("\n=== Run: Graph Info ===");
    writeln("Graph size: ", rep.n);
    writeln("Seed: ", rep.seed);
    writeln("Run mode: ", rep.mode);
    writeln("Reference algorithm: ", rep.referenceAlgorithm);
    writeln("Graph model: ", rep.graphModel);
    writeln("Target avg degree: ", rep.targetAvgDegree);
    writeln("Actual avg degree: ", rep.actualAvgDegree);
    writeln("Undirected edges: ", rep.undirectedEdges);
    writeln("Directed edges: ", rep.directedEdges);
    writeln("partitionStrategy: ", rep.partitionStrategy);
    writeln("partitionedParts: ", rep.partitionedParts);
    writeln("Min partition size: ", rep.minPartitionSize);
    writeln("Max partition size: ", rep.maxPartitionSize);
    writeln("Cut edges: ", rep.partitionCutEdges);
    writeln("Cut edge ratio: ", rep.partitionCutEdgeRatio);
    writeln("Connected parts: ", if rep.connectedParts then "PASS" else "FAIL");

    writeln("\n=== Run: Timings ===");
    writeln("Generation time: ", rep.generationSec);
    if rep.skipNaive then
      writeln("Naive time: SKIPPED");
    else
      writeln("Naive time: ", rep.naiveSec);
    writeln("Brandes time: ", rep.brandesSeqSec);
    writeln("Parallel Brandes time: ", rep.brandesParSec);
    if rep.ranPartitioned then
      writeln("Partitioned Brandes time: ", rep.brandesPartitionedSec);
    else
      writeln("Partitioned Brandes time: SKIPPED");
    writeln("Partitioned Parallel Brandes time: ", if rep.ranPartitionedParallel then rep.brandesPartitionedParallelSec else -1.0);
    if rep.ranPartitionedParallel {
      writeln("Partitioned Parallel forward BFS time: ", rep.pparForwardBfsSec);
      writeln("Partitioned Parallel backward time: ", rep.pparBackwardSec);
      writeln("Partitioned Parallel message time: ", rep.pparMessageSec);
      writeln("Partitioned Parallel gather time: ", rep.pparGatherSec);
    }
    writeln("Partitioned forward BFS time: ", rep.partitionedForwardBfsSec);
    writeln("Partitioned backward time: ", rep.partitionedBackwardSec);
    writeln("Partitioned message time: ", rep.partitionedMessageSec);
    writeln("Partitioned gather time: ", rep.partitionedGatherSec);

    writeln("\n=== Run: Totals ===");
    if rep.skipNaive then
      writeln("Naive total: SKIPPED");
    else
      writeln("Naive total: ", rep.naiveTotalSec);
    writeln("Brandes total: ", rep.brandesSeqTotalSec);
    writeln("Parallel Brandes total: ", rep.brandesParTotalSec);
    if rep.ranPartitioned then
      writeln("Partitioned Brandes total: ", rep.brandesPartitionedTotalSec);
    else
      writeln("Partitioned Brandes total: SKIPPED");
    writeln("Partitioned Parallel Brandes total: ", if rep.ranPartitionedParallel then rep.brandesPartitionedParallelTotalSec else -1.0);

    writeln("\n=== Run: Correctness ===");
    if rep.skipNaive then
      writeln("Correctness check seq: REFERENCE");
    else
      writeln("Correctness check seq: ", if rep.passedSeq then "PASS" else "FAIL");
    writeln("Correctness check par: ", if rep.passedPar then "PASS" else "FAIL");
    if rep.ranPartitioned then
      writeln("Correctness check partitioned: ", if rep.passedPartitioned then "PASS" else "FAIL");
    else
      writeln("Correctness check partitioned: SKIPPED");
    writeln("Correctness check partitioned parallel: ", if rep.passedPartitionedParallel then "PASS" else "FAIL");

    if rep.ranPartitioned {
      writeln("\n=== Run: Partitioned Message Stats ===");
      writeln("RELAX messages sent: ", rep.relaxMessagesSent);
      writeln("DEPENDENCY messages sent: ", rep.dependencyMessagesSent);
      writeln("Cut-edge traversals: ", rep.cutEdgeTraversals);
      writeln("BFS levels processed: ", rep.bfsLevelsProcessed);
      writeln("Backward levels processed: ", rep.backwardLevelsProcessed);
    }

    if rep.ranPartitionedParallel {
      writeln("\n=== Run: Partitioned Parallel Message Stats ===");
      writeln("RELAX messages sent: ", rep.pparRelaxMessagesSent);
      writeln("DEPENDENCY messages sent: ", rep.pparDependencyMessagesSent);
      writeln("Cut-edge traversals: ", rep.pparCutEdgeTraversals);
      writeln("BFS levels processed: ", rep.pparBfsLevelsProcessed);
      writeln("Backward levels processed: ", rep.pparBackwardLevelsProcessed);
    }
  }
}
