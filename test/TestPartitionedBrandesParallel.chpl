module TestPartitionedBrandesParallel {
  use GraphCSR;
  use GraphGenerator;
  use BrandesBC;
  use PartitionedBrandesParallel;

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

  private proc assertApproxEqual(ref a: [] real, ref b: [] real, eps: real = 1.0e-9) {
    assert(a.domain == b.domain);
    for i in a.domain do
      assert(abs(a[i] - b[i]) <= eps);
  }

  private proc runCase(ref g: CSRGraph) {
    var refBc = computeBrandesBCReal(g);
    for parts in (1, 2, 4) {
      var got = computePartitionedBrandesBCParallelReal(g, if parts <= g.n then parts else g.n);
      assertApproxEqual(refBc, got, 1.0e-9);
    }
  }

  private proc testPathGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 1, 2, 3];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);
    runCase(g);
  }

  private proc testStarGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 0, 0, 0];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);
    runCase(g);
  }

  private proc testRandomGraph() {
    var g = generateConnectedRandomGraph(20, 4242);
    runCase(g);
  }

  proc main() {
    testPathGraph();
    testStarGraph();
    testRandomGraph();
    writeln("TestPartitionedBrandesParallel: PASS");
  }
}
