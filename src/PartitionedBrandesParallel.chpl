module PartitionedBrandesParallel {
  use Time;
  use GraphCSR;
  use PartitionedGraph;
  use PartitionedState;
  use PartitionedMessages;

  record PartitionedParallelRunMetrics {
    var relaxMessagesSent: int(64) = 0;
    var dependencyMessagesSent: int(64) = 0;
    var cutEdgeTraversals: int(64) = 0;
    var bfsLevelsProcessed: int(64) = 0;
    var backwardLevelsProcessed: int(64) = 0;
    var forwardBfsSec: real = 0.0;
    var backwardSec: real = 0.0;
    var messageSec: real = 0.0;
    var gatherSec: real = 0.0;
  }

  var _lastParallelMetrics: PartitionedParallelRunMetrics;

  proc getLastPartitionedParallelRunMetrics(): PartitionedParallelRunMetrics {
    return _lastParallelMetrics;
  }

  proc computePartitionedBrandesBCParallelReal(const ref g: CSRGraph,
                                               numParts: int): [0..g.n-1] real {
    var pg = buildPartitionedGraph(g, numParts);
    const n = g.n;
    var metrics: PartitionedParallelRunMetrics;

    var bcLocal: PartitionedSourceState;
    bcLocal.initFromPartitionedGraph(pg);
    for p in 0..pg.numParts-1 do
      bcLocal.parts[p].reset();

    proc accumulateOneSource(const ref g: CSRGraph, ref pg: PartitionedGraph,
                             source: int, ref bcLocal: PartitionedSourceState,
                             ref metrics: PartitionedParallelRunMetrics) {
      var st: PartitionedSourceState;
      st.initFromPartitionedGraph(pg);
      st.resetForSource(source);

      var msg = new PartitionedMessagesParallel(pg.numParts);
      var level = 0;
      var maxDist = 0;

      const forwardStart = timeSinceEpoch().totalSeconds();
      while true {
        var hasWork = false;
        for p in 0..pg.numParts-1 {
          for li in st.parts[p].localDom {
            if st.getFrontierLocal(p, li) {
              hasWork = true;
              break;
            }
          }
          if hasWork then break;
        }
        if !hasWork then break;

        msg.clearAll();
        for p in 0..pg.numParts-1 do
          for li in st.parts[p].localDom do
            st.setNextFrontierLocal(p, li, false);

        var relaxSentByPart: [0..pg.numParts-1] int(64);
        relaxSentByPart = 0:int(64);
        var cutByPart: [0..pg.numParts-1] int(64);
        cutByPart = 0:int(64);

        coforall p in 0..pg.numParts-1 with (ref st, ref msg, ref relaxSentByPart, ref cutByPart) {
          for li in st.parts[p].localDom {
            if !st.getFrontierLocal(p, li) then continue;
            const v = pg.firstVertexOfPart(p) + li;
            const sigV = st.getSigmaLocal(p, li);

            for edgeIdx in g.rowPtr[v]..g.rowPtr[v+1]-1 {
              const w = g.colIdx[edgeIdx];
              const wp = pg.ownerOfVertex(w);
              if wp == p {
                const wLi = pg.localIndexOfVertex(w);
                if st.getDistLocal(p, wLi) < 0 {
                  st.setDistLocal(p, wLi, level + 1);
                  st.setSigmaLocal(p, wLi, sigV);
                  st.setNextFrontierLocal(p, wLi, true);
                } else if st.getDistLocal(p, wLi) == level + 1 {
                  st.addSigmaLocal(p, wLi, sigV);
                }
              } else {
                msg.appendRelax(p, wp, w, level + 1, sigV);
                relaxSentByPart[p] += 1;
                cutByPart[p] += 1;
              }
            }
          }
        }

        for p in 0..pg.numParts-1 {
          metrics.relaxMessagesSent += relaxSentByPart[p];
          metrics.cutEdgeTraversals += cutByPart[p];
        }

        const msgStartForward = timeSinceEpoch().totalSeconds();
        for dst in 0..pg.numParts-1 {
          for m in msg.relaxMessagesTo(dst) {
            const wLi = pg.localIndexOfVertex(m.targetVertex);
            if st.getDistLocal(dst, wLi) < 0 {
              st.setDistLocal(dst, wLi, m.distance);
              st.setSigmaLocal(dst, wLi, m.sigmaContribution);
              st.setNextFrontierLocal(dst, wLi, true);
            } else if st.getDistLocal(dst, wLi) == m.distance {
              st.addSigmaLocal(dst, wLi, m.sigmaContribution);
            }
          }
        }
        metrics.messageSec += timeSinceEpoch().totalSeconds() - msgStartForward;
        metrics.bfsLevelsProcessed += 1;

        // Обновляем maxDist после завершения параллельного уровня.
        for p in 0..pg.numParts-1 do
          for li in st.parts[p].localDom do
            if st.getNextFrontierLocal(p, li) {
              const d = st.getDistLocal(p, li);
              if d > maxDist then
                maxDist = d;
            }

        st.swapOrMoveNextFrontierToFrontier();
        level += 1;
      }
      metrics.forwardBfsSec += timeSinceEpoch().totalSeconds() - forwardStart;

      const backwardStart = timeSinceEpoch().totalSeconds();
      for level in 1..maxDist by -1 {
        msg.clearAll();

        var depSentByPart: [0..pg.numParts-1] int(64);
        depSentByPart = 0:int(64);

        coforall p in 0..pg.numParts-1 with (ref st, ref msg, ref depSentByPart) {
          for wLi in st.parts[p].localDom {
            if st.getDistLocal(p, wLi) != level then continue;
            const w = pg.firstVertexOfPart(p) + wLi;
            const sigmaW = st.getSigmaLocal(p, wLi);
            if sigmaW == 0 then continue;

            const factor = (1.0 + st.getDeltaLocal(p, wLi)) / sigmaW:real;
            for edgeIdx in g.rowPtr[w]..g.rowPtr[w+1]-1 {
              const v = g.colIdx[edgeIdx];
              const vp = pg.ownerOfVertex(v);
              const vLi = pg.localIndexOfVertex(v);
              if st.getDistLocal(vp, vLi) == level - 1 {
                const contrib = st.getSigmaLocal(vp, vLi):real * factor;
                if vp == p {
                  st.addDeltaLocal(p, vLi, contrib);
                } else {
                  msg.appendDependency(p, vp, v, contrib);
                  depSentByPart[p] += 1;
                }
              }
            }
          }
        }

        for p in 0..pg.numParts-1 do
          metrics.dependencyMessagesSent += depSentByPart[p];

        const msgStartBackward = timeSinceEpoch().totalSeconds();
        for dst in 0..pg.numParts-1 {
          for m in msg.dependencyMessagesTo(dst) {
            const vLi = pg.localIndexOfVertex(m.targetVertex);
            st.addDeltaLocal(dst, vLi, m.contribution);
          }
        }
        metrics.messageSec += timeSinceEpoch().totalSeconds() - msgStartBackward;
        metrics.backwardLevelsProcessed += 1;
      }
      metrics.backwardSec += timeSinceEpoch().totalSeconds() - backwardStart;

      for p in 0..pg.numParts-1 {
        for li in bcLocal.parts[p].localDom {
          const v = bcLocal.firstV[p] + li;
          if v != source then
            bcLocal.parts[p].delta[li] += st.getDeltaLocal(p, li);
        }
      }
    }

    for s in 0..n-1 do
      accumulateOneSource(g, pg, s, bcLocal, metrics);

    const gatherStart = timeSinceEpoch().totalSeconds();
    var bc = bcLocal.gatherDelta();
    metrics.gatherSec = timeSinceEpoch().totalSeconds() - gatherStart;
    for v in 0..n-1 do bc[v] /= 2.0;
    _lastParallelMetrics = metrics;
    return bc;
  }
}
