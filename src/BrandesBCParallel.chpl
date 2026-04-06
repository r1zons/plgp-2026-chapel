/*
  BrandesBCParallel.chpl
  Параллельная версия Brandes для невзвешенного неориентированного CSR-графа.

  Подход:
    - источники (s) делятся на равные блоки;
    - каждый блок обрабатывается отдельной задачей coforall;
    - локальные суммы BC по задаче сливаются в общий массив под lock.

  Почему coforall, а не forall:
    - coforall явно создаёт независимые задачи по блокам источников,
      что упрощает контроль локальных временных структур на задачу;
    - в этом режиме нагляднее и безопаснее реализуется контролируемое слияние
      частичных результатов (локальный bc -> глобальный bc).
*/
module BrandesBCParallel {
  use GraphCSR;

  proc computeBrandesBCParallelReal(ref g: CSRGraph, requestedTasks: int = 0): [0..g.n-1] real {
    const n = g.n;
    var bc: [0..n-1] real;
    bc = 0.0;

    if n == 0 then
      return bc;

    // Число задач: либо явно задано, либо по текущей доступной параллельности.
    var numTasks = if requestedTasks > 0 then requestedTasks else here.maxTaskPar;
    if numTasks < 1 then numTasks = 1;
    if numTasks > n then numTasks = n;

    const blockSize = (n + numTasks - 1) / numTasks;

    // Простейшая блокировка на время слияния локального результата.
    var mergeLock: sync bool = true;

    coforall tid in 0..numTasks-1 {
      const startS = tid * blockSize;
      const endS = min(n-1, startS + blockSize - 1);

      if startS <= endS {
        // Локальные для задачи накопители и временные массивы.
        var localBC: [0..n-1] real;
      localBC = 0.0;

      var dist: [0..n-1] int;
      var sigma: [0..n-1] int(64);
      var delta: [0..n-1] real;
      var queue: [0..n-1] int;
      var stack: [0..n-1] int;

      for s in startS..endS {
        dist = -1;
        sigma = 0:int(64);
        delta = 0.0;

        var head = 0;
        var tail = 0;
        var stackSize = 0;

        dist[s] = 0;
        sigma[s] = 1;
        queue[tail] = s;
        tail += 1;

        while head < tail {
          const v = queue[head];
          head += 1;

          stack[stackSize] = v;
          stackSize += 1;

          for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
            const w = g.colIdx[p];

            if dist[w] < 0 {
              dist[w] = dist[v] + 1;
              queue[tail] = w;
              tail += 1;
            }

            if dist[w] == dist[v] + 1 {
              sigma[w] += sigma[v];
            }
          }
        }

        var idx = stackSize - 1;
        while idx >= 0 {
          const w = stack[idx];

          for p in g.rowPtr[w]..g.rowPtr[w+1]-1 {
            const v = g.colIdx[p];
            if dist[v] == dist[w] - 1 {
              delta[v] += (sigma[v]:real / sigma[w]:real) * (1.0 + delta[w]);
            }
          }

          if w != s {
            localBC[w] += delta[w];
          }

          idx -= 1;
        }
      }

      // Контролируемое слияние локального результата в общий.
        mergeLock.readFE();
        for v in 0..n-1 do
          bc[v] += localBC[v];
        mergeLock.writeEF(true);
      }
    }

    // Поправка для неориентированного графа.
    for v in 0..n-1 do
      bc[v] /= 2.0;

    return bc;
  }
}
