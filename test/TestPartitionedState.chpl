module TestPartitionedState {
  use GraphCSR;
  use PartitionedGraph;
  use PartitionedState;

  proc main() {
    var g = makeCompleteGraph(7);
    var pg = buildPartitionedGraph(g, 3);

    var st: PartitionedSourceState;
    st.initFromPartitionedGraph(pg);

    // 1) local sizes must match partition sizes
    for p in 0..pg.numParts-1 do
      assert(st.parts[p].size() == pg.numLocalVertices(p));

    // 2) set/get via global ids
    st.setDist(0, 10);
    st.setSigma(1, 3:int(64));
    st.addSigma(1, 4:int(64));
    st.setDelta(6, 1.5);
    st.addDelta(6, 0.5);
    st.setFrontier(2, true);
    st.setNextFrontier(5, true);

    assert(st.getDist(0) == 10);
    assert(st.getSigma(1) == 7:int(64));
    assert(abs(st.getDelta(6) - 2.0) <= 1.0e-12);
    assert(st.getFrontier(2));
    assert(st.getNextFrontier(5));

    // 3) mapping checks
    assert(st.ownerOfVertex(0) == 0);
    assert(st.ownerOfVertex(2) == 0);
    assert(st.ownerOfVertex(3) == 1);
    assert(st.ownerOfVertex(5) == 2);
    assert(st.localIndexOfVertex(0) == 0);
    assert(st.localIndexOfVertex(3) == 0);
    assert(st.localIndexOfVertex(6) == 0);

    // 4) frontier move/clear
    st.swapOrMoveNextFrontierToFrontier();
    assert(!st.getFrontier(2));
    assert(st.getFrontier(5));
    assert(!st.getNextFrontier(5));

    st.clearFrontiers();
    for v in 0..6 {
      assert(!st.getFrontier(v));
      assert(!st.getNextFrontier(v));
    }

    // 5) reset for source
    st.resetForSource(4);
    for v in 0..6 {
      if v == 4 {
        assert(st.getDist(v) == 0);
        assert(st.getSigma(v) == 1:int(64));
        assert(st.getFrontier(v));
      } else {
        assert(st.getDist(v) == -1);
        assert(st.getSigma(v) == 0:int(64));
        assert(abs(st.getDelta(v)) <= 1.0e-12);
        assert(!st.getFrontier(v));
      }
      assert(!st.getNextFrontier(v));
    }

    // 6) gather helpers
    st.setDist(0, 11);
    st.setSigma(6, 9:int(64));
    st.setDelta(1, 2.25);

    const gd = st.gatherDist();
    const gs = st.gatherSigma();
    const gdel = st.gatherDelta();

    assert(gd[0] == 11);
    assert(gs[6] == 9:int(64));
    assert(abs(gdel[1] - 2.25) <= 1.0e-12);

    writeln("TestPartitionedState: PASS");
  }
}
