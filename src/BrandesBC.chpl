/*
  BrandesBC.chpl
  Заглушка для оптимизированного алгоритма Brandes.
  На следующем этапе сюда добавится последовательная реализация,
  затем параллельная версия через coforall.
*/
module BrandesBC {
  use GraphCSR;

  proc computeBrandesBC(ref g: CSRGraph): [0..g.n-1] real {
    // TODO: Реализовать алгоритм Brandes.
    var bc: [0..g.n-1] real;
    bc = 0.0;
    return bc;
  }
}
