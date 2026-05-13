/*
  Unit-тесты параллельного Brandes (coforall):
    - path graph
    - star graph
    - малый случайный граф

  Сравниваем с Naive по real с малым eps.
*/
module TestBrandesBCParallel {
  use GraphCSR;
  use GraphGenerator;
  use NaiveBC;
  use BrandesBCParallel;
  use Compare;

  private proc buildCSRFromEdges(n: int, edgeU: [] int, edgeV: [] int): CSRGraph {
    var g: CSRGraph;
    g.n = n;

    var deg: [0..n-1] int;
    deg = 0;

    for i in edgeU.domain {
      const u = edgeU[i];
      const v = edgeV[i];
      assert(u != v);
      deg[u] += 1;
      deg[v] += 1;
    }

    g.rowDom = {0..n};
    g.rowPtr = [i in g.rowDom] 0;
    for v in 0..n-1 do
      g.rowPtr[v+1] = g.rowPtr[v] + deg[v];

    g.colDom = {0..g.rowPtr[n]-1};
    g.colIdx = [i in g.colDom] 0;

    var nextPos: [0..n-1] int;
    for v in 0..n-1 do
      nextPos[v] = g.rowPtr[v];

    for i in edgeU.domain {
      const u = edgeU[i];
      const v = edgeV[i];
      g.colIdx[nextPos[u]] = v;
      nextPos[u] += 1;
      g.colIdx[nextPos[v]] = u;
      nextPos[v] += 1;
    }

    return g;
  }

  private proc checkAgainstNaive(ref g: CSRGraph) {
    var naive = computeNaiveBCReal(g);
    var par = computeBrandesBCParallelReal(g, 4);
    assert(approximatelyEqual(naive, par, 1.0e-9));
  }

  private proc testPathGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 1, 2, 3];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);
    checkAgainstNaive(g);
  }

  private proc testStarGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 0, 0, 0];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);
    checkAgainstNaive(g);
  }

  private proc testSmallRandomGraph() {
    var g = generateConnectedRandomGraph(12, 909);
    checkAgainstNaive(g);
  }

  proc main() {
    testPathGraph();
    testStarGraph();
    testSmallRandomGraph();
    writeln("TestBrandesBCParallel: PASS");
  }
}
