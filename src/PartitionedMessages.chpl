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
}
