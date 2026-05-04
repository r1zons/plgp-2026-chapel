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

    // Состояние на вершину (robust для Chapel rectangular arrays).
    var dist: [0..n-1] int = -1;
    var sigma: [0..n-1] int(64) = 0:int(64);
    var frontier: [0..n-1] bool = false;
    var nextFrontier: [0..n-1] bool = false;

    dist[source] = 0;
    sigma[source] = 1:int(64);
    frontier[source] = true;

    var level = 0;
    var msg = new PartitionedMessages(pg.numParts);

    while true {
      var hasWork = false;
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if frontier[v] {
            hasWork = true;
            break;
          }
        }
        if hasWork then break;
      }
      if !hasWork then break;

      msg.clearAll();
      nextFrontier = false;

      // 1) Локальная обработка frontier и отправка межpart RELAX сообщений.
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if !frontier[v] then
            continue;
          const sigV = sigma[v];

          for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[edgeIdx];
            const wp = pg.ownerOfVertex(w);

            if wp == p {
              if dist[w] < 0 {
                dist[w] = level + 1;
                sigma[w] = sigV;
                nextFrontier[w] = true;
              } else if dist[w] == level + 1 {
                sigma[w] += sigV;
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
          const w = m.targetVertex;
          if dist[w] < 0 {
            dist[w] = m.distance;
            sigma[w] = m.sigmaContribution;
            nextFrontier[w] = true;
          } else if dist[w] == m.distance {
            sigma[w] += m.sigmaContribution;
          }
        }
      }

      // 3) Переход на следующий BFS-уровень.
      frontier = nextFrontier;
      level += 1;
    }

    // Сборка глобальных dist/sigma для тестов.
    var res: SingleSourceBFSResult;
    res.vDom = {0..n-1};
    res.dist = [i in res.vDom] -1;
    res.sigma = [i in res.vDom] 0:int(64);

    for v in 0..n-1 {
      res.dist[v] = dist[v];
      res.sigma[v] = sigma[v];
    }

    return res;
  }

  proc computePartitionedSingleSourceDependencies(ref g: CSRGraph,
                                                  ref pg: PartitionedGraph,
                                                  source: int): [0..g.n-1] real {
    const n = g.n;
    var dist: [0..n-1] int = -1;
    var sigma: [0..n-1] int(64) = 0:int(64);
    var delta: [0..n-1] real = 0.0;
    var frontier: [0..n-1] bool = false;
    var nextFrontier: [0..n-1] bool = false;

    // Forward BFS локально по partition-состоянию (без промежуточного глобального массива).
    dist[source] = 0;
    sigma[source] = 1:int(64);
    frontier[source] = true;

    var level = 0;
    var maxDist = 0;
    var msg = new PartitionedMessages(pg.numParts);

    while true {
      var hasWork = false;
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if frontier[v] {
            hasWork = true;
            break;
          }
        }
        if hasWork then break;
      }
      if !hasWork then break;

      msg.clearAll();
      nextFrontier = false;

      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if !frontier[v] then
            continue;
          const sigV = sigma[v];

          for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[edgeIdx];
            const wp = pg.ownerOfVertex(w);

            if wp == p {
              if dist[w] < 0 {
                dist[w] = level + 1;
                sigma[w] = sigV;
                nextFrontier[w] = true;
                if level + 1 > maxDist then
                  maxDist = level + 1;
              } else if dist[w] == level + 1 {
                sigma[w] += sigV;
              }
            } else {
              msg.appendRelax(wp, w, level + 1, sigV);
            }
          }
        }
      }

      for p in 0..pg.numParts-1 {
        for m in msg.relaxMessages(p) {
          const w = m.targetVertex;
          if dist[w] < 0 {
            dist[w] = m.distance;
            sigma[w] = m.sigmaContribution;
            nextFrontier[w] = true;
            if m.distance > maxDist then
              maxDist = m.distance;
          } else if dist[w] == m.distance {
            sigma[w] += m.sigmaContribution;
          }
        }
      }

      frontier = nextFrontier;

      level += 1;
    }

    // Уровни в обратном порядке: maxDist..1 (source имеет dist=0).
    for level in maxDist..1 by -1 {
      msg.clearAll();

      // 1) Формируем вклады от w на уровень level к его предшественникам v.
      for p in 0..pg.numParts-1 {
        for w in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if dist[w] != level then
            continue;
          const sigmaW = sigma[w];

          if sigmaW == 0 then
            continue;

          const factor = (1.0 + delta[w]) / sigmaW:real;

          for edgeIdx in g.rowPtr[w]..g.rowPtr[w+1]-1 {
            const v = g.colIdx[edgeIdx];
            const vp = pg.ownerOfVertex(v);
            if dist[v] == level - 1 {
              const contrib = sigma[v]:real * factor;

              if vp == p {
                delta[v] += contrib;
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
          const v = m.targetVertex;
          delta[v] += m.contribution;
        }
      }
    }

    // Собираем вклад одного источника как BC-like contribution: delta[w] для w != source.
    var contrib: [0..n-1] real;
    contrib = 0.0;
    for v in 0..n-1 do
      if v != source then
        contrib[v] = delta[v];

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
