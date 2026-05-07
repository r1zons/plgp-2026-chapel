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
    // Single-process simulated message passing:
    // working state is partition-local via PartitionedSourceState.
    var st: PartitionedSourceState;
    st.initFromPartitionedGraph(pg);
    st.resetForSource(source);

    // Forward BFS по partition-состоянию.

    var level = 0;
    var maxDist = 0;
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
                if level + 1 > maxDist then
                  maxDist = level + 1;
              } else if st.getDist(w) == level + 1 {
                st.addSigma(w, sigV);
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
          if st.getDist(w) < 0 {
            st.setDist(w, m.distance);
            st.setSigma(w, m.sigmaContribution);
            st.setNextFrontier(w, true);
            if m.distance > maxDist then
              maxDist = m.distance;
          } else if st.getDist(w) == m.distance {
            st.addSigma(w, m.sigmaContribution);
          }
        }
      }

      st.swapOrMoveNextFrontierToFrontier();

      level += 1;
    }

    // Chapel countdown idiom: use 1..maxDist by -1 (not maxDist..1 by -1).
    // Source has dist=0, so backward dependency levels are maxDist..1.
    for level in 1..maxDist by -1 {
      msg.clearAll();

      // 1) Формируем вклады от w на уровень level к его предшественникам v.
      for p in 0..pg.numParts-1 {
        for w in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
          if st.getDist(w) != level then
            continue;
          const sigmaW = st.getSigma(w);

          if sigmaW == 0 then
            continue;

          const factor = (1.0 + st.getDelta(w)) / sigmaW:real;

          for edgeIdx in g.rowPtr[w]..g.rowPtr[w+1]-1 {
            const v = g.colIdx[edgeIdx];
            const vp = pg.ownerOfVertex(v);
            if st.getDist(v) == level - 1 {
              const contrib = st.getSigma(v):real * factor;

              if vp == p {
                st.addDelta(v, contrib);
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
          st.addDelta(v, m.contribution);
        }
      }
    }

    // Собираем вклад одного источника как BC-like contribution: delta[w] для w != source.
    var contrib = st.gatherDelta();
    contrib[source] = 0.0;

    return contrib;
  }

  proc computePartitionedBrandesBCReal(ref g: CSRGraph,
                                       numParts: int): [0..g.n-1] real {
    var pg = buildPartitionedGraph(g, numParts);

    const n = g.n;
    // Per-part local BC accumulation (stored in partition-local delta arrays).
    var bcLocal: PartitionedSourceState;
    bcLocal.initFromPartitionedGraph(pg);
    for p in 0..pg.numParts-1 do
      bcLocal.parts[p].reset();

    proc accumulateOneSource(ref g: CSRGraph, ref pg: PartitionedGraph,
                             source: int, ref bcLocal: PartitionedSourceState) {
      var st: PartitionedSourceState;
      st.initFromPartitionedGraph(pg);
      st.resetForSource(source);

      var level = 0;
      var maxDist = 0;
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
                  if level + 1 > maxDist then
                    maxDist = level + 1;
                } else if st.getDist(w) == level + 1 {
                  st.addSigma(w, sigV);
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
            if st.getDist(w) < 0 {
              st.setDist(w, m.distance);
              st.setSigma(w, m.sigmaContribution);
              st.setNextFrontier(w, true);
              if m.distance > maxDist then
                maxDist = m.distance;
            } else if st.getDist(w) == m.distance {
              st.addSigma(w, m.sigmaContribution);
            }
          }
        }
        st.swapOrMoveNextFrontierToFrontier();
        level += 1;
      }

      for level in 1..maxDist by -1 {
        msg.clearAll();
        for p in 0..pg.numParts-1 {
          for w in pg.firstVertexOfPart(p)..pg.lastVertexOfPart(p) {
            if st.getDist(w) != level then
              continue;
            const sigmaW = st.getSigma(w);
            if sigmaW == 0 then
              continue;
            const factor = (1.0 + st.getDelta(w)) / sigmaW:real;

            for edgeIdx in g.rowPtr[w]..g.rowPtr[w+1]-1 {
              const v = g.colIdx[edgeIdx];
              const vp = pg.ownerOfVertex(v);
              if st.getDist(v) == level - 1 {
                const contrib = st.getSigma(v):real * factor;
                if vp == p {
                  st.addDelta(v, contrib);
                } else {
                  msg.appendDependency(vp, v, contrib);
                }
              }
            }
          }
        }
        for p in 0..pg.numParts-1 {
          for m in msg.dependencyMessages(p) do
            st.addDelta(m.targetVertex, m.contribution);
        }
      }

      // Accumulate into per-part local BC storage.
      for p in 0..pg.numParts-1 {
        for li in bcLocal.parts[p].localDom {
          const v = bcLocal.firstV[p] + li;
          if v != source then
            bcLocal.parts[p].delta[li] += st.getDelta(v);
        }
      }
    }

    var bc: [0..n-1] real;
    bc = 0.0;

    for s in 0..n-1 {
      accumulateOneSource(g, pg, s, bcLocal);
    }

    // Gather global BC once at the end from partition-local storage.
    bc = bcLocal.gatherDelta();

    // Поправка для неориентированного графа.
    for v in 0..n-1 do
      bc[v] /= 2.0;

    return bc;
  }


}
