/*
  PartitionedBrandes.chpl
  Первый шаг Partitioned Message-Passing Brandes:
  только forward BFS-фаза для одного источника.
*/
module PartitionedBrandes {
  use GraphCSR;
  use PartitionedGraph;
  use PartitionedMessages;

  record SingleSourceBFSResult {
    var vDom: domain(1) = {0..-1};
    var dist: [vDom] int;
    var sigma: [vDom] int(64);
  }

  proc computePartitionedSingleSourceBFS(ref g: CSRGraph,
                                         ref pg: PartitionedGraph,
                                         source: int): SingleSourceBFSResult {
    if source < 0 || source >= g.n then
      halt("computePartitionedSingleSourceBFS: source out of range: ", source);

    if pg.n != g.n then
      halt("computePartitionedSingleSourceBFS: pg.n must match g.n");

    const n = g.n;

    // Локальные состояния по partition: dist/sigma/frontier только для owned-вершин.
    var localDom: [0..pg.numParts-1] domain(1);
    var localDist: [0..pg.numParts-1] [0..-1] int;
    var localSigma: [0..pg.numParts-1] [0..-1] int(64);
    var frontier: [0..pg.numParts-1] [0..-1] bool;
    var nextFrontier: [0..pg.numParts-1] [0..-1] bool;

    for p in 0..pg.numParts-1 {
      const nv = pg.numLocalVertices(p);
      localDom[p] = {0..nv-1};

      localDist[p] = [i in localDom[p]] -1;
      localSigma[p] = [i in localDom[p]] 0:int(64);
      frontier[p] = [i in localDom[p]] false;
      nextFrontier[p] = [i in localDom[p]] false;
    }

    const sp = pg.ownerOfVertex(source);
    const sLi = pg.localIndexOfVertex(source);
    localDist[sp][sLi] = 0;
    localSigma[sp][sLi] = 1:int(64);
    frontier[sp][sLi] = true;

    var level = 0;
    var msg = new PartitionedMessages(pg.numParts);

    while true {
      var hasWork = false;
      for p in 0..pg.numParts-1 {
        for li in localDom[p] {
          if frontier[p][li] {
            hasWork = true;
            break;
          }
        }
        if hasWork then break;
      }
      if !hasWork then break;

      msg.clearAll();
      for p in 0..pg.numParts-1 do
        for li in localDom[p] do
          nextFrontier[p][li] = false;

      // 1) Локальная обработка frontier и отправка межpart RELAX сообщений.
      for p in 0..pg.numParts-1 {
        for li in localDom[p] {
          if !frontier[p][li] then
            continue;

          const v = pg.globalVertexOf(p, li);
          const sigV = localSigma[p][li];

          for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[edgeIdx];
            const wp = pg.ownerOfVertex(w);

            if wp == p {
              const wLi = pg.localIndexOfVertex(w);
              if localDist[p][wLi] < 0 {
                localDist[p][wLi] = level + 1;
                localSigma[p][wLi] = sigV;
                nextFrontier[p][wLi] = true;
              } else if localDist[p][wLi] == level + 1 {
                localSigma[p][wLi] += sigV;
              }
            } else {
              // Межpartition обновление только через message buffer.
              msg.appendRelax(wp, w, level + 1, sigV);
            }
          }
        }
      }

      // 2) Доставка и применение RELAX сообщений у владельца вершины.
      for p in 0..pg.numParts-1 {
        for m in msg.relaxMessages(p) {
          const wLi = pg.localIndexOfVertex(m.targetVertex);

          if localDist[p][wLi] < 0 {
            localDist[p][wLi] = m.distance;
            localSigma[p][wLi] = m.sigmaContribution;
            nextFrontier[p][wLi] = true;
          } else if localDist[p][wLi] == m.distance {
            localSigma[p][wLi] += m.sigmaContribution;
          }
        }
      }

      // 3) Переход на следующий BFS-уровень.
      for p in 0..pg.numParts-1 {
        for li in localDom[p] {
          frontier[p][li] = nextFrontier[p][li];
        }
      }
      level += 1;
    }

    // Сборка глобальных dist/sigma для тестов.
    var res: SingleSourceBFSResult;
    res.vDom = {0..n-1};
    res.dist = [i in res.vDom] -1;
    res.sigma = [i in res.vDom] 0:int(64);

    for p in 0..pg.numParts-1 {
      for li in localDom[p] {
        const v = pg.globalVertexOf(p, li);
        res.dist[v] = localDist[p][li];
        res.sigma[v] = localSigma[p][li];
      }
    }

    return res;
  }

  proc computePartitionedSingleSourceDependencies(ref g: CSRGraph,
                                                  ref pg: PartitionedGraph,
                                                  source: int): [0..g.n-1] real {
    const n = g.n;
    var localDom: [0..pg.numParts-1] domain(1);
    var localDist: [0..pg.numParts-1] [0..-1] int;
    var localSigma: [0..pg.numParts-1] [0..-1] int(64);
    var localDelta: [0..pg.numParts-1] [0..-1] real;
    var frontier: [0..pg.numParts-1] [0..-1] bool;
    var nextFrontier: [0..pg.numParts-1] [0..-1] bool;

    for p in 0..pg.numParts-1 {
      const nv = pg.numLocalVertices(p);
      localDom[p] = {0..nv-1};
      localDist[p] = [i in localDom[p]] -1;
      localSigma[p] = [i in localDom[p]] 0:int(64);
      localDelta[p] = [i in localDom[p]] 0.0;
      frontier[p] = [i in localDom[p]] false;
      nextFrontier[p] = [i in localDom[p]] false;
    }

    // Forward BFS локально по partition-состоянию (без промежуточного глобального массива).
    const sp = pg.ownerOfVertex(source);
    const sLi = pg.localIndexOfVertex(source);
    localDist[sp][sLi] = 0;
    localSigma[sp][sLi] = 1:int(64);
    frontier[sp][sLi] = true;

    var level = 0;
    var maxDist = 0;
    var msg = new PartitionedMessages(pg.numParts);

    while true {
      var hasWork = false;
      for p in 0..pg.numParts-1 {
        for li in localDom[p] {
          if frontier[p][li] {
            hasWork = true;
            break;
          }
        }
        if hasWork then break;
      }
      if !hasWork then break;

      msg.clearAll();
      for p in 0..pg.numParts-1 do
        for li in localDom[p] do
          nextFrontier[p][li] = false;

      for p in 0..pg.numParts-1 {
        for li in localDom[p] {
          if !frontier[p][li] then
            continue;

          const v = pg.globalVertexOf(p, li);
          const sigV = localSigma[p][li];

          for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[edgeIdx];
            const wp = pg.ownerOfVertex(w);

            if wp == p {
              const wLi = pg.localIndexOfVertex(w);
              if localDist[p][wLi] < 0 {
                localDist[p][wLi] = level + 1;
                localSigma[p][wLi] = sigV;
                nextFrontier[p][wLi] = true;
                if level + 1 > maxDist then
                  maxDist = level + 1;
              } else if localDist[p][wLi] == level + 1 {
                localSigma[p][wLi] += sigV;
              }
            } else {
              msg.appendRelax(wp, w, level + 1, sigV);
            }
          }
        }
      }

      for p in 0..pg.numParts-1 {
        for m in msg.relaxMessages(p) {
          const wLi = pg.localIndexOfVertex(m.targetVertex);
          if localDist[p][wLi] < 0 {
            localDist[p][wLi] = m.distance;
            localSigma[p][wLi] = m.sigmaContribution;
            nextFrontier[p][wLi] = true;
            if m.distance > maxDist then
              maxDist = m.distance;
          } else if localDist[p][wLi] == m.distance {
            localSigma[p][wLi] += m.sigmaContribution;
          }
        }
      }

      for p in 0..pg.numParts-1 do
        for li in localDom[p] do
          frontier[p][li] = nextFrontier[p][li];

      level += 1;
    }

    // Уровни в обратном порядке: maxDist..1 (source имеет dist=0).
    for level in maxDist..1 by -1 {
      msg.clearAll();

      // 1) Формируем вклады от w на уровень level к его предшественникам v.
      for p in 0..pg.numParts-1 {
        for wLi in localDom[p] {
          if localDist[p][wLi] != level then
            continue;

          const w = pg.globalVertexOf(p, wLi);
          const sigmaW = localSigma[p][wLi];

          if sigmaW == 0 then
            continue;

          const factor = (1.0 + localDelta[p][wLi]) / sigmaW:real;

          for edgeIdx in g.rowPtr[w]..g.rowPtr[w+1]-1 {
            const v = g.colIdx[edgeIdx];
            const vp = pg.ownerOfVertex(v);
            const vLi = pg.localIndexOfVertex(v);

            if localDist[vp][vLi] == level - 1 {
              const contrib = localSigma[vp][vLi]:real * factor;

              if vp == p {
                localDelta[p][vLi] += contrib;
              } else {
                msg.appendDependency(vp, v, contrib);
              }
            }
          }
        }
      }

      // 2) Применяем межpart dependency-сообщения у владельца вершины.
      for p in 0..pg.numParts-1 {
        for m in msg.dependencyMessages(p) {
          const vLi = pg.localIndexOfVertex(m.targetVertex);
          localDelta[p][vLi] += m.contribution;
        }
      }
    }

    // Собираем вклад одного источника как BC-like contribution: delta[w] для w != source.
    var contrib: [0..n-1] real;
    contrib = 0.0;
    for p in 0..pg.numParts-1 {
      for li in localDom[p] {
        const v = pg.globalVertexOf(p, li);
        if v != source then
          contrib[v] = localDelta[p][li];
      }
    }

    return contrib;
  }

  proc computePartitionedBrandesBCReal(ref g: CSRGraph,
                                       numParts: int): [0..g.n-1] real {
    var pg = buildPartitionedGraph(g, numParts);

    const n = g.n;
    var bc: [0..n-1] real;
    bc = 0.0;

    // Для каждого источника считаем вклад partitioned single-source и аккумулируем.
    for s in 0..n-1 {
      var contrib = computePartitionedSingleSourceDependencies(g, pg, s);

      // Обновляем BC только у owner-part через ownerOfVertex,
      // но пишем в глобальный массив (удобно для сравнения/отчёта).
      for v in 0..n-1 {
        if v != s {
          // Обновление результирующего глобального массива.
          bc[v] += contrib[v];
        }
      }
    }

    // Поправка для неориентированного графа.
    for v in 0..n-1 do
      bc[v] /= 2.0;

    return bc;
  }


}
