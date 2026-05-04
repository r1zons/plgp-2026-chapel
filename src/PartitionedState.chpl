module PartitionedState {
  use PartitionedGraph;

  record PartSourceState {
    var localDom: domain(1) = {0..-1};
    var dist: [localDom] int;
    var sigma: [localDom] int(64);
    var delta: [localDom] real;
    var frontier: [localDom] bool;
    var nextFrontier: [localDom] bool;

    proc ref initLocal(nv: int) {
      if nv < 0 then
        halt("initLocal: nv must be >= 0");
      localDom = {0..nv-1};
      dist = [i in localDom] -1;
      sigma = [i in localDom] 0:int(64);
      delta = [i in localDom] 0.0;
      frontier = [i in localDom] false;
      nextFrontier = [i in localDom] false;
    }

    proc ref reset() {
      for i in localDom {
        dist[i] = -1;
        sigma[i] = 0:int(64);
        delta[i] = 0.0;
        frontier[i] = false;
        nextFrontier[i] = false;
      }
    }

    proc size(): int {
      return localDom.size;
    }
  }

  record PartitionedSourceState {
    var n: int;
    var numParts: int;

    var partDom: domain(1) = {0..-1};
    var firstV: [partDom] int;
    var lastVExclusive: [partDom] int;

    var parts: [partDom] PartSourceState;

    proc initFromPartitionedGraph(ref pg: PartitionedGraph) {
      n = pg.n;
      numParts = pg.numParts;
      partDom = {0..numParts-1};

      firstV = [p in partDom] 0;
      lastVExclusive = [p in partDom] 0;

      for p in partDom {
        firstV[p] = pg.firstVertexOfPart(p);
        lastVExclusive[p] = pg.lastVertexOfPart(p) + 1;

        const nv = pg.numLocalVertices(p);
        parts[p].initLocal(nv);
      }
    }

    proc ownerOfVertex(v: int): int {
      if v < 0 || v >= n then
        halt("ownerOfVertex: vertex out of range: ", v);

      for p in partDom {
        if v >= firstV[p] && v < lastVExclusive[p] then
          return p;
      }
      halt("ownerOfVertex: cannot find owner for vertex ", v);
      return -1;
    }

    proc localIndexOfVertex(v: int): int {
      const p = ownerOfVertex(v);
      return v - firstV[p];
    }

    proc ref resetForSource(source: int) {
      for p in partDom do
        parts[p].reset();

      setDist(source, 0);
      setSigma(source, 1:int(64));
      setFrontier(source, true);
    }

    proc getDist(v: int): int {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      return parts[p].dist[li];
    }

    proc ref setDist(v: int, value: int) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].dist[li] = value;
    }

    proc getSigma(v: int): int(64) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      return parts[p].sigma[li];
    }

    proc ref setSigma(v: int, value: int(64)) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].sigma[li] = value;
    }

    proc ref addSigma(v: int, value: int(64)) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].sigma[li] += value;
    }

    proc getDelta(v: int): real {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      return parts[p].delta[li];
    }

    proc ref setDelta(v: int, value: real) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].delta[li] = value;
    }

    proc ref addDelta(v: int, value: real) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].delta[li] += value;
    }

    proc getFrontier(v: int): bool {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      return parts[p].frontier[li];
    }

    proc ref setFrontier(v: int, value: bool) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].frontier[li] = value;
    }

    proc getNextFrontier(v: int): bool {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      return parts[p].nextFrontier[li];
    }

    proc ref setNextFrontier(v: int, value: bool) {
      const p = ownerOfVertex(v);
      const li = localIndexOfVertex(v);
      parts[p].nextFrontier[li] = value;
    }

    proc ref clearFrontiers() {
      for p in partDom {
        for li in parts[p].localDom {
          parts[p].frontier[li] = false;
          parts[p].nextFrontier[li] = false;
        }
      }
    }

    proc ref swapOrMoveNextFrontierToFrontier() {
      for p in partDom {
        for li in parts[p].localDom {
          parts[p].frontier[li] = parts[p].nextFrontier[li];
          parts[p].nextFrontier[li] = false;
        }
      }
    }

    proc gatherDist(): [0..n-1] int {
      var result: [0..n-1] int;
      result = -1;
      for p in partDom {
        for li in parts[p].localDom {
          const v = firstV[p] + li;
          result[v] = parts[p].dist[li];
        }
      }
      return result;
    }

    proc gatherSigma(): [0..n-1] int(64) {
      var result: [0..n-1] int(64);
      result = 0:int(64);
      for p in partDom {
        for li in parts[p].localDom {
          const v = firstV[p] + li;
          result[v] = parts[p].sigma[li];
        }
      }
      return result;
    }

    proc gatherDelta(): [0..n-1] real {
      var result: [0..n-1] real;
      result = 0.0;
      for p in partDom {
        for li in parts[p].localDom {
          const v = firstV[p] + li;
          result[v] = parts[p].delta[li];
        }
      }
      return result;
    }
  }
}
