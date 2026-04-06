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
    var brandesSec: real;
    var naiveTotalSec: real;
    var brandesTotalSec: real;
    var passed: bool;
  }

  proc printRunReport(rep: RunReport) {
    writeln("Graph size: ", rep.n);
    writeln("Seed: ", rep.seed);
    writeln("Generation time: ", rep.generationSec);
    writeln("Naive time: ", rep.naiveSec);
    writeln("Brandes time: ", rep.brandesSec);
    writeln("Naive total: ", rep.naiveTotalSec);
    writeln("Brandes total: ", rep.brandesTotalSec);
    writeln("Correctness check: ", if rep.passed then "PASS" else "FAIL");
  }
}
