/*
  Report.chpl
  Печать отчёта в stdout.
*/
module Report {
  record RunReport {
    var command: string;
    var n: int;
    var seed: int;
    var generationSec: real;
    var naiveSec: real;
    var brandesSec: real;
    var totalSec: real;
    var passed: bool;
  }

  proc printReport(rep: RunReport) {
    writeln("=== Betweenness Centrality Report ===");
    writeln("command       : ", rep.command);
    writeln("n             : ", rep.n);
    writeln("seed          : ", rep.seed);
    writeln("gen_time_sec  : ", rep.generationSec);
    writeln("naive_time_sec: ", rep.naiveSec);
    writeln("brandes_time_s: ", rep.brandesSec);
    writeln("total_time_sec: ", rep.totalSec);
    writeln("compare       : ", if rep.passed then "PASS" else "FAIL");
  }
}
