/*
  Unit-тесты последовательного Brandes:
    - path graph
    - star graph
    - малый случайный связный граф

  Во всех случаях требуем точное совпадение с NaiveBC (по num/den).
*/
module TestBrandesBC {
  use GraphCSR;
  use GraphGenerator;
  use NaiveBC;
  use BrandesBC;

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

  private proc assertExactArraysEqual(ref nNum: [] int(64), ref nDen: [] int(64),
                                      ref bNum: [] int(64), ref bDen: [] int(64)) {
    for i in nNum.domain {
      assert(nNum[i] == bNum[i]);
      assert(nDen[i] == bDen[i]);
    }
  }

  private proc checkAgainstNaive(ref g: CSRGraph) {
    var nNum: [0..g.n-1] int(64);
    var nDen: [0..g.n-1] int(64);
    var bNum: [0..g.n-1] int(64);
    var bDen: [0..g.n-1] int(64);

    computeNaiveBCExact(g, nNum, nDen);
    computeBrandesBCExact(g, bNum, bDen);

    assertExactArraysEqual(nNum, nDen, bNum, bDen);
  }

  private proc testPathGraph() {
    // Путь: 0-1-2-3-4
    const m = 4;
    var eu: [0..m-1] int = [0, 1, 2, 3];
    var ev: [0..m-1] int = [1, 2, 3, 4];

    var g = buildCSRFromEdges(5, eu, ev);
    checkAgainstNaive(g);
  }

  private proc testStarGraph() {
    // Звезда: центр 0, листья 1..4
    const m = 4;
    var eu: [0..m-1] int = [0, 0, 0, 0];
    var ev: [0..m-1] int = [1, 2, 3, 4];

    var g = buildCSRFromEdges(5, eu, ev);
    checkAgainstNaive(g);
  }

  private proc testSmallRandomGraph() {
    var g = generateConnectedRandomGraph(8, 777);
    checkAgainstNaive(g);
  }

  proc main() {
    testPathGraph();
    testStarGraph();
    testSmallRandomGraph();
    writeln("TestBrandesBC: PASS");
  }
}
