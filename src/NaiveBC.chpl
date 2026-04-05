/*
  NaiveBC.chpl
  Заглушка для baseline-алгоритма betweenness centrality.
*/
module NaiveBC {
  use GraphCSR;

  proc computeNaiveBC(ref g: CSRGraph): [0..g.n-1] real {
    // TODO: Реализовать наивный алгоритм.
    var bc: [0..g.n-1] real;
    bc = 0.0;
    return bc;
  }
}
