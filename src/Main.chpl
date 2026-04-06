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
  use Compare;
  use Report;

  config const command = "Run";
  config const n = 10;
  config const seed = 1;

  private proc printFirstRealMismatches(ref naive: [] real, ref brandes: [] real,
                                        eps: real, maxCount: int = 5) {
    var printed = 0;
    for v in naive.domain {
      const diff = abs(naive[v] - brandes[v]);
      if diff > eps {
        writeln("Mismatch at vertex ", v,
                ": naive=", naive[v],
                ", brandes=", brandes[v],
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

    const brandes0 = timeSinceEpoch().totalSeconds();
    var brandes = computeBrandesBCReal(g);
    const brandes1 = timeSinceEpoch().totalSeconds();

    const eps = 1.0e-9;
    const ok = approximatelyEqual(naive, brandes, eps);

    if !ok {
      printFirstRealMismatches(naive, brandes, eps, 5);
    }

    var rep: RunReport;
    rep.n = n;
    rep.seed = seed;
    rep.generationSec = gen1 - gen0;
    rep.naiveSec = naive1 - naive0;
    rep.brandesSec = brandes1 - brandes0;
    rep.naiveTotalSec = (gen1 - gen0) + (naive1 - naive0);
    rep.brandesTotalSec = (gen1 - gen0) + (brandes1 - brandes0);
    rep.passed = ok;

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
