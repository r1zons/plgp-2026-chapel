/*
  Unit-тесты для PartitionedGraph.
*/
module TestPartitionedGraph {
  use GraphCSR;
  use GraphGenerator;
  use PartitionedGraph;

  private proc assertUniqueOwnership(ref pg: PartitionedGraph) {
    for v in 0..pg.n-1 {
      const p = pg.ownerOfVertex(v);
      assert(0 <= p && p < pg.numParts);

      const first = pg.firstVertexOfPart(p);
      const last = pg.lastVertexOfPart(p);
      assert(first <= v && v <= last);
    }
  }

  private proc assertMappings(ref pg: PartitionedGraph) {
    for v in 0..pg.n-1 {
      const p = pg.ownerOfVertex(v);
      const li = pg.localIndexOfVertex(v);
      const gv = pg.globalVertexOf(p, li);
      assert(gv == v);
    }
  }

  private proc assertPartLayoutSafe(ref pg: PartitionedGraph) {
    // Части не пересекаются, порядок неубывающий.
    for p in 0..pg.numParts-2 {
      const aEndEx = pg.firstVertexOfPart(p) + pg.numLocalVertices(p);
      const bStart = pg.firstVertexOfPart(p+1);
      assert(aEndEx <= bStart);
    }

    // Сумма локальных вершин равна n.
    var total = 0;
    for p in 0..pg.numParts-1 do
      total += pg.numLocalVertices(p);
    assert(total == pg.n);

    // Пустые части допустимы и должны быть безопасными.
    for p in 0..pg.numParts-1 {
      const nv = pg.numLocalVertices(p);
      if nv == 0 {
        assert(pg.lastVertexOfPart(p) == pg.firstVertexOfPart(p) - 1);
      } else {
        assert(pg.lastVertexOfPart(p) >= pg.firstVertexOfPart(p));
      }
    }
  }

  private proc runCase(n: int, numParts: int, seed: int) {
    var g = generateConnectedRandomGraph(n, seed);
    var pg = buildPartitionedGraph(g, numParts);

    assert(pg.n == n);
    assert(pg.numParts == numParts);

    assertUniqueOwnership(pg);
    assertMappings(pg);
    assertPartLayoutSafe(pg);
  }

  proc main() {
    runCase(1, 1, 1);
    runCase(5, 2, 2);
    runCase(7, 3, 3);

    writeln("TestPartitionedGraph: PASS");
  }
}
