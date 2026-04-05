/*
  Compare.chpl
  Проверка точного совпадения результатов baseline и optimized.
*/
module Compare {
  proc exactlyEqual(a: [?D] real, b: [D] real): bool {
    for i in D {
      if a[i] != b[i] then
        return false;
    }
    return true;
  }
}
