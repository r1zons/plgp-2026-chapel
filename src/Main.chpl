/*
  Main.chpl
  Минимальный CLI с командами:
    - Generate
    - Run

  Параметры:
    --command=<Generate|Run>
    --n=<число>
    --seed=<число>
*/
module Main {
  use Time;
  use GraphCSR;
  use GraphGenerator;
  use NaiveBC;
  use BrandesBC;
  use BrandesBCParallel;
  use PartitionedGraph;
  use PartitionedBrandes;
  use PartitionedBrandesParallel;
  use Compare;
  use Report;

  config const command = "Run";
  config const n = 10;
  config const seed = 1;
  config const parTasks = 0;
  config const partitionedParts = 0;
  config const mode = "correctness"; // correctness | benchmark
  config const runPartitioned: bool = true;
  config const runPartitionedParallel = true;
  config const skipNaive: bool = false;
  config const maxNaiveN: int = 200;

  private proc printFirstRealMismatches(ref base: [] real, ref other: [] real,
                                        eps: real, cmpTag: string,
                                        maxCount: int = 5) {
    var printed = 0;
    for v in base.domain {
      const diff = abs(base[v] - other[v]);
      if diff > eps {
        writeln("Mismatch (", cmpTag, ") at vertex ", v,
                ": base=", base[v],
                ", other=", other[v],
                ", |diff|=", diff);
        printed += 1;
        if printed >= maxCount then
          break;
      }
    }
  }

  proc doGenerate(n: int, seed: int) {
    const t0 = timeSinceEpoch().totalSeconds();
    var g = generateConnectedRandomGraph(n, seed);
    const t1 = timeSinceEpoch().totalSeconds();

    writeln("\n=== Generate ===");
    writeln("Graph generated: vertices=", g.numVertices(),
            ", directed_edges=", g.numDirectedEdges());

    if n <= 20 then
      printSmallGraph(g);

    writeln("\n=== Generate: Summary ===");
    writeln("Graph size: ", n);
    writeln("Seed: ", seed);
    const undirectedEdges = g.numDirectedEdges() / 2;
    const actualAvgDegree = if n > 0 then (2.0 * undirectedEdges:real) / n:real else 0.0;
    const model = if edgeDensity >= 0.0 then "density-opt-in" else graphModel;
    const targetAvgDegree = if edgeDensity >= 0.0 then
      (2.0 * (edgeDensity * ((n * (n - 1)) / 2):real)) / (if n > 0 then n:real else 1.0)
      else avgDegree:real;
    writeln("Graph model: ", model);
    writeln("Target avg degree: ", targetAvgDegree);
    writeln("Actual avg degree: ", actualAvgDegree);
    writeln("Undirected edges: ", undirectedEdges);
    writeln("Directed edges: ", g.numDirectedEdges());
    writeln("Generation time: ", t1 - t0);
  }

  proc doRun(n: int, seed: int) {
    const useSeqReference = skipNaive || mode == "benchmark";
    const referenceAlgorithm = if useSeqReference then "Sequential Brandes" else "NaiveBC";
    writeln("\n=== Run: Effective Config ===");
    writeln("Run mode: ", mode);
    writeln("skipNaive: ", skipNaive);
    writeln("runPartitioned: ", runPartitioned);
    writeln("runPartitionedParallel: ", runPartitionedParallel);
    writeln("partitionStrategy: ", partitionStrategy);
    writeln("partitionedParts: ", partitionedParts);
    writeln("maxNaiveN: ", maxNaiveN);
    writeln("Reference algorithm: ", referenceAlgorithm);

    if !skipNaive && n > maxNaiveN then
      halt("NaiveBC is disabled for n > maxNaiveN. Use --skipNaive=true or increase --maxNaiveN explicitly.");

    var parts = partitionedParts;
    if parts <= 0 then
      parts = if n >= 2 then 2 else 1;
    if parts > n then
      parts = n;

    if !partitionStrategyConfigIsValid(graphModel, parts, numCommunities) then
      halt(partitionStrategyConfigErrorMessage());

    const gen0 = timeSinceEpoch().totalSeconds();
    var g = generateConnectedRandomGraph(n, seed);
    const gen1 = timeSinceEpoch().totalSeconds();

    if n <= 20 then
      printSmallGraph(g);

    var naive: [0..n-1] real;
    naive = 0.0;
    var naive0 = 0.0;
    var naive1 = 0.0;
    if !skipNaive {
      naive0 = timeSinceEpoch().totalSeconds();
      naive = computeNaiveBCReal(g);
      naive1 = timeSinceEpoch().totalSeconds();
    } else {
      writeln("Skipping NaiveBC.");
      writeln("Naive time: SKIPPED");
      writeln("Naive total: SKIPPED");
    }

    const seq0 = timeSinceEpoch().totalSeconds();
    var brandesSeq = computeBrandesBCReal(g);
    const seq1 = timeSinceEpoch().totalSeconds();

    const par0 = timeSinceEpoch().totalSeconds();
    var brandesPar = computeBrandesBCParallelReal(g, parTasks);
    const par1 = timeSinceEpoch().totalSeconds();

    var pgForReport = buildPartitionedGraph(g, parts);
    const partitionMetrics = computePartitionMetrics(g, pgForReport);

    var brandesPartitioned: [0..n-1] real;
    brandesPartitioned = 0.0;
    var pmsg0 = 0.0;
    var pmsg1 = 0.0;
    var pMetrics = getLastPartitionedRunMetrics();
    if runPartitioned {
      pmsg0 = timeSinceEpoch().totalSeconds();
      brandesPartitioned = computePartitionedBrandesBCReal(g, parts);
      pmsg1 = timeSinceEpoch().totalSeconds();
      pMetrics = getLastPartitionedRunMetrics();
    }

    var brandesPartitionedParallel: [0..n-1] real;
    brandesPartitionedParallel = 0.0;
    var ppar0 = 0.0;
    var ppar1 = 0.0;
    var pparMetrics = getLastPartitionedParallelRunMetrics();
    if runPartitionedParallel {
      ppar0 = timeSinceEpoch().totalSeconds();
      brandesPartitionedParallel = computePartitionedBrandesBCParallelReal(g, parts);
      ppar1 = timeSinceEpoch().totalSeconds();
      pparMetrics = getLastPartitionedParallelRunMetrics();
    }

    const eps = 1.0e-9;
    const okSeq = if useSeqReference then true else approximatelyEqual(naive, brandesSeq, eps);
    const okPar = if useSeqReference then approximatelyEqual(brandesSeq, brandesPar, eps)
                  else approximatelyEqual(naive, brandesPar, eps);
    const okPartitioned = if !runPartitioned then true
                          else if useSeqReference then approximatelyEqual(brandesSeq, brandesPartitioned, eps)
                          else approximatelyEqual(naive, brandesPartitioned, eps);
    const okPartitionedParallel = if !runPartitionedParallel then true
      else if useSeqReference then approximatelyEqual(brandesSeq, brandesPartitionedParallel, eps)
      else approximatelyEqual(naive, brandesPartitionedParallel, eps);

    if (!okSeq || !okPar || !okPartitioned || !okPartitionedParallel) then
      writeln("\n=== Run: Mismatches ===");

    if !skipNaive && !okSeq then
      printFirstRealMismatches(naive, brandesSeq, eps, "Naive vs Seq", 5);

    if !okPar then
      if skipNaive then
        printFirstRealMismatches(brandesSeq, brandesPar, eps, "Seq vs Par", 5);
      else
        printFirstRealMismatches(naive, brandesPar, eps, "Naive vs Par", 5);

    if runPartitioned && !okPartitioned then
      if useSeqReference then
        printFirstRealMismatches(brandesSeq, brandesPartitioned, eps, "Seq vs Partitioned", 5);
      else
        printFirstRealMismatches(naive, brandesPartitioned, eps, "Naive vs Partitioned", 5);

    if !okPartitionedParallel then
      if mode == "benchmark" then
        printFirstRealMismatches(brandesSeq, brandesPartitionedParallel, eps, "Seq vs PartitionedParallel", 5);
      else
        printFirstRealMismatches(naive, brandesPartitionedParallel, eps, "Naive vs PartitionedParallel", 5);

    var rep: RunReport;
    rep.n = n;
    rep.seed = seed;
    rep.mode = mode;
    rep.skipNaive = skipNaive;
    rep.referenceAlgorithm = referenceAlgorithm;
    rep.ranPartitioned = runPartitioned;
    rep.graphModel = if edgeDensity >= 0.0 then "dense-opt-in" else graphModel;
    rep.partitionStrategy = partitionStrategy;
    rep.undirectedEdges = g.numDirectedEdges() / 2;
    rep.directedEdges = g.numDirectedEdges();
    rep.actualAvgDegree = if n > 0 then (2.0 * rep.undirectedEdges:real) / n:real else 0.0;
    rep.targetAvgDegree = if edgeDensity >= 0.0 then
      (2.0 * (edgeDensity * ((n * (n - 1)) / 2):real)) / (if n > 0 then n:real else 1.0)
      else avgDegree:real;
    rep.generationSec = gen1 - gen0;
    rep.naiveSec = if skipNaive then 0.0 else (naive1 - naive0);
    rep.brandesSeqSec = seq1 - seq0;
    rep.brandesParSec = par1 - par0;
    rep.brandesPartitionedSec = if runPartitioned then (pmsg1 - pmsg0) else 0.0;
    rep.brandesPartitionedParallelSec = if runPartitionedParallel then (ppar1 - ppar0) else 0.0;
    rep.ranPartitionedParallel = runPartitionedParallel;
    rep.partitionedParts = parts;
    rep.minPartitionSize = partitionMetrics.minPartitionSize;
    rep.maxPartitionSize = partitionMetrics.maxPartitionSize;
    rep.partitionCutEdges = partitionMetrics.cutEdges;
    rep.partitionCutEdgeRatio = partitionMetrics.cutEdgeRatio;
    rep.connectedParts = partitionMetrics.connectedParts;
    rep.naiveTotalSec = if skipNaive then 0.0 else (gen1 - gen0) + (naive1 - naive0);
    rep.brandesSeqTotalSec = (gen1 - gen0) + (seq1 - seq0);
    rep.brandesParTotalSec = (gen1 - gen0) + (par1 - par0);
    rep.brandesPartitionedTotalSec = if runPartitioned then (gen1 - gen0) + (pmsg1 - pmsg0) else 0.0;
    rep.brandesPartitionedParallelTotalSec = if runPartitionedParallel then (gen1 - gen0) + (ppar1 - ppar0) else 0.0;
    rep.passedSeq = okSeq;
    rep.passedPar = okPar;
    rep.passedPartitioned = okPartitioned;
    rep.passedPartitionedParallel = okPartitionedParallel;
    rep.relaxMessagesSent = pMetrics.relaxMessagesSent;
    rep.dependencyMessagesSent = pMetrics.dependencyMessagesSent;
    rep.cutEdgeTraversals = pMetrics.cutEdgeTraversals;
    rep.bfsLevelsProcessed = pMetrics.bfsLevelsProcessed;
    rep.backwardLevelsProcessed = pMetrics.backwardLevelsProcessed;
    rep.partitionedForwardBfsSec = pMetrics.forwardBfsSec;
    rep.partitionedBackwardSec = pMetrics.backwardSec;
    rep.partitionedMessageSec = pMetrics.messageSec;
    rep.partitionedGatherSec = pMetrics.gatherSec;
    rep.pparRelaxMessagesSent = pparMetrics.relaxMessagesSent;
    rep.pparDependencyMessagesSent = pparMetrics.dependencyMessagesSent;
    rep.pparCutEdgeTraversals = pparMetrics.cutEdgeTraversals;
    rep.pparBfsLevelsProcessed = pparMetrics.bfsLevelsProcessed;
    rep.pparBackwardLevelsProcessed = pparMetrics.backwardLevelsProcessed;
    rep.pparForwardBfsSec = pparMetrics.forwardBfsSec;
    rep.pparBackwardSec = pparMetrics.backwardSec;
    rep.pparMessageSec = pparMetrics.messageSec;
    rep.pparGatherSec = pparMetrics.gatherSec;

    printRunReport(rep);
  }

  proc main() {
    if n < 1 {
      writeln("ERROR: --n must be >= 1");
      return;
    }

    if command == "Generate" {
      doGenerate(n, seed);
    } else if command == "Run" {
      doRun(n, seed);
    } else {
      writeln("ERROR: unknown --command=", command,
              ". Use Generate or Run.");
    }
  }
}
