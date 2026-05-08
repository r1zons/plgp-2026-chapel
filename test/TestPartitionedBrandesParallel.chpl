module TestPartitionedBrandesParallel {
  use GraphCSR;
  use GraphGenerator;
  use BrandesBC;
  use PartitionedBrandesParallel;

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
