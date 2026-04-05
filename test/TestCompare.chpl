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

    writeln("TestCompare: PASS");
  }
}
