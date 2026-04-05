# plgp-2026-chapel

Проект для сравнения наивного алгоритма betweenness centrality и Brandes
на невзвешенных неориентированных связных графах в Chapel.

## Что создано в проекте

- `src/Main.chpl` — минимальный CLI и orchestration.
- `src/GraphCSR.chpl` — CSR-представление графа.
- `src/GraphGenerator.chpl` — генерация случайного связного графа (остов + случайные рёбра), печать маленьких графов.
- `src/NaiveBC.chpl` — заглушка baseline-алгоритма.
- `src/BrandesBC.chpl` — заглушка алгоритма Brandes.
- `src/Compare.chpl` — точное сравнение массивов результатов.
- `src/Report.chpl` — форматированный отчёт в stdout.
- `test/TestCompare.chpl` — unit-тест сравнения.
- `test/TestGraphGenerator.chpl` — unit-тесты генератора (включая случаи `n=5` и `n=7`).
- `scripts/pipeline.sh` — воспроизводимый pipeline.
- `Makefile` — команды сборки/запуска/тестов.

## Генератор графа

В `GraphGenerator` реализован надёжный генератор:

1. Сначала строится случайное остовное дерево (гарантирует связность).
2. Затем добавляются случайные рёбра до целевой плотности `defaultEdgeDensity`.
3. Запрещены петли и дубликаты неориентированных рёбер.
4. Результат возвращается сразу в CSR (`rowPtr`, `colIdx`).

Для визуальной проверки есть `printSmallGraph(g, maxN=20)`.

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
