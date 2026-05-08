module TestPartitionedMessagesParallel {
  use PartitionedMessages;

  proc main() {
    var pm = new PartitionedMessagesParallel(3);

    pm.appendRelax(0, 2, 10, 1, 5:int(64));
    pm.appendRelax(1, 2, 11, 1, 7:int(64));
    pm.appendRelax(2, 2, 12, 2, 3:int(64));

    pm.appendDependency(0, 1, 20, 0.5);
    pm.appendDependency(2, 1, 21, 1.25);

    assert(pm.numRelax(0, 2) == 1);
    assert(pm.numRelax(1, 2) == 1);
    assert(pm.numRelax(2, 2) == 1);
    assert(pm.numDependency(0, 1) == 1);
    assert(pm.numDependency(2, 1) == 1);

    var relaxCount = 0;
    var seen10 = false, seen11 = false, seen12 = false;
    for m in pm.relaxMessagesTo(2) {
      relaxCount += 1;
      if m.targetVertex == 10 then seen10 = true;
      if m.targetVertex == 11 then seen11 = true;
      if m.targetVertex == 12 then seen12 = true;
    }
    assert(relaxCount == 3);
    assert(seen10 && seen11 && seen12);

    var depCount = 0;
    var seen20 = false, seen21 = false;
    for m in pm.dependencyMessagesTo(1) {
      depCount += 1;
      if m.targetVertex == 20 then seen20 = true;
      if m.targetVertex == 21 then seen21 = true;
    }
    assert(depCount == 2);
    assert(seen20 && seen21);

    pm.clearAll();
    assert(pm.numRelax(0, 2) == 0);
    assert(pm.numRelax(1, 2) == 0);
    assert(pm.numDependency(0, 1) == 0);
    assert(pm.numDependency(2, 1) == 0);

    var emptyCount = 0;
    for m in pm.relaxMessagesTo(2) do
      emptyCount += 1;
    assert(emptyCount == 0);

    writeln("TestPartitionedMessagesParallel: PASS");
  }
}
