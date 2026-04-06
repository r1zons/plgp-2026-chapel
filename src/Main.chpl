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

  private proc printFirstMismatches(ref naiveNum: [] int(64), ref naiveDen: [] int(64),
                                    ref brandesNum: [] int(64), ref brandesDen: [] int(64),
                                    maxCount: int = 5) {
    var printed = 0;
    for v in naiveNum.domain {
      if naiveNum[v] != brandesNum[v] || naiveDen[v] != brandesDen[v] {
        writeln("Mismatch at vertex ", v,
                ": naive=", naiveNum[v], "/", naiveDen[v],
                ", brandes=", brandesNum[v], "/", brandesDen[v]);
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

    var naiveNum: [0..n-1] int(64);
    var naiveDen: [0..n-1] int(64);
    var brandesNum: [0..n-1] int(64);
    var brandesDen: [0..n-1] int(64);

    const naive0 = timeSinceEpoch().totalSeconds();
    computeNaiveBCExact(g, naiveNum, naiveDen);
    const naive1 = timeSinceEpoch().totalSeconds();

    const brandes0 = timeSinceEpoch().totalSeconds();
    computeBrandesBCExact(g, brandesNum, brandesDen);
    const brandes1 = timeSinceEpoch().totalSeconds();

    const ok = exactlyEqualFractions(naiveNum, naiveDen, brandesNum, brandesDen);

    if !ok {
      printFirstMismatches(naiveNum, naiveDen, brandesNum, brandesDen, 5);
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
