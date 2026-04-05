# plgp-2026-chapel

Проект для сравнения наивного алгоритма betweenness centrality и Brandes
на невзвешенных неориентированных связных графах в Chapel.

## Что создано в проекте

- `src/Main.chpl` — минимальный CLI и orchestration.
- `src/GraphCSR.chpl` — CSR-представление графа.
- `src/GraphGenerator.chpl` — генерация случайного связного графа (остов + случайные рёбра), печать маленьких графов.
- `src/NaiveBC.chpl` — корректный последовательный baseline-алгоритм наивного betweenness centrality (точное накопление в рациональных дробях).
- `src/BrandesBC.chpl` — заглушка алгоритма Brandes.
- `src/Compare.chpl` — точное сравнение массивов результатов.
- `src/Report.chpl` — форматированный отчёт в stdout.
- `test/TestCompare.chpl` — unit-тест сравнения.
- `test/TestGraphGenerator.chpl` — unit-тесты генератора (включая случаи `n=5` и `n=7`).
- `test/TestNaiveBC.chpl` — unit-тесты наивного BC на path/star графах с явной проверкой ожидаемых значений.
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
make test        # прогнать unit-тесты
make clean       # очистить bin/
```

Также можно запустить pipeline:

```bash
./scripts/pipeline.sh 100 42
```

## Совместимость

- Цель: Chapel 2.8.
- По возможности избегаются фичи новее Chapel 2.0.
