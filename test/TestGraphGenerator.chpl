/*
  Минимальный unit-тест генератора на связную цепочку.
*/
module TestGraphGenerator {
  use GraphGenerator;

  proc main() {
    const n = 4;
    const seed = 123;
    var g = generateConnectedRandomGraph(n, seed);

    assert(g.n == 4);
    assert(g.rowPtr.size == 5);
    assert(g.colIdx.size == 6);

    writeln("TestGraphGenerator: PASS");
  }
}
