# Project instructions for Codex

This repository contains a Chapel project for comparing:
- a naive baseline algorithm for betweenness centrality
- Brandes algorithm
- a parallel Brandes variant later

## Core goals
- Correctness is the top priority.
- Performance matters only after correctness is established.
- Prefer clear, minimal, high-confidence changes.
- Avoid guessing Chapel syntax or semantics.

## Required workflow before editing Chapel code
Before changing any `.chpl` file, always do this in order:

1. Read this file.
2. Read all files under `docs/chapel/`.
3. Summarize the exact Chapel constructs relevant to the current task.
4. Inspect the current implementation.
5. Propose the smallest safe fix.
6. Run the smallest relevant build/test command after each nontrivial change.

## Documentation-first rule
Do not guess Chapel syntax.

If any of the following are unclear, consult `docs/chapel/` first:
- module structure
- procedures and intents
- arrays/domains
- records
- ranges
- loops
- random generation
- CSR graph data layout
- parallel constructs (`forall`, `coforall`, `on`, locales)
- initialization rules
- array slicing and assignment semantics

If local docs are insufficient, say exactly which topic is missing before coding.

## Compatibility target
- Primary target: Chapel 2.8
- Prefer syntax that is also likely to work on Chapel 2.0 when reasonable
- Do not introduce newer features unless necessary

## Project constraints
- Graphs are:
  - unweighted
  - undirected
  - connected
  - randomly generated
- CLI parameters:
  - `--n`
  - `--seed`
- Graph import is not needed for now
- Main graph representation should be CSR unless there is a strong, documented reason otherwise
- Do not duplicate the graph in multiple large representations without clear need
- Be memory-conscious
- Avoid unnecessary copies of large arrays and records

## Implementation priorities
Implement in this order unless explicitly told otherwise:
1. graph generation
2. naive baseline
3. sequential Brandes
4. result comparison
5. stdout report
6. parallel Brandes with block decomposition

## Testing policy
Always keep or improve tests.
For graph generation and BC code, prefer:
- tiny deterministic tests
- path graph
- star graph
- tiny random graph with fixed seed

When fixing a bug:
- add or update the smallest test that reproduces it
- then fix the code

## Build and run expectations
Prefer the smallest relevant command:
- build only when enough
- run only the relevant test when enough
- avoid long benchmark runs unless explicitly requested

## Reporting expectations
The runtime report printed to stdout should include:
- graph size
- seed
- generation time
- naive time
- Brandes time
- parallel Brandes time when available
- total times
- correctness check PASS/FAIL

## Change discipline
- Keep diffs focused
- Do not refactor unrelated code
- Do not rename files or modules without need
- Explain briefly why each change is needed
- After finishing, summarize:
  - what changed
  - what was tested
  - any remaining uncertainty
