/*
  PartitionedGraph.chpl
  Простая инфраструктура разбиения CSR-графа на contiguous-блоки по id вершины.

  Это первый шаг для Partitioned Message-Passing Brandes.
*/
module PartitionedGraph {
  use GraphCSR;

  record PartitionedGraph {
    var n: int;
    var numParts: int;

    // blockSize = ceil(n / numParts)
    var blockSize: int;

    // Для каждой part: [start, end) по глобальным вершинам.
    var partDom: domain(1) = {0..-1};
    var firstV: [partDom] int;
    var lastVExclusive: [partDom] int;

    proc ownerOfVertex(v: int): int {
      if v < 0 || v >= n then
        halt("ownerOfVertex: vertex out of range: ", v);

      var p = v / blockSize;
      if p >= numParts then
        p = numParts - 1;
      return p;
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

  proc buildPartitionedGraph(ref g: CSRGraph, numParts: int): PartitionedGraph {
    if numParts <= 0 then
      halt("buildPartitionedGraph: numParts must be > 0");

    var pg: PartitionedGraph;
    pg.n = g.n;
    pg.numParts = numParts;

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

    for p in pg.partDom {
      const start = p * pg.blockSize;
      const endEx = min(pg.n, start + pg.blockSize);

      pg.firstV[p] = if start <= pg.n then start else pg.n;
      pg.lastVExclusive[p] = if endEx <= pg.n then endEx else pg.n;
    }

    return pg;
  }
}
