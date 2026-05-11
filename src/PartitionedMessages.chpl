/*
  PartitionedMessages.chpl
  Простейшая инфраструктура message buffers для
  Partitioned Message-Passing Brandes (single-process simulation).
*/
module PartitionedMessages {
  use List;

  record RelaxMessage {
    var targetVertex: int;
    var distance: int;
    var sigmaContribution: int(64);
  }

  record DependencyMessage {
    var targetVertex: int;
    var contribution: real;
  }

  record PartMessageBuffer {
    // В этом буфере хранятся сообщения, адресованные конкретной part.
    var relaxMsgs: list(RelaxMessage);
    var depMsgs: list(DependencyMessage);

    proc ref clear() {
      relaxMsgs.clear();
      depMsgs.clear();
    }

    proc ref appendRelax(msg: RelaxMessage) {
      relaxMsgs.pushBack(msg);
    }

    proc ref appendDependency(msg: DependencyMessage) {
      depMsgs.pushBack(msg);
    }

    proc numRelax(): int {
      return relaxMsgs.size;
    }

    proc numDependency(): int {
      return depMsgs.size;
    }
  }

  record PartitionedMessages {
    var numParts: int;

    var partDom: domain(1) = {0..-1};
    var buffers: [partDom] PartMessageBuffer;

    proc init(numParts: int) {
      this.numParts = numParts;
      this.partDom = {0..numParts-1};
    }

    proc ref clearAll() {
      for p in partDom do
        buffers[p].clear();
    }

    proc ref appendRelax(destPart: int, targetVertex: int, distance: int,
                         sigmaContribution: int(64)) {
      if destPart < 0 || destPart >= numParts then
        halt("appendRelax: destPart out of range: ", destPart);

      var msg: RelaxMessage;
      msg.targetVertex = targetVertex;
      msg.distance = distance;
      msg.sigmaContribution = sigmaContribution;
      buffers[destPart].appendRelax(msg);
    }

    proc ref appendDependency(destPart: int, targetVertex: int, contribution: real) {
      if destPart < 0 || destPart >= numParts then
        halt("appendDependency: destPart out of range: ", destPart);

      var msg: DependencyMessage;
      msg.targetVertex = targetVertex;
      msg.contribution = contribution;
      buffers[destPart].appendDependency(msg);
    }

    proc numRelax(part: int): int {
      if part < 0 || part >= numParts then
        halt("numRelax: part out of range: ", part);
      return buffers[part].numRelax();
    }

    proc numDependency(part: int): int {
      if part < 0 || part >= numParts then
        halt("numDependency: part out of range: ", part);
      return buffers[part].numDependency();
    }

    // Для итерации по relax-сообщениям части.
    iter relaxMessages(part: int) {
      if part < 0 || part >= numParts then
        halt("relaxMessages: part out of range: ", part);

      for m in buffers[part].relaxMsgs do
        yield m;
    }

    // Для итерации по dependency-сообщениям части.
    iter dependencyMessages(part: int) {
      if part < 0 || part >= numParts then
        halt("dependencyMessages: part out of range: ", part);

      for m in buffers[part].depMsgs do
        yield m;
    }
  }

  // 2D буферы для parallel partition execution:
  // row = fromPart (single writer), col = toPart.
  record PartitionedMessagesParallel {
    var numParts: int;
    var partDom: domain(1) = {0..-1};
    var matrixDom: domain(2) = {0..-1, 0..-1};
    var relaxOut: [matrixDom] PartMessageBuffer;
    var depOut: [matrixDom] PartMessageBuffer;

    proc init(numParts: int) {
      this.numParts = numParts;
      this.partDom = {0..numParts-1};
      this.matrixDom = {0..numParts-1, 0..numParts-1};
    }

    proc ref clearAll() {
      for src in partDom do
        for dst in partDom {
          relaxOut[src, dst].clear();
          depOut[src, dst].clear();
        }
    }

    proc ref appendRelax(fromPart: int, toPart: int,
                         targetVertex: int, distance: int,
                         sigmaContribution: int(64)) {
      if fromPart < 0 || fromPart >= numParts then
        halt("appendRelax(par): fromPart out of range: ", fromPart);
      if toPart < 0 || toPart >= numParts then
        halt("appendRelax(par): toPart out of range: ", toPart);

      var msg: RelaxMessage;
      msg.targetVertex = targetVertex;
      msg.distance = distance;
      msg.sigmaContribution = sigmaContribution;
      relaxOut[fromPart, toPart].appendRelax(msg);
    }

    proc ref appendDependency(fromPart: int, toPart: int,
                              targetVertex: int, contribution: real) {
      if fromPart < 0 || fromPart >= numParts then
        halt("appendDependency(par): fromPart out of range: ", fromPart);
      if toPart < 0 || toPart >= numParts then
        halt("appendDependency(par): toPart out of range: ", toPart);

      var msg: DependencyMessage;
      msg.targetVertex = targetVertex;
      msg.contribution = contribution;
      depOut[fromPart, toPart].appendDependency(msg);
    }

    proc numRelax(fromPart: int, toPart: int): int {
      return relaxOut[fromPart, toPart].numRelax();
    }

    proc numDependency(fromPart: int, toPart: int): int {
      return depOut[fromPart, toPart].numDependency();
    }

    iter relaxMessagesFromTo(fromPart: int, toPart: int) {
      if fromPart < 0 || fromPart >= numParts then
        halt("relaxMessagesFromTo: fromPart out of range: ", fromPart);
      if toPart < 0 || toPart >= numParts then
        halt("relaxMessagesFromTo: toPart out of range: ", toPart);

      for m in relaxOut[fromPart, toPart].relaxMsgs do
        yield m;
    }

    iter dependencyMessagesFromTo(fromPart: int, toPart: int) {
      if fromPart < 0 || fromPart >= numParts then
        halt("dependencyMessagesFromTo: fromPart out of range: ", fromPart);
      if toPart < 0 || toPart >= numParts then
        halt("dependencyMessagesFromTo: toPart out of range: ", toPart);

      for m in depOut[fromPart, toPart].depMsgs do
        yield m;
    }

    iter relaxMessagesTo(dstPart: int) {
      if dstPart < 0 || dstPart >= numParts then
        halt("relaxMessagesTo: dstPart out of range: ", dstPart);
      for src in partDom do
        for m in relaxOut[src, dstPart].relaxMsgs do
          yield m;
    }

    iter dependencyMessagesTo(dstPart: int) {
      if dstPart < 0 || dstPart >= numParts then
        halt("dependencyMessagesTo: dstPart out of range: ", dstPart);
      for src in partDom do
        for m in depOut[src, dstPart].depMsgs do
          yield m;
    }
  }
}
