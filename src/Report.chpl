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
    var naiveTotalSec: real;
    var brandesSeqTotalSec: real;
    var brandesParTotalSec: real;
    var passedSeq: bool;
    var passedPar: bool;
  }

  proc printRunReport(rep: RunReport) {
    writeln("\n=== Run: Graph Info ===");
    writeln("Graph size: ", rep.n);
    writeln("Seed: ", rep.seed);

    writeln("\n=== Run: Timings ===");
    writeln("Generation time: ", rep.generationSec);
    writeln("Naive time: ", rep.naiveSec);
    writeln("Brandes time: ", rep.brandesSeqSec);
    writeln("Parallel Brandes time: ", rep.brandesParSec);

    writeln("\n=== Run: Totals ===");
    writeln("Naive total: ", rep.naiveTotalSec);
    writeln("Brandes total: ", rep.brandesSeqTotalSec);
    writeln("Parallel Brandes total: ", rep.brandesParTotalSec);

    writeln("\n=== Run: Correctness ===");
    writeln("Correctness check seq: ", if rep.passedSeq then "PASS" else "FAIL");
    writeln("Correctness check par: ", if rep.passedPar then "PASS" else "FAIL");
  }
}
