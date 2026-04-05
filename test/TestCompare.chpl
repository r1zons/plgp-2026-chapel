/*
  Минимальный unit-тест Compare.exactlyEqual на малых массивах.
*/
module TestCompare {
  use Compare;

  proc main() {
    var a: [0..2] real = [1.0, 2.0, 3.0];
    var b: [0..2] real = [1.0, 2.0, 3.0];
    var c: [0..2] real = [1.0, 2.0, 4.0];

    assert(exactlyEqual(a, b));
    assert(!exactlyEqual(a, c));

    var nNum: [0..2] int(64) = [0, 3, 4];
    var nDen: [0..2] int(64) = [1, 1, 1];
    var bNum: [0..2] int(64) = [0, 3, 4];
    var bDen: [0..2] int(64) = [1, 1, 1];
    var cNum: [0..2] int(64) = [0, 3, 5];
    var cDen: [0..2] int(64) = [1, 1, 1];

    assert(exactlyEqualFractions(nNum, nDen, bNum, bDen));
    assert(!exactlyEqualFractions(nNum, nDen, cNum, cDen));

    writeln("TestCompare: PASS");
  }
}
