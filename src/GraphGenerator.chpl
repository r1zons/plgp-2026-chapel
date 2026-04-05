/*
  GraphGenerator.chpl
  Генерация связного случайного графа в CSR.
  На текущем этапе реализована минимальная заглушка с воспроизводимостью по seed.
*/
module GraphGenerator {
  use Random;
  use GraphCSR;

  proc generateConnectedRandomGraph(n: int, seed: int): CSRGraph {
    // В этом шаге строим минимальный связный граф-цепочку: 0-1-2-...-(n-1).
    // Это гарантирует связность и воспроизводимость независимо от seed.
    // seed сохранён в интерфейсе для будущей рандомизированной генерации.
    var _rng = new randomStream(real, seed=seed:uint);

    var g: CSRGraph;
    g.n = n;

    if n <= 0 {
      g.rowDom = {0..0};
      g.rowPtr = [i in g.rowDom] 0;
      g.colDom = {0..-1};
      g.colIdx = [i in g.colDom] 0;
      return g;
    }

    const mDirected = if n == 1 then 0 else 2 * (n - 1);

    g.rowDom = {0..n};
    g.rowPtr = [i in g.rowDom] 0;

    // Степени для цепочки.
    for v in 0..n-1 {
      if v == 0 || v == n-1 then
        g.rowPtr[v+1] = g.rowPtr[v] + (if n == 1 then 0 else 1);
      else
        g.rowPtr[v+1] = g.rowPtr[v] + 2;
    }

    g.colDom = {0..mDirected-1};
    g.colIdx = [i in g.colDom] 0;

    // Заполняем colIdx.
    for v in 0..n-1 {
      var pos = g.rowPtr[v];
      if v > 0 {
        g.colIdx[pos] = v-1;
        pos += 1;
      }
      if v+1 < n {
        g.colIdx[pos] = v+1;
      }
    }

    return g;
  }
}
