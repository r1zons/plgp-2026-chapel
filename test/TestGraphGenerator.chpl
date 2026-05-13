/*
  Unit-тест генератора случайного связного графа.

  Проверки:
    - связность
    - отсутствие петель
    - отсутствие дубликатов неориентированных рёбер
    - корректность CSR

  Прогоняем на n=5 и n=7.
*/
module TestGraphGenerator {
  use GraphCSR;
  use GraphGenerator;

  private proc assertCSRWellFormed(ref g: CSRGraph) {
    assert(g.rowPtr.size == g.n + 1);
    assert(g.rowPtr[0] == 0);

    for i in 0..g.n-1 {
      assert(g.rowPtr[i] <= g.rowPtr[i+1]);
    }

    assert(g.rowPtr[g.n] == g.colIdx.size);

    for idx in g.colDom {
      const u = g.colIdx[idx];
      assert(0 <= u && u < g.n);
    }
  }

  private proc assertNoSelfLoops(ref g: CSRGraph) {
    for v in 0..g.n-1 {
      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        assert(g.colIdx[p] != v);
      }
    }
  }

  private proc assertNoUndirectedDuplicates(ref g: CSRGraph) {
    // Для каждого неориентированного ребра храним (min(u,v), max(u,v)).
    var seen: domain(2*int);

    for v in 0..g.n-1 {
      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const u = g.colIdx[p];
        const a = if v <= u then v else u;
        const b = if v <= u then u else v;

        // Считаем только одно направление, чтобы не ловить нормальную симметрию CSR.
        if v < u {
          assert(!seen.contains((a, b)));
          seen += (a, b);
        }
      }
    }
  }

  private proc assertConnected(ref g: CSRGraph) {
    if g.n == 0 then
      return;

    var visited: [0..g.n-1] bool;
    visited = false;

    // Простая очередь на массиве (BFS).
    var q: [0..g.n-1] int;
    var head = 0;
    var tail = 0;

    q[tail] = 0;
    tail += 1;
    visited[0] = true;

    while head < tail {
      const v = q[head];
      head += 1;

      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const u = g.colIdx[p];
        if !visited[u] {
          visited[u] = true;
          q[tail] = u;
          tail += 1;
        }
      }
    }

    for v in 0..g.n-1 do
      assert(visited[v]);
  }

  private proc expectedTargetEdges(n: int, avgD: int): int {
    if n <= 1 then
      return 0;
    const maxEdges = (n * (n - 1)) / 2;
    const minEdges = n - 1;
    var target = ((n * avgD) + 1) / 2; // round(n*avgD/2)
    if target < minEdges then target = minEdges;
    if target > maxEdges then target = maxEdges;
    return target;
  }

  private proc communityOf(v: int, n: int, communities: int): int {
    return (v * communities) / n;
  }

  private proc countInterCommunityEdges(ref g: CSRGraph, communities: int): int {
    var count = 0;

    for v in 0..g.n-1 {
      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const u = g.colIdx[p];
        if v < u && communityOf(v, g.n, communities) != communityOf(u, g.n, communities) then
          count += 1;
      }
    }

    return count;
  }

  private proc runCase(n: int, seed: int, avgD: int = 16) {
    var g = generateConnectedRandomGraph(n, seed);

    assert(g.n == n);
    assertCSRWellFormed(g);
    assertNoSelfLoops(g);
    assertNoUndirectedDuplicates(g);
    assertConnected(g);

    const undirectedEdges = g.numDirectedEdges() / 2;
    const targetEdges = expectedTargetEdges(n, avgD);
    const tol = max(2, (targetEdges * 10) / 100);
    assert(abs(undirectedEdges - targetEdges) <= tol);
  }

  private proc runClusteredCase(n: int, seed: int, communities: int,
                                interFraction: real, avgD: int) {
    var g = generateConnectedClusteredRandomGraph(n, seed, communities,
                                                  interFraction, avgD);

    assert(g.n == n);
    assertCSRWellFormed(g);
    assertNoSelfLoops(g);
    assertNoUndirectedDuplicates(g);
    assertConnected(g);

    const undirectedEdges = g.numDirectedEdges() / 2;
    const targetEdges = expectedTargetEdges(n, avgD);
    const tol = max(2, (targetEdges * 10) / 100);
    assert(abs(undirectedEdges - targetEdges) <= tol);

    const interEdges = countInterCommunityEdges(g, communities);
    assert(interEdges >= communities - 1);
    assert(interEdges > 0);
    assert(interEdges < undirectedEdges / 2);
  }

  proc main() {
    runCase(5, 101, 16);
    runCase(100, 202, 16);
    runCase(1000, 303, 16);
    runClusteredCase(40, 404, 4, 0.10, 6);
    runClusteredCase(75, 505, 5, 0.05, 8);

    writeln("TestGraphGenerator: PASS");
  }
}
