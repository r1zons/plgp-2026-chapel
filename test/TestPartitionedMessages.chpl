/*
  Unit-тесты для PartitionedMessages.
*/
module TestPartitionedMessages {
  use PartitionedMessages;

  private proc testAppendAndDestination() {
    var pm = new PartitionedMessages(3);

    pm.appendRelax(0, 10, 1, 5:int(64));
    pm.appendRelax(2, 20, 2, 7:int(64));
    pm.appendDependency(1, 30, 0.75);
    pm.appendDependency(2, 40, 1.25);

    assert(pm.numRelax(0) == 1);
    assert(pm.numRelax(1) == 0);
    assert(pm.numRelax(2) == 1);

    assert(pm.numDependency(0) == 0);
    assert(pm.numDependency(1) == 1);
    assert(pm.numDependency(2) == 1);

    // Проверяем, что сообщения лежат в ожидаемой part.
    var seenR0 = false;
    for m in pm.relaxMessages(0) {
      seenR0 = true;
      assert(m.targetVertex == 10);
      assert(m.distance == 1);
      assert(m.sigmaContribution == 5:int(64));
    }
    assert(seenR0);

    var seenR2 = false;
    for m in pm.relaxMessages(2) {
      seenR2 = true;
      assert(m.targetVertex == 20);
      assert(m.distance == 2);
      assert(m.sigmaContribution == 7:int(64));
    }
    assert(seenR2);

    var seenD1 = false;
    for m in pm.dependencyMessages(1) {
      seenD1 = true;
      assert(m.targetVertex == 30);
      assert(m.contribution == 0.75);
    }
    assert(seenD1);

    var seenD2 = false;
    for m in pm.dependencyMessages(2) {
      seenD2 = true;
      assert(m.targetVertex == 40);
      assert(m.contribution == 1.25);
    }
    assert(seenD2);
  }

  private proc testClearBuffers() {
    var pm = new PartitionedMessages(2);

    pm.appendRelax(0, 1, 0, 1:int(64));
    pm.appendDependency(1, 2, 3.5);

    assert(pm.numRelax(0) == 1);
    assert(pm.numDependency(1) == 1);

    pm.clearAll();

    assert(pm.numRelax(0) == 0);
    assert(pm.numRelax(1) == 0);
    assert(pm.numDependency(0) == 0);
    assert(pm.numDependency(1) == 0);

    // Итерация по пустому буферу безопасна.
    var count = 0;
    for _ in pm.relaxMessages(0) do
      count += 1;
    assert(count == 0);
  }

  proc main() {
    testAppendAndDestination();
    testClearBuffers();

    writeln("TestPartitionedMessages: PASS");
  }
}
