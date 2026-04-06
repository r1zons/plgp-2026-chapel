/*
  BrandesBC.chpl
  Последовательная реализация алгоритма Brandes для
  невзвешенного неориентированного графа в CSR.

  Для точности используем рациональное накопление (num/den).
  В модуле используются только целочисленные расстояния и счётчики путей.
*/
module BrandesBC {
  use GraphCSR;

  private proc absI64(x: int(64)): int(64) {
    if x < 0 then return -x;
    return x;
  }

  private proc gcdI64(a: int(64), b: int(64)): int(64) {
    var x = absI64(a);
    var y = absI64(b);

    if x == 0 && y == 0 then
      return 1;

    while y != 0 {
      const t = x % y;
      x = y;
      y = t;
    }

    if x == 0 then return 1;
    return x;
  }

  private proc reduceFraction(ref num: int(64), ref den: int(64)) {
    if den < 0 {
      num = -num;
      den = -den;
    }

    if num == 0 {
      den = 1;
      return;
    }

    const g = gcdI64(num, den);
    num /= g;
    den /= g;
  }

  private proc addFraction(ref accNum: int(64), ref accDen: int(64),
                           addNumIn: int(64), addDenIn: int(64)) {
    var addNum = addNumIn;
    var addDen = addDenIn;
    reduceFraction(addNum, addDen);

    if addNum == 0 then
      return;

    const g = gcdI64(accDen, addDen);
    const leftMul = addDen / g;
    const rightMul = accDen / g;

    var n = accNum * leftMul + addNum * rightMul;
    var d = accDen * leftMul;
    reduceFraction(n, d);
    accNum = n;
    accDen = d;
  }

  // Точный результат Brandes как рациональные значения по вершинам.
  proc computeBrandesBCExact(ref g: CSRGraph,
                             ref numOut: [] int(64),
                             ref denOut: [] int(64)) {
    const n = g.n;

    numOut = 0:int(64);
    denOut = 1:int(64);

    // Вспомогательные структуры на один источник s.
    var dist: [0..n-1] int;
    var sigma: [0..n-1] int(64);

    // delta[v] как рациональная дробь.
    var deltaNum: [0..n-1] int(64);
    var deltaDen: [0..n-1] int(64);

    var queue: [0..n-1] int;
    var stack: [0..n-1] int;

    for s in 0..n-1 {
      // Инициализация для источника s.
      dist = -1;
      sigma = 0:int(64);
      deltaNum = 0:int(64);
      deltaDen = 1:int(64);

      var head = 0;
      var tail = 0;
      var stackSize = 0;

      dist[s] = 0;
      sigma[s] = 1;
      queue[tail] = s;
      tail += 1;

      // BFS: считаем dist и sigma, запоминаем порядок обхода в stack.
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

      // Обратный проход по вершинам в порядке невозрастания dist.
      // Без хранения P[w]: предшественники определяем по условию dist[v] = dist[w]-1.
      var idx = stackSize - 1;
      while idx >= 0 {
        const w = stack[idx];

        for p in g.rowPtr[w]..g.rowPtr[w+1]-1 {
          const v = g.colIdx[p];

          if dist[v] == dist[w] - 1 {
            // contrib(v <- w) = (sigma[v]/sigma[w]) * (1 + delta[w])
            // 1 + delta[w] = (deltaDen[w] + deltaNum[w]) / deltaDen[w]
            var onePlusNum = deltaDen[w] + deltaNum[w];
            var onePlusDen = deltaDen[w];
            reduceFraction(onePlusNum, onePlusDen);

            // (sigma[v]/sigma[w]) * (onePlusNum/onePlusDen)
            // Сокращаем крест-накрест до умножения.
            var aNum = sigma[v];
            var aDen = sigma[w];
            var bNum = onePlusNum;
            var bDen = onePlusDen;

            var g1 = gcdI64(aNum, bDen);
            aNum /= g1;
            bDen /= g1;

            var g2 = gcdI64(bNum, aDen);
            bNum /= g2;
            aDen /= g2;

            const addNum = aNum * bNum;
            const addDen = aDen * bDen;

            addFraction(deltaNum[v], deltaDen[v], addNum, addDen);
          }
        }

        if w != s {
          addFraction(numOut[w], denOut[w], deltaNum[w], deltaDen[w]);
        }

        idx -= 1;
      }
    }

    // Для неориентированного графа Brandes считает каждую пару дважды,
    // поэтому делим результат на 2.
    for v in 0..n-1 {
      denOut[v] *= 2;
      reduceFraction(numOut[v], denOut[v]);
    }
  }

  proc computeBrandesBCReal(ref g: CSRGraph): [0..g.n-1] real {
    const n = g.n;
    var bc: [0..n-1] real;
    bc = 0.0;

    var dist: [0..n-1] int;
    var sigma: [0..n-1] int(64);
    var delta: [0..n-1] real;
    var queue: [0..n-1] int;
    var stack: [0..n-1] int;

    for s in 0..n-1 {
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
          bc[w] += delta[w];
        }
        idx -= 1;
      }
    }

    // undirected correction
    for v in 0..n-1 do
      bc[v] /= 2.0;

    return bc;
  }

}
