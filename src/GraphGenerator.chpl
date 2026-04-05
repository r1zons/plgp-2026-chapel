/*
  GraphGenerator.chpl
  Генерация связного случайного невзвешенного неориентированного графа в CSR.

  Подход:
    1) Случайное остовное дерево (гарантия связности).
    2) Добавление случайных рёбер до целевой плотности.

  Ограничения:
    - Без петель.
    - Без дубликатов неориентированных рёбер.
*/
module GraphGenerator {
  use Random;
  use GraphCSR;

  // Целевая доля от максимально возможного числа неориентированных рёбер.
  // На этом этапе оставляем константой (не выносим в CLI).
  config const defaultEdgeDensity: real = 0.20;

  // Нормализуем неориентированное ребро так, чтобы u <= v.
  private proc normalizeEdge(u: int, v: int): 2*int {
    if u <= v then
      return (u, v);
    else
      return (v, u);
  }

  // Возвращает случайное целое в диапазоне [lo, hi].
  private proc randomIntInRange(ref rng: randomStream(uint(64)), lo: int, hi: int): int {
    const span = (hi - lo + 1):uint(64);
    const r = rng.next() % span;
    return lo + r:int;
  }

  // Пытается добавить неориентированное ребро (u, v) в множество рёбер.
  // Возвращает true, если ребро действительно добавлено.
  private proc tryAddEdge(ref edgeDom: domain(2*int), u: int, v: int): bool {
    if u == v then
      return false;

    const e = normalizeEdge(u, v);
    if edgeDom.contains(e) then
      return false;

    edgeDom += e;
    return true;
  }

  // Строим CSR из множества неориентированных рёбер edgeDom.
  private proc buildCSRFromEdgeSet(n: int, edgeDom: domain(2*int)): CSRGraph {
    var g: CSRGraph;
    g.n = n;

    if n <= 0 {
      g.rowDom = {0..0};
      g.rowPtr = [i in g.rowDom] 0;
      g.colDom = {0..-1};
      g.colIdx = [i in g.colDom] 0;
      return g;
    }

    var deg: [0..n-1] int;
    deg = 0;

    for (u, v) in edgeDom {
      deg[u] += 1;
      deg[v] += 1;
    }

    g.rowDom = {0..n};
    g.rowPtr = [i in g.rowDom] 0;

    for v in 0..n-1 {
      g.rowPtr[v+1] = g.rowPtr[v] + deg[v];
    }

    const mDirected = g.rowPtr[n];
    g.colDom = {0..mDirected-1};
    g.colIdx = [i in g.colDom] 0;

    var nextPos: [0..n-1] int;
    for v in 0..n-1 do
      nextPos[v] = g.rowPtr[v];

    for (u, v) in edgeDom {
      g.colIdx[nextPos[u]] = v;
      nextPos[u] += 1;

      g.colIdx[nextPos[v]] = u;
      nextPos[v] += 1;
    }

    return g;
  }

  proc generateConnectedRandomGraph(n: int, seed: int): CSRGraph {
    var g: CSRGraph;

    if n <= 0 {
      g.n = 0;
      g.rowDom = {0..0};
      g.rowPtr = [i in g.rowDom] 0;
      g.colDom = {0..-1};
      g.colIdx = [i in g.colDom] 0;
      return g;
    }

    if n == 1 {
      g.n = 1;
      g.rowDom = {0..1};
      g.rowPtr = [i in g.rowDom] 0;
      g.colDom = {0..-1};
      g.colIdx = [i in g.colDom] 0;
      return g;
    }

    var rng = new randomStream(uint(64), seed=seed:int(64));

    // Множество уникальных неориентированных рёбер.
    var edgeDom: domain(2*int);

    // 1) Случайное остовное дерево:
    // для каждой вершины v = 1..n-1 выбираем случайного родителя в [0, v-1].
    for v in 1..n-1 {
      const parent = randomIntInRange(rng, 0, v-1);
      const added = tryAddEdge(edgeDom, v, parent);
      // Для дерева добавление всегда должно быть успешным.
      if !added then
        halt("Internal error: failed to add tree edge");
    }

    // 2) Дополняем случайными рёбрами до целевой плотности.
    const maxEdgesUndirected = (n * (n - 1)) / 2;
    const minEdgesUndirected = n - 1;

    var targetEdgesUndirected = (defaultEdgeDensity * maxEdgesUndirected:real):int;
    if targetEdgesUndirected < minEdgesUndirected then
      targetEdgesUndirected = minEdgesUndirected;
    if targetEdgesUndirected > maxEdgesUndirected then
      targetEdgesUndirected = maxEdgesUndirected;

    // Ограничиваем число попыток, чтобы избежать длинных циклов на плотных графах.
    var attempts = 0;
    const maxAttempts = 20 * maxEdgesUndirected + 100;

    while edgeDom.size < targetEdgesUndirected && attempts < maxAttempts {
      attempts += 1;
      const u = randomIntInRange(rng, 0, n-1);
      const v = randomIntInRange(rng, 0, n-1);
      tryAddEdge(edgeDom, u, v);
    }

    return buildCSRFromEdgeSet(n, edgeDom);
  }

  // Для очень маленьких графов удобно вывести CSR и список соседей.
  proc printSmallGraph(ref g: CSRGraph, maxN: int = 20) {
    if g.n > maxN {
      writeln("Graph is too large to print: n=", g.n, ", maxN=", maxN);
      return;
    }

    writeln("CSR graph: n=", g.n,
            ", directed_edges=", g.numDirectedEdges(),
            ", undirected_edges=", g.numDirectedEdges()/2);
    writeln("rowPtr:");
    for i in g.rowDom {
      write(g.rowPtr[i], if i == g.rowDom.high then "\n" else " ");
    }

    writeln("adjacency lists:");
    for v in 0..g.n-1 {
      write("  ", v, ": ");
      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        write(g.colIdx[p], " ");
      }
      writeln();
    }
  }
}
