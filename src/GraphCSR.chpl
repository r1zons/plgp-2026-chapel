/*
  GraphCSR.chpl
  Базовое CSR-представление для невзвешенного неориентированного графа.
  Архитектурный каркас; детали построения будут расширены позже.
*/
module GraphCSR {
  record CSRGraph {
    // Количество вершин.
    var n: int;

    // rowPtr имеет длину n+1.
    // rowPtr[v]..rowPtr[v+1]-1 — диапазон соседей вершины v в colIdx.
    var rowDom: domain(1) = {0..-1};
    var rowPtr: [rowDom] int;

    // colIdx хранит список соседей (ориентированные дуги для неориентированного графа).
    var colDom: domain(1) = {0..-1};
    var colIdx: [colDom] int;

    proc numVertices(): int {
      return n;
    }

    proc numDirectedEdges(): int {
      return colDom.size;
    }
  }
}
