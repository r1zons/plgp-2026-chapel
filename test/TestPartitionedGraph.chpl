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

  private proc runContiguousCase() {
    var g = generateConnectedRandomGraph(7, 303);
    var pg = buildContiguousPartitionedGraph(g, 3);

    assert(pg.strategy == "contiguous");
    assert(pg.numLocalVertices(0) == 3);
    assert(pg.numLocalVertices(1) == 3);
    assert(pg.numLocalVertices(2) == 1);
    assert(pg.ownerOfVertex(0) == 0);
    assert(pg.ownerOfVertex(2) == 0);
    assert(pg.ownerOfVertex(3) == 1);
    assert(pg.ownerOfVertex(5) == 1);
    assert(pg.ownerOfVertex(6) == 2);

    assertUniqueOwnership(pg);
    assertMappings(pg);
    assertPartLayoutSafe(pg);
  }

  private proc runCommunityCase() {
    const n = 100;
    const communities = 4;
    var g = generateConnectedClusteredRandomGraph(n, 404, communities, 0.05, 8);
    var pg = buildCommunityPartitionedGraph(g, communities);

    assert(pg.strategy == "community");
    assert(pg.n == n);
    assert(pg.numParts == communities);

    assertUniqueOwnership(pg);
    assertMappings(pg);
    assertPartLayoutSafe(pg);

    for v in 0..n-1 {
      const expectedPart = (v * communities) / n;
      assert(pg.ownerOfVertex(v) == expectedPart);
    }

    var minSize = pg.numLocalVertices(0);
    var maxSize = pg.numLocalVertices(0);
    for p in 0..communities-1 {
      const nv = pg.numLocalVertices(p);
      if nv < minSize then minSize = nv;
      if nv > maxSize then maxSize = nv;
    }
    assert(maxSize - minSize <= 1);

    const metrics = computePartitionMetrics(g, pg);
    assert(metrics.minPartitionSize == minSize);
    assert(metrics.maxPartitionSize == maxSize);
    assert(metrics.connectedParts);
    assert(metrics.cutEdges > 0);
    assert(metrics.cutEdgeRatio > 0.0);
    assert(metrics.cutEdgeRatio < 0.5);
  }

  private proc runInvalidConfigCases() {
    assert(!partitionStrategyConfigIsValid("community", "sparse", 4, 4));
    assert(partitionStrategyConfigErrorMessage("community") ==
           communityStrategyConfigError);

    assert(!partitionStrategyConfigIsValid("community", "clustered", 3, 4));
    assert(partitionStrategyConfigErrorMessage("community") ==
           communityStrategyConfigError);

    assert(partitionStrategyConfigIsValid("contiguous", "sparse", 3, 4));
  }

  proc main() {
    runCase(1, 1, 1);
    runCase(5, 2, 2);
    runCase(7, 3, 3);
    runContiguousCase();
    runCommunityCase();
    runInvalidConfigCases();

    writeln("TestPartitionedGraph: PASS");
  }
}
