/*
  PartitionedMessages.chpl
  Простейшая инфраструктура message buffers для
  Partitioned Message-Passing Brandes (single-process simulation).
*/
module PartitionedMessages {

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
    var relaxDom: domain(1) = {0..-1};
    var relaxMsgs: [relaxDom] RelaxMessage;

    var depDom: domain(1) = {0..-1};
    var depMsgs: [depDom] DependencyMessage;

    proc ref clear() {
      relaxDom = {0..-1};
      depDom = {0..-1};
    }

    proc ref appendRelax(msg: RelaxMessage) {
      const next = if relaxDom.size == 0 then 0 else relaxDom.high + 1;
      relaxDom = {0..next};
      relaxMsgs[next] = msg;
    }

    proc ref appendDependency(msg: DependencyMessage) {
      const next = if depDom.size == 0 then 0 else depDom.high + 1;
      depDom = {0..next};
      depMsgs[next] = msg;
    }

    proc numRelax(): int {
      return relaxDom.size;
    }

    proc numDependency(): int {
      return depDom.size;
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
    iter ref relaxMessages(part: int) ref {
      if part < 0 || part >= numParts then
        halt("relaxMessages: part out of range: ", part);

      for i in buffers[part].relaxDom do
        yield buffers[part].relaxMsgs[i];
    }

    // Для итерации по dependency-сообщениям части.
    iter ref dependencyMessages(part: int) ref {
      if part < 0 || part >= numParts then
        halt("dependencyMessages: part out of range: ", part);

      for i in buffers[part].depDom do
        yield buffers[part].depMsgs[i];
    }
  }
}
