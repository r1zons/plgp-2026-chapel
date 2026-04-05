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
          assert((a, b) not in seen);
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

  private proc runCase(n: int, seed: int) {
    var g = generateConnectedRandomGraph(n, seed);

    assert(g.n == n);
    assertCSRWellFormed(g);
    assertNoSelfLoops(g);
    assertNoUndirectedDuplicates(g);
    assertConnected(g);
  }

  proc main() {
    // Требуемые размеры из постановки.
    runCase(5, 101);
    runCase(7, 202);

    writeln("TestGraphGenerator: PASS");
  }
}
