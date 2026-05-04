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
- `--partitionedParts=<int>` (для partitioned Brandes; `<=0` => безопасный default)

Примеры:

```bash
make build
./bin/bc_compare --command=Generate --n=7 --seed=42
./bin/bc_compare --command=Run --n=100 --seed=42 --partitionedParts=2
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
- `Partitioned Brandes time: ...`
- `Partitioned parts: ...`
- `Naive total: ...`
- `Brandes total: ...`
- `Parallel Brandes total: ...`
- `Partitioned Brandes total: ...`
- `Correctness check seq: PASS/FAIL`
- `Correctness check par: PASS/FAIL`
- `Correctness check partitioned: PASS/FAIL`

Пример:

```bash
./bin/bc_compare --command=Run --n=100 --seed=42 --partitionedParts=2
```


## Параллельный Brandes (coforall)

- Используется `coforall`, а не `forall`, чтобы явно создавать задачи по блокам источников и контролировать слияние результатов.
- Источники делятся на равные блоки (`block decomposition`).
- Граф (`CSR`) общий и не дублируется.
- На задачу локальны: `dist`, `sigma`, `delta`, `queue`, `stack`, `localBC`.
- Слияние `localBC` в глобальный `bc` выполняется под простой блокировкой.

### Потенциальные узкие места по памяти

Основной вклад в память даёт `localBC` на каждую задачу (размер `O(n)` на задачу), плюс временные массивы BFS/обратного прохода (`dist/sigma/delta/queue/stack`) также `O(n)` на задачу.


## Partitioned Message-Passing Brandes: корректность и обмен сообщениями

### Почему нельзя считать BC независимо по partition и просто суммировать

Локальный BC внутри одной partition не учитывает кратчайшие пути, которые:
- начинаются в одной partition,
- проходят через вершины другой partition,
- возвращают вклад зависимости обратно через границу разбиения.

Поэтому простая схема «посчитать в каждой части отдельно и сложить» математически неверна:
она теряет межpartition пути и ломает рекурренцию Brandes.

### Почему межpartition кратчайшие пути требуют сообщений

Если ребро `(u, v)` пересекает границу (`owner(u) != owner(v)`),
то владелец `u` не должен напрямую менять состояние `v`.
Обновление для `v` отправляется владельцу `v` как сообщение.
Это сохраняет правило единственного владельца состояния вершины.

### Как работают RELAX-сообщения (forward BFS)

На уровне BFS `d` каждая partition обрабатывает frontier `dist=d`:
- локальные соседи обновляются напрямую;
- для межpartition соседа отправляется `RELAX(targetVertex, distance=d+1, sigmaContribution)`.

Владелец `targetVertex` применяет сообщение:
- если найдено меньшее расстояние — обновляет `dist` и `sigma`;
- если расстояние то же (`d+1`) — добавляет вклад в `sigma`.

### Как работают DEPENDENCY-сообщения (backward phase)

В обратной фазе (по убыванию уровней) для предшественника `v` вершины `w` используется:

`delta[v] += (sigma[v] / sigma[w]) * (1 + delta[w])`

Если `v` и `w` в разных partition, вклад отправляется как
`DEPENDENCY(targetVertex=v, contribution=...)` владельцу `v`.
Только владелец `v` обновляет `delta[v]`.

### Почему нужна синхронизация уровней BFS

Без барьера между уровнями часть `RELAX`-сообщений уровня `d` может прийти после начала `d+1`.
Это приводит к неверным `dist`/`sigma` (пропуски кратчайших путей или неверная мультипликативность путей).

### Почему нужна синхронизация уровней backward

`delta` на уровне `L-1` зависит от уже завершённых `delta` на уровне `L`.
Если начать более ранний уровень до доставки всех `DEPENDENCY`-вкладов,
рекурренция Brandes нарушается.

### Почему это эквивалентно обычному Brandes

Используются те же величины (`dist`, `sigma`, `delta`) и те же формулы обновления.
Меняется только способ доставки межвершинных обновлений: локально напрямую,
межpartition — через сообщения владельцам.
При level-synchronous барьерах порядок вычислений эквивалентен обычному Brandes.

### Отличие от текущего coforall block-source Brandes

`BrandesBCParallel` делит **источники** между задачами и обычно держит крупные временные структуры на задачу.
Partitioned message-passing Brandes делит **вершины** между partition,
с локальным состоянием по owned-вершинам и явными межpartition сообщениями.

### Сравнение памяти

- Source-parallel (`coforall` по источникам): примерно `O(numTasks * n)` временного состояния.
- Partitioned message-passing: примерно `O(local_n)` временного состояния на partition
  (плюс буферы сообщений на cut-edges).

### Текущие ограничения

- Сейчас это simulation message passing в одном Chapel-процессе.
- Это ещё не полноценная multi-locale distributed реализация.
- Communication overhead может быть высоким при большом числе cut-edges.
- Простое block-разбиение по id вершины может быть неоптимальным для реальных графов.

## Questions a teacher may ask

- **Why is this correct?**  
  Потому что сохраняются те же инварианты и формулы Brandes, а сообщения лишь заменяют прямой доступ через границы partition.

- **Why not just sum local BC values?**  
  Локальные вычисления не видят межpartition кратчайшие пути и не передают корректные dependency-вклады через границы.

- **What data is owned by each partition?**  
  Локальные состояния своих вершин: `dist`, `sigma`, `delta`, frontier-структуры и локальные contribution-накопители.

- **What messages are sent?**  
  Вперёд: `RELAX(targetVertex, distance, sigmaContribution)`.  
  Назад: `DEPENDENCY(targetVertex, contribution)`.

- **Where is synchronization required?**  
  Между уровнями forward BFS и между уровнями backward dependency phase.

- **What is the main memory advantage?**  
  Нет необходимости держать полноразмерные временные массивы на каждую задачу; состояние локализовано по partition.

- **What is the main performance drawback?**  
  Потери на коммуникации и барьерах, особенно при большом количестве межpartition рёбер.
