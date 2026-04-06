/*
  Compare.chpl
  Сравнение результатов baseline и optimized.
*/
module Compare {
  proc exactlyEqual(a: [?D] real, b: [D] real): bool {
    for i in D {
      if a[i] != b[i] then
        return false;
    }
    return true;
  }

  // Точное сравнение рациональных значений num/den.
  // Предполагается, что дроби уже приведены к канонической форме.
  proc exactlyEqualFractions(aNum: [?D] int(64), aDen: [D] int(64),
                             bNum: [D] int(64), bDen: [D] int(64)): bool {
    for i in D {
      if aNum[i] != bNum[i] || aDen[i] != bDen[i] then
        return false;
    }
    return true;
  }

  proc approximatelyEqual(a: [?D] real, b: [D] real, eps: real = 1.0e-9): bool {
    for i in D {
      if abs(a[i] - b[i]) > eps then
        return false;
    }
    return true;
  }
}
