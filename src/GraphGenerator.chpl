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
  use Math;
  use GraphCSR;

  // Новая default-модель: sparse граф через целевую среднюю степень.
  config const graphModel = "sparse";
  config const avgDegree: int = 16;
  config const numCommunities: int = 4;
  config const interCommunityFraction: real = 0.05;
  // Старую density-модель оставляем только как явный opt-in.
  // Если edgeDensity >= 0, используется именно она.
  config const edgeDensity: real = -1.0;

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

  private proc targetEdgesForAvgDegree(n: int, requestedAvgDegree: int,
                                       allowEdgeDensity: bool = true): int {
    if n <= 1 then
      return 0;

    const maxEdgesUndirected = (n * (n - 1)) / 2;
    const minEdgesUndirected = n - 1;
    var targetEdgesUndirected: int;

    if allowEdgeDensity && edgeDensity >= 0.0 {
      targetEdgesUndirected = (edgeDensity * maxEdgesUndirected:real):int;
    } else {
      const rawTarget = (n:real * requestedAvgDegree:real) / 2.0;
      targetEdgesUndirected = round(rawTarget):int;
    }

    if targetEdgesUndirected < minEdgesUndirected then
      targetEdgesUndirected = minEdgesUndirected;
    if targetEdgesUndirected > maxEdgesUndirected then
      targetEdgesUndirected = maxEdgesUndirected;

    return targetEdgesUndirected;
  }

  private proc sanitizedCommunityCount(n: int, requestedNumCommunities: int): int {
    if n <= 1 then
      return 1;

    var communities = requestedNumCommunities;
    if communities < 1 then
      communities = 1;
    if communities > n then
      communities = n;

    return communities;
  }

  private proc communityOfVertex(v: int, n: int, communities: int): int {
    if communities <= 1 then
      return 0;
    return (v * communities) / n;
  }

  private proc firstVertexOfCommunity(c: int, n: int, communities: int): int {
    return (c * n) / communities;
  }

  private proc lastVertexExclusiveOfCommunity(c: int, n: int, communities: int): int {
    return ((c + 1) * n) / communities;
  }

  private proc countInterCommunityEdges(edgeDom: domain(2*int),
                                        n: int,
                                        communities: int): int {
    var count = 0;
    for (u, v) in edgeDom {
      if communityOfVertex(u, n, communities) != communityOfVertex(v, n, communities) then
        count += 1;
    }
    return count;
  }

  private proc tryAddRandomIntraCommunityEdge(ref rng: randomStream(uint(64)),
                                              ref edgeDom: domain(2*int),
                                              n: int,
                                              communities: int): bool {
    const maxAttempts = 20 * n + 100;
    var attempts = 0;

    while attempts < maxAttempts {
      attempts += 1;

      const c = randomIntInRange(rng, 0, communities - 1);
      const first = firstVertexOfCommunity(c, n, communities);
      const lastEx = lastVertexExclusiveOfCommunity(c, n, communities);
      if lastEx - first < 2 then
        continue;

      const u = randomIntInRange(rng, first, lastEx - 1);
      const v = randomIntInRange(rng, first, lastEx - 1);
      if tryAddEdge(edgeDom, u, v) then
        return true;
    }

    return false;
  }

  private proc tryAddRandomInterCommunityEdge(ref rng: randomStream(uint(64)),
                                              ref edgeDom: domain(2*int),
                                              n: int,
                                              communities: int): bool {
    if communities < 2 then
      return false;

    const maxAttempts = 20 * n + 100;
    var attempts = 0;

    while attempts < maxAttempts {
      attempts += 1;

      const c1 = randomIntInRange(rng, 0, communities - 1);
      var c2 = randomIntInRange(rng, 0, communities - 2);
      if c2 >= c1 then
        c2 += 1;

      const first1 = firstVertexOfCommunity(c1, n, communities);
      const lastEx1 = lastVertexExclusiveOfCommunity(c1, n, communities);
      const first2 = firstVertexOfCommunity(c2, n, communities);
      const lastEx2 = lastVertexExclusiveOfCommunity(c2, n, communities);

      const u = randomIntInRange(rng, first1, lastEx1 - 1);
      const v = randomIntInRange(rng, first2, lastEx2 - 1);
      if tryAddEdge(edgeDom, u, v) then
        return true;
    }

    return false;
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
    if graphModel == "clustered" {
      return generateConnectedClusteredRandomGraph(n, seed);
    } else if graphModel != "sparse" {
      halt("Unsupported graphModel=", graphModel, ". Use sparse or clustered.");
    }

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

    const maxEdgesUndirected = (n * (n - 1)) / 2;
    // 2) Дополняем случайными рёбрами до целевого числа.
    const targetEdgesUndirected = targetEdgesForAvgDegree(n, avgDegree);

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

  proc generateConnectedClusteredRandomGraph(n: int, seed: int,
                                             requestedNumCommunities: int = numCommunities,
                                             requestedInterCommunityFraction: real = interCommunityFraction,
                                             requestedAvgDegree: int = avgDegree): CSRGraph {
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

    const communities = sanitizedCommunityCount(n, requestedNumCommunities);
    var rng = new randomStream(uint(64), seed=seed:int(64));
    var edgeDom: domain(2*int);

    // Сначала строим связный clustered каркас:
    // дерево внутри каждой community плюс цепочка межcommunity рёбер.
    for c in 0..communities-1 {
      const first = firstVertexOfCommunity(c, n, communities);
      const lastEx = lastVertexExclusiveOfCommunity(c, n, communities);

      for v in first+1..lastEx-1 {
        const parent = randomIntInRange(rng, first, v - 1);
        const added = tryAddEdge(edgeDom, v, parent);
        if !added then
          halt("Internal error: failed to add clustered tree edge");
      }
    }

    for c in 1..communities-1 {
      const prevFirst = firstVertexOfCommunity(c - 1, n, communities);
      const prevLastEx = lastVertexExclusiveOfCommunity(c - 1, n, communities);
      const curFirst = firstVertexOfCommunity(c, n, communities);
      const curLastEx = lastVertexExclusiveOfCommunity(c, n, communities);
      const u = randomIntInRange(rng, prevFirst, prevLastEx - 1);
      const v = randomIntInRange(rng, curFirst, curLastEx - 1);
      const added = tryAddEdge(edgeDom, u, v);
      if !added then
        halt("Internal error: failed to add clustered bridge edge");
    }

    const targetEdgesUndirected = targetEdgesForAvgDegree(n, requestedAvgDegree, false);
    var boundedInterFraction = requestedInterCommunityFraction;
    if boundedInterFraction < 0.0 then
      boundedInterFraction = 0.0;
    if boundedInterFraction > 1.0 then
      boundedInterFraction = 1.0;

    var targetInterEdges = round(targetEdgesUndirected:real * boundedInterFraction):int;
    if targetInterEdges < 0 then
      targetInterEdges = 0;
    if targetInterEdges > targetEdgesUndirected then
      targetInterEdges = targetEdgesUndirected;

    var interEdges = countInterCommunityEdges(edgeDom, n, communities);
    const maxEdgesUndirected = (n * (n - 1)) / 2;
    const maxAttempts = 20 * maxEdgesUndirected + 100;
    var attempts = 0;

    while edgeDom.size < targetEdgesUndirected && attempts < maxAttempts {
      attempts += 1;

      if communities > 1 && interEdges < targetInterEdges {
        if tryAddRandomInterCommunityEdge(rng, edgeDom, n, communities) {
          interEdges += 1;
        } else {
          tryAddRandomIntraCommunityEdge(rng, edgeDom, n, communities);
        }
      } else {
        if !tryAddRandomIntraCommunityEdge(rng, edgeDom, n, communities) {
          if tryAddRandomInterCommunityEdge(rng, edgeDom, n, communities) then
            interEdges += 1;
        }
      }
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
