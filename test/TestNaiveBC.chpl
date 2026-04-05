/*
  Unit-тесты для наивного betweenness centrality.
  Явно проверяем ожидаемые значения на маленьких графах:
    - path graph
    - star graph
*/
module TestNaiveBC {
  use GraphCSR;
  use NaiveBC;

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

  private proc assertExactValue(num: int(64), den: int(64), expected: int(64)) {
    assert(den == 1:int(64));
    assert(num == expected);
  }

  private proc testPathGraph() {
    // Путь: 0-1-2-3-4
    const m = 4;
    var eu: [0..m-1] int = [0, 1, 2, 3];
    var ev: [0..m-1] int = [1, 2, 3, 4];

    var g = buildCSRFromEdges(5, eu, ev);

    var num: [0..g.n-1] int(64);
    var den: [0..g.n-1] int(64);
    computeNaiveBCExact(g, num, den);

    // Не нормализованная BC для пути из 5 вершин:
    // [0, 3, 4, 3, 0]
    assertExactValue(num[0], den[0], 0);
    assertExactValue(num[1], den[1], 3);
    assertExactValue(num[2], den[2], 4);
    assertExactValue(num[3], den[3], 3);
    assertExactValue(num[4], den[4], 0);
  }

  private proc testStarGraph() {
    // Звезда из 5 вершин: центр 0 и листья 1..4.
    const m = 4;
    var eu: [0..m-1] int = [0, 0, 0, 0];
    var ev: [0..m-1] int = [1, 2, 3, 4];

    var g = buildCSRFromEdges(5, eu, ev);

    var num: [0..g.n-1] int(64);
    var den: [0..g.n-1] int(64);
    computeNaiveBCExact(g, num, den);

    // Не нормализованная BC:
    // center = C(4,2)=6, leaves = 0
    assertExactValue(num[0], den[0], 6);
    assertExactValue(num[1], den[1], 0);
    assertExactValue(num[2], den[2], 0);
    assertExactValue(num[3], den[3], 0);
    assertExactValue(num[4], den[4], 0);
  }

  proc main() {
    testPathGraph();
    testStarGraph();
    writeln("TestNaiveBC: PASS");
  }
}
