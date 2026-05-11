# Multi-locale plan for Partitioned Message-Passing Brandes

## 1) Термины: partition vs locale vs cluster node

Важно разделить три уровня:

- **Logical partition** — логическая часть графа (например, диапазон вершин), используемая алгоритмом.
- **Chapel locale** — единица размещения/выполнения в Chapel (`Locales[i]`).
- **Physical cluster node** — реальная машина (или VM) в кластере.

`partition` — это идея алгоритма. `locale` — механизм Chapel для размещения данных/кода. Один cluster node обычно соответствует одному или нескольким locale (зависит от backend/launcher).

---

## 2) Почему `--partitionedParts` сам по себе не распределяет данные по кластеру

Параметр `--partitionedParts` сейчас управляет только **логическим разбиением** графа на части.

Если код не использует `on Locales[...]`, то:

- все структуры всё равно могут жить на `here`;
- сообщения остаются in-process simulation;
- фактического межузлового распределения не происходит.

Иными словами: число partition не равно числу locale и не гарантирует распределённую память/вычисление.

---

## 3) Базовые multi-locale концепты Chapel

Для перехода к реальному distributed варианту нужны следующие элементы:

- `numLocales` — доступное число locale в рантайме;
- `Locales` — массив locale объектов;
- `here` — текущая locale выполнения;
- `on Locales[p] { ... }` — выполнить блок на целевой locale;
- `coforall loc in Locales do on loc { ... }` — параллельно запустить работу на всех locale.

---

## 4) Предложение по mapping

Простой воспроизводимый mapping:

- `part p -> Locales[p % numLocales]`

Плюсы:

- очень простой старт;
- не требует сложной схемы в первом multi-locale прототипе;
- работает для `parts >= numLocales` и `parts < numLocales`.

Минусы:

- баланс зависит от качества исходного partitioning и структуры графа.

---

## 5) Что должно жить на каждой locale

Для каждой locale (или для назначенных ей partition) размещать локально:

- owned vertex range (или список owned-вершин);
- local adjacency / local CSR slice;
- local `dist`;
- local `sigma`;
- local `delta`;
- local `frontier`;
- local `nextFrontier`;
- local `BC` accumulation;
- outgoing message buffers (`RELAX`/`DEPENDENCY`) на другие locale/part.

Цель: минимизировать удалённые обращения в traversal-state и обновлять owned-данные локально.

---

## 6) Forward phase в multi-locale

Для каждого BFS уровня `d`:

1. На каждой locale обрабатывается локальный frontier (`dist == d`) и локальные рёбра.
2. Для remote owner отправляются `RELAX`-сообщения.
3. Полученные `RELAX` применяются владельцем вершины.
4. Барьер уровня: переход к `d+1` только после завершения доставки/применения сообщений уровня `d`.

Ключевой инвариант: `dist/sigma` обновляет только owner вершины.

---

## 7) Backward phase в multi-locale

Для каждого обратного уровня `L` (от maxDist к 1):

1. Локально считаются dependency-вклады в предшественников на `L-1`.
2. Для remote owner отправляются `DEPENDENCY`-сообщения.
3. Полученные вклады применяются владельцем вершины (`delta`).
4. Барьер перед переходом к следующему обратному уровню.

Ключевой инвариант: `delta` также обновляет только owner вершины.

---

## 8) Сборка и запуск multi-locale Chapel

Практические замечания:

- Multi-locale требует поддержки коммуникационного backend.
- `CHPL_COMM=none` поддерживает только one-locale сценарий.
- Для multi-locale запуска обычно используются `-nl <N>` / `--numLocales=<N>`.
- Конкретный launcher (`gasnetrun_*`, `slurm`, `aprun`, и т.п.) зависит от окружения кластера.

Примерно:

- компиляция с подходящим `CHPL_COMM`;
- запуск с `-nl 1` (базовая проверка), затем `-nl 2+`.

---

## 9) Основные риски

1. **Скрытый remote access** в helper-функциях (например, случайные чтения/записи не на owner-locale).
2. **Synchronization overhead** на каждом уровне forward/backward.
3. **Message buffer placement** и стоимость сериализации/доставки.
4. **Load imbalance** между locale/partition.
5. **Плохое partitioning** (много cut-edges) => много сообщений и потеря производительности.

---

## 10) Конкретные ближайшие milestones

1. **Locale skeleton**
   - завести каркас `coforall loc in Locales do on loc { ... }`;
   - ввести явную таблицу mapping `part -> locale`.

2. **Local data placement**
   - перенести owned traversal-state и local CSR slices на назначенные locale.

3. **Remote message delivery abstraction**
   - отдельный слой отправки/приёма `RELAX`/`DEPENDENCY` между locale;
   - контроль барьеров по уровням.

4. **Correctness tests on multiple locales**
   - проверка эквивалентности на `-nl 1` и `-nl 2` против Naive/Seq Brandes.

5. **Cluster benchmark**
   - измерить время/масштабируемость/объёмы сообщений;
   - оценить влияние cut-edge плотности и качества partitioning.

---

## Итог

Текущая реализация — корректный single-process simulation этап.
Переход к true multi-locale требует явного data placement на `Locales`,
owner-local update discipline и уровня синхронизации/доставки сообщений в распределённой среде.
