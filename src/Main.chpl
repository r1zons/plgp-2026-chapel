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
  use Compare;
  use Report;

  config const command = "Run";
  config const n = 10;
  config const seed = 1;
  config const parTasks = 0;

  private proc printFirstRealMismatches(ref base: [] real, ref other: [] real,
                                        eps: real, label: string,
                                        maxCount: int = 5) {
    var printed = 0;
    for v in base.domain {
      const diff = abs(base[v] - other[v]);
      if diff > eps {
        writeln("Mismatch (", label, ") at vertex ", v,
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

    writeln("Graph generated: vertices=", g.numVertices(),
            ", directed_edges=", g.numDirectedEdges());

    if n <= 20 then
      printSmallGraph(g);

    // Короткая сводка для Generate.
    writeln("Graph size: ", n);
    writeln("Seed: ", seed);
    writeln("Generation time: ", t1 - t0);
  }

  proc doRun(n: int, seed: int) {
    const gen0 = timeSinceEpoch().totalSeconds();
    var g = generateConnectedRandomGraph(n, seed);
    const gen1 = timeSinceEpoch().totalSeconds();

    if n <= 20 then
      printSmallGraph(g);

    const naive0 = timeSinceEpoch().totalSeconds();
    var naive = computeNaiveBCReal(g);
    const naive1 = timeSinceEpoch().totalSeconds();

    const seq0 = timeSinceEpoch().totalSeconds();
    var brandesSeq = computeBrandesBCReal(g);
    const seq1 = timeSinceEpoch().totalSeconds();

    const par0 = timeSinceEpoch().totalSeconds();
    var brandesPar = computeBrandesBCParallelReal(g, parTasks);
    const par1 = timeSinceEpoch().totalSeconds();

    const eps = 1.0e-9;
    const okSeq = approximatelyEqual(naive, brandesSeq, eps);
    const okPar = approximatelyEqual(naive, brandesPar, eps);

    if !okSeq then
      printFirstRealMismatches(naive, brandesSeq, eps, "Naive vs Seq", 5);

    if !okPar then
      printFirstRealMismatches(naive, brandesPar, eps, "Naive vs Par", 5);

    var rep: RunReport;
    rep.n = n;
    rep.seed = seed;
    rep.generationSec = gen1 - gen0;
    rep.naiveSec = naive1 - naive0;
    rep.brandesSeqSec = seq1 - seq0;
    rep.brandesParSec = par1 - par0;
    rep.naiveTotalSec = (gen1 - gen0) + (naive1 - naive0);
    rep.brandesSeqTotalSec = (gen1 - gen0) + (seq1 - seq0);
    rep.brandesParTotalSec = (gen1 - gen0) + (par1 - par0);
    rep.passedSeq = okSeq;
    rep.passedPar = okPar;

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
