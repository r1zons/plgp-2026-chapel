/*
  Unit-тесты forward BFS-фазы Partitioned Message-Passing (single source).
*/
module TestPartitionedBFS {
  use GraphCSR;
  use GraphGenerator;
  use PartitionedGraph;
  use PartitionedBrandes;

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

  private proc referenceBFS(ref g: CSRGraph, source: int,
                            ref dist: [] int, ref sigma: [] int(64)) {
    const n = g.n;
    dist = -1;
    sigma = 0:int(64);

    var q: [0..n-1] int;
    var head = 0;
    var tail = 0;

    dist[source] = 0;
    sigma[source] = 1;
    q[tail] = source;
    tail += 1;

    while head < tail {
      const v = q[head];
      head += 1;

      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const w = g.colIdx[p];

        if dist[w] < 0 {
          dist[w] = dist[v] + 1;
          q[tail] = w;
          tail += 1;
        }

        if dist[w] == dist[v] + 1 {
          sigma[w] += sigma[v];
        }
      }
    }
  }



  private proc referenceSingleSourceDependency(ref g: CSRGraph, source: int): [0..g.n-1] real {
    const n = g.n;
    var dist: [0..n-1] int;
    var sigma: [0..n-1] int(64);

    // BFS + порядок посещения
    dist = -1;
    sigma = 0:int(64);

    var q: [0..n-1] int;
    var stack: [0..n-1] int;
    var head = 0;
    var tail = 0;
    var stackSize = 0;

    dist[source] = 0;
    sigma[source] = 1;
    q[tail] = source;
    tail += 1;

    while head < tail {
      const v = q[head];
      head += 1;

      stack[stackSize] = v;
      stackSize += 1;

      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const w = g.colIdx[p];

        if dist[w] < 0 {
          dist[w] = dist[v] + 1;
          q[tail] = w;
          tail += 1;
        }

        if dist[w] == dist[v] + 1 {
          sigma[w] += sigma[v];
        }
      }
    }

    var delta: [0..n-1] real;
    delta = 0.0;

    var idx = stackSize - 1;
    while idx >= 0 {
      const w = stack[idx];

      for p in g.rowPtr[w]..g.rowPtr[w+1]-1 {
        const v = g.colIdx[p];
        if dist[v] == dist[w] - 1 {
          delta[v] += (sigma[v]:real / sigma[w]:real) * (1.0 + delta[w]);
        }
      }

      idx -= 1;
    }

    var contrib: [0..n-1] real;
    contrib = 0.0;
    for v in 0..n-1 do
      if v != source then
        contrib[v] = delta[v];

    return contrib;
  }

  private proc runOne(ref g: CSRGraph, source: int, numParts: int) {
    var pg = buildPartitionedGraph(g, numParts);
    var got = computePartitionedSingleSourceBFS(g, pg, source);

    var expDist: [0..g.n-1] int;
    var expSigma: [0..g.n-1] int(64);
    referenceBFS(g, source, expDist, expSigma);

    for v in 0..g.n-1 {
      assert(got.dist[v] == expDist[v]);
      assert(got.sigma[v] == expSigma[v]);
    }
  }



  private proc runOneDep(ref g: CSRGraph, source: int, numParts: int) {
    var pg = buildPartitionedGraph(g, numParts);
    var got = computePartitionedSingleSourceDependencies(g, pg, source);
    var exp = referenceSingleSourceDependency(g, source);

    for v in 0..g.n-1 {
      assert(abs(got[v] - exp[v]) <= 1.0e-9);
    }
  }

  private proc testPathGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 1, 2, 3];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);

    runOne(g, 0, 1);
    runOne(g, 0, 2);
    runOne(g, 0, 3);

    runOneDep(g, 0, 1);
    runOneDep(g, 0, 2);
    runOneDep(g, 0, 3);
  }

  private proc testStarGraph() {
    const m = 4;
    var eu: [0..m-1] int = [0, 0, 0, 0];
    var ev: [0..m-1] int = [1, 2, 3, 4];
    var g = buildCSRFromEdges(5, eu, ev);

    runOne(g, 0, 1);
    runOne(g, 0, 2);
    runOne(g, 0, 3);

    runOneDep(g, 0, 1);
    runOneDep(g, 0, 2);
    runOneDep(g, 0, 3);
  }

  private proc testGeneratedGraph() {
    var g = generateConnectedRandomGraph(10, 4242);

    runOne(g, 0, 1);
    runOne(g, 0, 2);
    runOne(g, 0, 3);

    runOneDep(g, 0, 1);
    runOneDep(g, 0, 2);
    runOneDep(g, 0, 3);
  }

  proc main() {
    testPathGraph();
    testStarGraph();
    testGeneratedGraph();

    writeln("TestPartitionedBFS: PASS");
  }
}
