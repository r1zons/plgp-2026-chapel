# plgp-2026-chapel

Проект для сравнения наивного алгоритма betweenness centrality и Brandes
на невзвешенных неориентированных связных графах в Chapel.

## Что создано в проекте

- `src/Main.chpl` — минимальный CLI и orchestration.
- `src/GraphCSR.chpl` — CSR-представление графа.
- `src/GraphGenerator.chpl` — генерация случайного связного графа (остов + случайные рёбра), печать маленьких графов.
- `src/NaiveBC.chpl` — корректный последовательный baseline-алгоритм наивного betweenness centrality (точное накопление в рациональных дробях).
- `src/BrandesBC.chpl` — корректный последовательный алгоритм Brandes.
- `src/BrandesBCParallel.chpl` — параллельный Brandes на `coforall` с блочным делением источников.
- `src/Compare.chpl` — точное сравнение массивов результатов.
- `src/Report.chpl` — форматированный отчёт в stdout.
- `test/TestCompare.chpl` — unit-тест сравнения.
- `test/TestGraphGenerator.chpl` — unit-тесты генератора (включая случаи `n=5` и `n=7`).
- `test/TestNaiveBC.chpl` — unit-тесты наивного BC на path/star графах с явной проверкой ожидаемых значений.
- `test/TestBrandesBC.chpl` — unit-тесты последовательного Brandes.
- `test/TestBrandesBCParallel.chpl` — unit-тесты параллельного Brandes (coforall) против NaiveBC.
- `scripts/pipeline.sh` — воспроизводимый pipeline.
- `Makefile` — команды сборки/запуска/тестов.

## Генератор графа

В `GraphGenerator` реализован надёжный генератор:

1. Сначала строится случайное остовное дерево (гарантирует связность).
2. Затем добавляются случайные рёбра до целевой плотности `defaultEdgeDensity`.
3. Запрещены петли и дубликаты неориентированных рёбер.
4. Результат возвращается сразу в CSR (`rowPtr`, `colIdx`).

Для визуальной проверки есть `printSmallGraph(g, maxN=20)`.

## Наивный BC (baseline)

В `NaiveBC` реализован корректный последовательный алгоритм (без параллелизма):

- перебор всех пар `(s, t)`, `s < t`;
- BFS из `s` и из `t` для `dist` и количества кратчайших путей `sigma`;
- вклад вершины `v` в точной рациональной форме:
  `sigma_s(v) * sigma_t(v) / sigma_s(t)`;
- накопление через целочисленные числитель/знаменатель с сокращением дробей.

В `Main` время работы наивного алгоритма уже фиксируется в поле `naive_time_sec` отчёта.
Сравнение Naive vs Brandes в `Run` делается по `real`-результатам с допуском `eps=1e-9` (это избегает переполнений `int(64)` на больших графах при точной рациональной агрегации).
Если есть расхождения, печатаются первые несовпадающие вершины и их значения.

## Brandes BC (sequential)

В `BrandesBC` реализован корректный последовательный алгоритм Brandes:

- один BFS на каждый источник `s`;
- накопление зависимостей в обратном порядке расстояний;
- без дублирования графа (работа только по CSR);
- точное накопление вклада в рациональных дробях;
- для неориентированного графа итог делится на 2.

Время работы последовательного и параллельного Brandes фиксируется отдельно в отчёте Run.

Алгоритмы считают пути в невзвешенном графе: длины путей (`dist`) и количества кратчайших путей (`sigma`) хранятся как целые числа.
Никакие вещественные веса рёбер в Naive/Brandes не используются.

## CLI

Минимальный интерфейс:

- `Generate`
- `Run`

Параметры:

- `--command=Generate|Run`
- `--n=<число вершин>`
- `--seed=<seed>`

Примеры:

```bash
make build
./bin/bc_compare --command=Generate --n=7 --seed=42
./bin/bc_compare --command=Run --n=100 --seed=42
```

## Как запускать через Makefile

```bash
make build       # собрать основной бинарник
make generate    # запустить команду Generate (дефолтные n/seed)
make run         # запустить команду Run (дефолтные n/seed)
make test        # прогнать все unit-тесты, включая Brandes parallel
make test-brandes-parallel # только тесты Brandes parallel
make clean       # очистить bin/
```

Также можно запустить pipeline:

```bash
./scripts/pipeline.sh 100 42
```

## Совместимость

- Цель: Chapel 2.8.
- По возможности избегаются фичи новее Chapel 2.0.


## Формат отчёта Run

Команда `Run` печатает строки:

- `Graph size: ...`
- `Seed: ...`
- `Generation time: ...`
- `Naive time: ...`
- `Brandes time: ...`
- `Parallel Brandes time: ...`
- `Naive total: ...`
- `Brandes total: ...`
- `Parallel Brandes total: ...`
- `Correctness check seq: PASS/FAIL`
- `Correctness check par: PASS/FAIL`

Пример:

```bash
./bin/bc_compare --command=Run --n=100 --seed=42
```


## Параллельный Brandes (coforall)

- Используется `coforall`, а не `forall`, чтобы явно создавать задачи по блокам источников и контролировать слияние результатов.
- Источники делятся на равные блоки (`block decomposition`).
- Граф (`CSR`) общий и не дублируется.
- На задачу локальны: `dist`, `sigma`, `delta`, `queue`, `stack`, `localBC`.
- Слияние `localBC` в глобальный `bc` выполняется под простой блокировкой.

### Потенциальные узкие места по памяти

Основной вклад в память даёт `localBC` на каждую задачу (размер `O(n)` на задачу), плюс временные массивы BFS/обратного прохода (`dist/sigma/delta/queue/stack`) также `O(n)` на задачу.
