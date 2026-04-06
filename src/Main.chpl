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

  proc doGenerate(n: int, seed: int) {
    const t0 = timeSinceEpoch().totalSeconds();
    var g = generateConnectedRandomGraph(n, seed);
    const t1 = timeSinceEpoch().totalSeconds();

    var rep: RunReport;
    rep.command = "Generate";
    rep.n = n;
    rep.seed = seed;
    rep.generationSec = t1 - t0;
    rep.naiveSec = 0.0;
    rep.brandesSec = 0.0;
    rep.totalSec = t1 - t0;
    rep.passed = true;

    writeln("Graph generated: vertices=", g.numVertices(),
            ", directed_edges=", g.numDirectedEdges());

    // Визуальная проверка для очень маленьких графов.
    if n <= 20 then
      printSmallGraph(g);

    printReport(rep);
  }

  proc doRun(n: int, seed: int) {
    const all0 = timeSinceEpoch().totalSeconds();

    const gen0 = timeSinceEpoch().totalSeconds();
    var g = generateConnectedRandomGraph(n, seed);
    const gen1 = timeSinceEpoch().totalSeconds();

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

    const exactOk = exactlyEqualFractions(naiveNum, naiveDen, brandesNum, brandesDen);

    var ok = exactOk;
    if !exactOk {
      // Защита от переполнений/потери точности в больших рациональных дробях.
      var naiveReal = computeNaiveBCReal(g);
      var brandesReal = computeBrandesBCReal(g);
      ok = approximatelyEqual(naiveReal, brandesReal, 1.0e-9);
    }

    const all1 = timeSinceEpoch().totalSeconds();

    var rep: RunReport;
    rep.command = "Run";
    rep.n = n;
    rep.seed = seed;
    rep.generationSec = gen1 - gen0;
    rep.naiveSec = naive1 - naive0;
    rep.brandesSec = brandes1 - brandes0;
    rep.totalSec = all1 - all0;
    rep.passed = ok;

    printReport(rep);
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
