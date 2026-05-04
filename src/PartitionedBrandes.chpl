/*
  PartitionedBrandes.chpl
  Первый шаг Partitioned Message-Passing Brandes:
  только forward BFS-фаза для одного источника.
*/
module PartitionedBrandes {
  use GraphCSR;
  use PartitionedGraph;
  use PartitionedMessages;
  use PartitionedState;

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

    // Working-state хранится по partition через PartitionedSourceState.
    var st: PartitionedSourceState;
    st.initFromPartitionedGraph(pg);
    st.resetForSource(source);

    var level = 0;
    var msg = new PartitionedMessages(pg.numParts);

    while true {
      var hasWork = false;
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if st.getFrontier(v) {
            hasWork = true;
            break;
          }
        }
        if hasWork then break;
      }
      if !hasWork then break;

      msg.clearAll();
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) do
          st.setNextFrontier(v, false);
      }

      // 1) Локальная обработка frontier и отправка межpart RELAX сообщений.
      for p in 0..pg.numParts-1 {
        for v in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if !st.getFrontier(v) then
            continue;
          const sigV = st.getSigma(v);

          for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[edgeIdx];
            const wp = pg.ownerOfVertex(w);

            if wp == p {
              if st.getDist(w) < 0 {
                st.setDist(w, level + 1);
                st.setSigma(w, sigV);
                st.setNextFrontier(w, true);
              } else if st.getDist(w) == level + 1 {
                st.addSigma(w, sigV);
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
          if st.getDist(w) < 0 {
            st.setDist(w, m.distance);
            st.setSigma(w, m.sigmaContribution);
            st.setNextFrontier(w, true);
          } else if st.getDist(w) == m.distance {
            st.addSigma(w, m.sigmaContribution);
          }
        }
      }

      // 3) Переход на следующий BFS-уровень.
      st.swapOrMoveNextFrontierToFrontier();
      level += 1;
    }

    // Сборка глобальных dist/sigma для тестов.
    var res: SingleSourceBFSResult;
    res.vDom = {0..n-1};
    res.dist = st.gatherDist();
    res.sigma = st.gatherSigma();

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

    // Chapel countdown idiom: use 1..maxDist by -1 (not maxDist..1 by -1).
    // Source has dist=0, so backward dependency levels are maxDist..1.
    for level in 1..maxDist by -1 {
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
