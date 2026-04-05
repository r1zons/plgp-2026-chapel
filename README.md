# plgp-2026-chapel

Каркас проекта для сравнения двух алгоритмов betweenness centrality на невзвешенных неориентированных связных случайных графах в Chapel.

## Структура

- `src/GraphCSR.chpl` — CSR-представление графа.
- `src/GraphGenerator.chpl` — генератор связного случайного графа (пока stub-версия: цепочка).
- `src/NaiveBC.chpl` — заглушка baseline (наивный алгоритм).
- `src/BrandesBC.chpl` — заглушка optimized (Brandes).
- `src/Compare.chpl` — точное сравнение результатов.
- `src/Report.chpl` — формат отчёта в stdout.
- `src/Main.chpl` — CLI и orchestration.
- `test/` — минимальные unit-тесты на малых графах.
- `scripts/pipeline.sh` — воспроизводимый pipeline.
- `Makefile` — сборка, запуск, тесты.

## CLI

Минимальный интерфейс:

- `Generate`
- `Run`

Параметры:

- `--command=Generate|Run`
- `--n=<число вершин>`
- `--seed=<seed>`

## Использование

```bash
make build
./bin/bc_compare --command=Generate --n=100 --seed=1
./bin/bc_compare --command=Run --n=100 --seed=1
make test
```

Или воспроизводимый pipeline:

```bash
./scripts/pipeline.sh 100 1
```

## Совместимость

- Цель: Chapel 2.8.
- По возможности избегаются фичи новее Chapel 2.0.
