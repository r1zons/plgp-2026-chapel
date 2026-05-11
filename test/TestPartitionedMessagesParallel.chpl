module TestPartitionedMessagesParallel {
  use PartitionedMessages;

  proc main() {
    var pm = new PartitionedMessagesParallel(3);

    // RELAX: from 0->2, 1->2, 2->0
    pm.appendRelax(0, 2, 10, 1, 5:int(64));
    pm.appendRelax(1, 2, 11, 1, 7:int(64));
    pm.appendRelax(2, 0, 12, 2, 3:int(64));

    // Stored separately by (fromPart, toPart).
    assert(pm.numRelax(0, 2) == 1);
    assert(pm.numRelax(1, 2) == 1);
    assert(pm.numRelax(2, 0) == 1);
    assert(pm.numRelax(2, 2) == 0);

    var cnt02 = 0;
    for m in pm.relaxMessagesFromTo(0, 2) {
      cnt02 += 1;
      assert(m.targetVertex == 10);
      assert(m.distance == 1);
      assert(m.sigmaContribution == 5:int(64));
    }
    assert(cnt02 == 1);

    var cnt12 = 0;
    for m in pm.relaxMessagesFromTo(1, 2) {
      cnt12 += 1;
      assert(m.targetVertex == 11);
    }
    assert(cnt12 == 1);

    var cnt20 = 0;
    for m in pm.relaxMessagesFromTo(2, 0) {
      cnt20 += 1;
      assert(m.targetVertex == 12);
    }
    assert(cnt20 == 1);

    // Destination-style delivery: iterate all src for fixed dst=2.
    var relaxTo2 = 0;
    var seen10 = false, seen11 = false;
    for m in pm.relaxMessagesTo(2) {
      relaxTo2 += 1;
      if m.targetVertex == 10 then seen10 = true;
      if m.targetVertex == 11 then seen11 = true;
    }
    assert(relaxTo2 == 2);
    assert(seen10 && seen11);

    // DEPENDENCY messages with split by (from,to).
    pm.appendDependency(0, 1, 20, 0.5);
    pm.appendDependency(2, 1, 21, 1.25);
    pm.appendDependency(1, 0, 22, 2.0);

    assert(pm.numDependency(0, 1) == 1);
    assert(pm.numDependency(2, 1) == 1);
    assert(pm.numDependency(1, 0) == 1);

    var dep01 = 0;
    for m in pm.dependencyMessagesFromTo(0, 1) {
      dep01 += 1;
      assert(m.targetVertex == 20);
      assert(abs(m.contribution - 0.5) < 1.0e-12);
    }
    assert(dep01 == 1);

    var depTo1 = 0;
    var seen20 = false, seen21 = false;
    for m in pm.dependencyMessagesTo(1) {
      depTo1 += 1;
      if m.targetVertex == 20 then seen20 = true;
      if m.targetVertex == 21 then seen21 = true;
    }
    assert(depTo1 == 2);
    assert(seen20 && seen21);

    // clearAll resets both RELAX and DEP buffers.
    pm.clearAll();

    assert(pm.numRelax(0, 2) == 0);
    assert(pm.numRelax(1, 2) == 0);
    assert(pm.numRelax(2, 0) == 0);
    assert(pm.numDependency(0, 1) == 0);
    assert(pm.numDependency(2, 1) == 0);
    assert(pm.numDependency(1, 0) == 0);

    var emptyCount = 0;
    for m in pm.relaxMessagesTo(2) do
      emptyCount += 1;
    assert(emptyCount == 0);

    writeln("TestPartitionedMessagesParallel: PASS");
  }
}
