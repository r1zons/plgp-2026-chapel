/*
  PartitionedGraph.chpl
  Простая инфраструктура разбиения CSR-графа на contiguous-блоки по id вершины.

  Это первый шаг для Partitioned Message-Passing Brandes.
*/
module PartitionedGraph {
  use GraphCSR;

  config const partitionStrategy = "contiguous";
  const communityStrategyConfigError =
    "partitionStrategy=community requires graphModel=clustered and partitionedParts == numCommunities";

  record PartitionMetrics {
    var minPartitionSize: int = 0;
    var maxPartitionSize: int = 0;
    var cutEdges: int = 0;
    var cutEdgeRatio: real = 0.0;
    var connectedParts: bool = true;
  }

  record PartitionedGraph {
    var n: int;
    var numParts: int;
    var strategy: string = "contiguous";

    // blockSize = ceil(n / numParts)
    var blockSize: int;

    // Для каждой part: [start, end) по глобальным вершинам.
    var partDom: domain(1) = {0..-1};
    var firstV: [partDom] int;
    var lastVExclusive: [partDom] int;

    proc ownerOfVertex(v: int): int {
      if v < 0 || v >= n then
        halt("ownerOfVertex: vertex out of range: ", v);

      for p in 0..numParts-1 {
        if firstV[p] <= v && v < lastVExclusive[p] then
          return p;
      }

      halt("ownerOfVertex: no owner found for vertex: ", v);
      return -1;
    }

    proc localIndexOfVertex(v: int): int {
      const p = ownerOfVertex(v);
      return v - firstV[p];
    }

    proc globalVertexOf(part: int, localIndex: int): int {
      if part < 0 || part >= numParts then
        halt("globalVertexOf: part out of range: ", part);

      const nv = numLocalVertices(part);
      if localIndex < 0 || localIndex >= nv then
        halt("globalVertexOf: localIndex out of range: ", localIndex,
             " for part ", part);

      return firstV[part] + localIndex;
    }

    proc firstVertexOfPart(part: int): int {
      if part < 0 || part >= numParts then
        halt("firstVertexOfPart: part out of range: ", part);
      return firstV[part];
    }

    proc lastVertexOfPart(part: int): int {
      if part < 0 || part >= numParts then
        halt("lastVertexOfPart: part out of range: ", part);

      // Возвращаем включительно; если part пустая, возвращаем first-1.
      const nv = numLocalVertices(part);
      if nv == 0 then
        return firstV[part] - 1;
      return lastVExclusive[part] - 1;
    }

    proc numLocalVertices(part: int): int {
      if part < 0 || part >= numParts then
        halt("numLocalVertices: part out of range: ", part);
      return lastVExclusive[part] - firstV[part];
    }
  }

  proc partitionStrategyConfigIsValid(strategy: string, graphModel: string,
                                      partitionedParts: int,
                                      numCommunities: int): bool {
    if strategy == "community" then
      return graphModel == "clustered" && partitionedParts == numCommunities;

    return strategy == "contiguous";
  }

  proc partitionStrategyConfigIsValid(graphModel: string, partitionedParts: int,
                                      numCommunities: int): bool {
    return partitionStrategyConfigIsValid(partitionStrategy, graphModel,
                                          partitionedParts, numCommunities);
  }

  proc partitionStrategyConfigErrorMessage(strategy: string): string {
    if strategy == "community" then
      return communityStrategyConfigError;
    return "Unsupported partitionStrategy=" + strategy + ". Use contiguous or community.";
  }

  proc partitionStrategyConfigErrorMessage(): string {
    return partitionStrategyConfigErrorMessage(partitionStrategy);
  }

  private proc initPartitionedGraphBase(const ref g: CSRGraph, numParts: int,
                                        strategy: string): PartitionedGraph {
    if numParts <= 0 then
      halt("buildPartitionedGraph: numParts must be > 0");

    var pg: PartitionedGraph;
    pg.n = g.n;
    pg.numParts = numParts;
    pg.strategy = strategy;

    if pg.n <= 0 {
      pg.blockSize = 1;
    } else {
      pg.blockSize = (pg.n + numParts - 1) / numParts;
      if pg.blockSize <= 0 then
        pg.blockSize = 1;
    }

    pg.partDom = {0..numParts-1};
    pg.firstV = [p in pg.partDom] 0;
    pg.lastVExclusive = [p in pg.partDom] 0;

    return pg;
  }

  proc buildContiguousPartitionedGraph(const ref g: CSRGraph,
                                       numParts: int): PartitionedGraph {
    var pg = initPartitionedGraphBase(g, numParts, "contiguous");

    for p in pg.partDom {
      const start = p * pg.blockSize;
      const endEx = min(pg.n, start + pg.blockSize);

      pg.firstV[p] = if start <= pg.n then start else pg.n;
      pg.lastVExclusive[p] = if endEx <= pg.n then endEx else pg.n;
    }

    return pg;
  }

  proc buildCommunityPartitionedGraph(const ref g: CSRGraph,
                                      numParts: int): PartitionedGraph {
    var pg = initPartitionedGraphBase(g, numParts, "community");

    for p in pg.partDom {
      pg.firstV[p] = (p * pg.n) / pg.numParts;
      pg.lastVExclusive[p] = ((p + 1) * pg.n) / pg.numParts;
    }

    return pg;
  }

  proc buildPartitionedGraph(const ref g: CSRGraph, numParts: int): PartitionedGraph {
    if partitionStrategy == "contiguous" then
      return buildContiguousPartitionedGraph(g, numParts);
    else if partitionStrategy == "community" then
      return buildCommunityPartitionedGraph(g, numParts);
    else
      halt("Unsupported partitionStrategy=", partitionStrategy, ". Use contiguous or community.");
  }

  proc makeCompleteGraph(n: int): CSRGraph {
    var g: CSRGraph;
    g.n = n;

    if n <= 0 {
      g.rowDom = {0..0};
      g.rowPtr = [i in g.rowDom] 0;
      g.colDom = {0..-1};
      g.colIdx = [i in g.colDom] 0;
      return g;
    }

    g.rowDom = {0..n};
    g.rowPtr = [i in g.rowDom] i * (n - 1);

    const mDirected = n * (n - 1);
    g.colDom = {0..mDirected-1};
    g.colIdx = [i in g.colDom] 0;

    for v in 0..n-1 {
      var pos = g.rowPtr[v];
      for u in 0..n-1 {
        if u != v {
          g.colIdx[pos] = u;
          pos += 1;
        }
      }
    }

    return g;
  }

  private proc isPartConnected(const ref g: CSRGraph, ref pg: PartitionedGraph,
                               part: int): bool {
    const nv = pg.numLocalVertices(part);
    if nv <= 1 then
      return true;

    var visited: [0..pg.n-1] bool;
    visited = false;
    var q: [0..pg.n-1] int;
    var head = 0;
    var tail = 0;
    const start = pg.firstVertexOfPart(part);

    visited[start] = true;
    q[tail] = start;
    tail += 1;

    while head < tail {
      const v = q[head];
      head += 1;

      for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const u = g.colIdx[edgeIdx];
        if pg.ownerOfVertex(u) == part && !visited[u] {
          visited[u] = true;
          q[tail] = u;
          tail += 1;
        }
      }
    }

    var seen = 0;
    for li in 0..nv-1 {
      const v = pg.globalVertexOf(part, li);
      if visited[v] then
        seen += 1;
    }

    return seen == nv;
  }

  proc computePartitionMetrics(const ref g: CSRGraph,
                               ref pg: PartitionedGraph): PartitionMetrics {
    var metrics: PartitionMetrics;

    if pg.numParts <= 0 then
      return metrics;

    metrics.minPartitionSize = pg.numLocalVertices(0);
    metrics.maxPartitionSize = pg.numLocalVertices(0);

    for p in 0..pg.numParts-1 {
      const nv = pg.numLocalVertices(p);
      if nv < metrics.minPartitionSize then
        metrics.minPartitionSize = nv;
      if nv > metrics.maxPartitionSize then
        metrics.maxPartitionSize = nv;
      if !isPartConnected(g, pg, p) then
        metrics.connectedParts = false;
    }

    for v in 0..g.n-1 {
      const vp = pg.ownerOfVertex(v);
      for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const u = g.colIdx[edgeIdx];
        if v < u && vp != pg.ownerOfVertex(u) then
          metrics.cutEdges += 1;
      }
    }

    const undirectedEdges = g.numDirectedEdges() / 2;
    metrics.cutEdgeRatio = if undirectedEdges > 0 then
      metrics.cutEdges:real / undirectedEdges:real
      else 0.0;

    return metrics;
  }
}
