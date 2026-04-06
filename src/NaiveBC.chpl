/*
  NaiveBC.chpl
  Корректный baseline-алгоритм betweenness centrality (последовательный).

  Подход (для невзвешенного неориентированного графа):
    - для каждой пары вершин (s, t), s < t:
      1) считаем dist_s[*], sigma_s[*] через BFS из s
      2) считаем dist_t[*], sigma_t[*] через BFS из t
      3) для каждой вершины v != s,t проверяем, лежит ли v на кратчайших путях s->t:
           dist_s[v] + dist_t[v] == dist_s[t]
         вклад:
           sigma_s[v] * sigma_t[v] / sigma_s[t]

  Для точности накопление идёт в рациональных дробях (num/den).
  В модуле используются только целочисленные расстояния и счётчики путей.
*/
module NaiveBC {
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
    // acc + add = accNum/accDen + addNum/addDen
    var addNum = addNumIn;
    var addDen = addDenIn;
    reduceFraction(addNum, addDen);

    if addNum == 0 then
      return;

    // Складываем через НОК знаменателей, чтобы меньше рисковать переполнением.
    const g = gcdI64(accDen, addDen);
    const leftMul = addDen / g;
    const rightMul = accDen / g;

    var n = accNum * leftMul + addNum * rightMul;
    var d = accDen * leftMul;

    reduceFraction(n, d);
    accNum = n;
    accDen = d;
  }

  private proc bfsDistSigma(ref g: CSRGraph, source: int,
                            ref dist: [] int, ref sigma: [] int(64)) {
    const n = g.n;

    dist = -1;
    sigma = 0:int(64);

    var q: [0..n-1] int;
    var head = 0;
    var tail = 0;

    dist[source] = 0;
    sigma[source] = 1;
    q[tail] = source;
    tail += 1;

    while head < tail {
      const v = q[head];
      head += 1;

      for p in g.rowPtr[v]..g.rowPtr[v+1]-1 {
        const w = g.colIdx[p];

        if dist[w] < 0 {
          dist[w] = dist[v] + 1;
          q[tail] = w;
          tail += 1;
        }

        if dist[w] == dist[v] + 1 {
          sigma[w] += sigma[v];
        }
      }
    }
  }

  // Возвращает точный результат как массивы числителей и знаменателей.
  proc computeNaiveBCExact(ref g: CSRGraph,
                           ref numOut: [] int(64),
                           ref denOut: [] int(64)) {
    const n = g.n;

    numOut = 0:int(64);
    denOut = 1:int(64);

    var distS: [0..n-1] int;
    var distT: [0..n-1] int;
    var sigmaS: [0..n-1] int(64);
    var sigmaT: [0..n-1] int(64);

    for s in 0..n-1 {
      bfsDistSigma(g, s, distS, sigmaS);

      for t in s+1..n-1 {
        if distS[t] < 0 then
          continue;

        bfsDistSigma(g, t, distT, sigmaT);

        const stDist = distS[t];
        const stSigma = sigmaS[t];

        for v in 0..n-1 {
          if v == s || v == t then
            continue;

          if distS[v] >= 0 && distT[v] >= 0 && distS[v] + distT[v] == stDist {
            // Вклад в BC(v): sigma_s(v) * sigma_t(v) / sigma_s(t)
            // Перед умножением сокращаем с знаменателем.
            var x = sigmaS[v];
            var y = sigmaT[v];
            var d = stSigma;

            var g1 = gcdI64(x, d);
            x /= g1;
            d /= g1;

            var g2 = gcdI64(y, d);
            y /= g2;
            d /= g2;

            const addNum = x * y;
            const addDen = d;

            if addNum != 0 {
              addFraction(numOut[v], denOut[v], addNum, addDen);
            }
          }
        }
      }
    }
  }

}
