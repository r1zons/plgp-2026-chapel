# Partitioned Brandes: shared-memory parallel partition execution plan

## 1) Текущая разница между двумя параллельными подходами

### `BrandesBCParallel` (source-parallel)

- Делит **источники** между задачами (`coforall` по блокам источников).
- Каждая задача считает обычный single-source Brandes для своего набора источников.
- Это source-level параллелизм.

### `PartitionedBrandes` (graph-partitioned)

- Делит **вершины графа** на partition.
- Использует owner-based state и сообщения `RELAX` / `DEPENDENCY`.
- Сейчас это корректная single-process simulation, но обработка partition по уровням в основном выполняется последовательно.

---

## 2) Новый целевой вариант

**Partitioned Brandes with parallel partition execution (one node):**

- На каждом уровне BFS/Backward partition обрабатываются параллельно через `coforall`.
- Межpartition вклад остаётся message-based.
- После локальной фазы обязательно синхронизация и доставка сообщений.

Это shared-memory параллелизм внутри одного узла, без multi-locale.

---

## 3) Forward BFS (по уровням) в новом варианте

Для уровня `d`:

1. `coforall p in 0..numParts-1`:
   - локально обрабатывается frontier partition `p`;
   - локальные relax-обновления применяются сразу;
   - для cross-part рёбер формируются `RELAX`-сообщения.
2. Барьер после параллельной локальной обработки.
3. Фаза доставки/применения сообщений у владельцев destination-part.
4. Барьер после доставки.
5. Переход к уровню `d+1`.

---

## 4) Backward dependency (по обратным уровням)

Для уровня `L` (от maxDist к 1):

1. `coforall p in 0..numParts-1`:
   - локально считаются dependency-вклады;
   - локальные вклады в `delta` применяются сразу;
   - cross-part вклады пакуются в `DEPENDENCY`-сообщения.
2. Барьер после локальной фазы.
3. Доставка/применение dependency-сообщений у владельцев target-part.
4. Барьер после доставки.
5. Переход к `L-1`.

---

## 5) Почему `messages[dst]` небезопасно в `coforall`

Если несколько partition одновременно пишут в один буфер `messages[dst]`:

- возникает конкурентная запись в общую структуру;
- нужны блокировки/атомики на каждый append;
- высокая contention + риск ошибок (гонки/потеря сообщений).

---

## 6) Зачем двухмерные буферы `messages[fromPart][toPart]`

Вместо одного входного буфера на destination использовать матрицу буферов:

- `RELAX[fromPart][toPart]`
- `DEPENDENCY[fromPart][toPart]`

Тогда каждый producer пишет только в свою строку (`fromPart`),
а consumer-part собирает колонку/входящие для себя.

---

## 7) Почему это убирает write-races

- Каждый `fromPart` пишет только в свои `messages[fromPart][*]`.
- Нет одновременной записи разных producer в одну и ту же структуру.
- На delivery-phase destination-part читает адресованные ему буферы и применяет их к своему локальному состоянию.

Итог: гонки на append существенно упрощаются/исключаются по конструкции буферов.

---

## 8) Какие данные shared read-only

- CSR граф (`rowPtr`, `colIdx`, `n`);
- metadata разбиения (`owner`, диапазоны partition и пр.).

Эти данные читаются всеми задачами, но не модифицируются на уровне single-source прохода.

---

## 9) Какие данные partition-local

Для каждой partition локальны и изменяются только owner-обработчиком:

- `dist`
- `sigma`
- `delta`
- `frontier`
- `nextFrontier`
- `localBC`

Это ключ к снижению contention и к owner-update discipline.

---

## 10) Какие барьеры обязательны

Минимально нужны:

1. Барьер после параллельной local frontier/dependency фазы.
2. Барьер после доставки и применения сообщений текущего уровня.
3. В backward — отдельный барьер после dependency delivery перед переходом к следующему обратному уровню.

Без этих барьеров нарушается level-synchronous корректность Brandes.

---

## 11) Ограничения первого parallel-partition варианта

- Всё ещё single-node shared-memory.
- Это не Chapel multi-locale.
- Это не cluster-distributed execution.
- Внутри одной partition локальная работа на старте может оставаться последовательной.

---

## 12) Следующие уровни параллелизма

1. Параллелить local frontier processing внутри partition.
2. Добавить source batching (несколько источников одновременно, аккуратно по памяти).
3. Перейти к true multi-locale размещению через `Locales` / `on`.

---

## Итог

Новый шаг — не менять математическую часть Brandes, а изменить execution model:
partition-level `coforall` + race-safe message topology `fromPart -> toPart` + строгие level barriers.
Это даст реальный shared-memory parallel execution для graph-partitioned подхода, оставаясь в одном узле.
