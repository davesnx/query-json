# Compiled query engine architecture

Status: compiled execution, result folding, and selective root-member retention
are implemented. Barrier-aware event input, Core delivery policy, and CLI routing
are implemented. Controlled-pipe Cram tests and a first-result benchmark are
implemented and checked locally. The one-iteration benchmark check hits the
existing timer-resolution guard. Full-stage verification and repeated
fresh-process peak-RSS measurements remain.

This document explains the execution architecture for maintainers and defines
the input-streaming seam.

## Problem

The interpreter evaluates every query against a complete `Json.t` and returns a
complete result list. This has two independent costs:

- Large result streams allocate a final list before callers can consume output.
- Input parsing retains the complete document even when a query needs one part.

An optimized path must preserve query semantics, diagnostics, source ownership,
and fallback behavior. It must not retry with the interpreter after execution
or output starts.

## Goals

- Prepare an immutable execution plan once and reuse it safely.
- Compile a conservative query subset without changing its results or errors.
- Let callers consume complete top-level results without a final result list.
- Retain only a selected root member when the plan permits it.
- Validate all input bytes and preserve input error precedence in existing calls.
- Keep interpreted fallback behavior unchanged.

## Non-goals

- Compile the complete language.
- Mix compiled and interpreted nodes in one plan.
- Expose parser tokens, sparse JSON values, or lazy containers.
- Stream JSON rendering one token at a time.
- Claim constant memory or bounded peak RSS.
- Change REPL input or JavaScript output behavior.
- Make the parser accept only RFC JSON. The existing parser language remains.

## Current caller usage

Callers can execute an existing value atomically:

```ocaml
Core.run query json
```

They can consume each complete result without a final list:

```ocaml
Core.run_iter ~emit query json
```

Source calls let Core select input retention:

```ocaml
Core.run_input query (Core.File path)
Core.run_input_iter ~emit query (Core.Channel stdin)
```

`run_input` and default `run_input_iter` validate the complete source before
execution. The iterator call can expose a result prefix before a later query error, but it
cannot expose output before input EOF.

`run_input_iter ~input_delivery:Core.When_ready` permits output before EOF for
proven compiled item cuts. `debug=true` forces validation-first delivery.

## Current architecture

```text
CLI or JavaScript
  -> Core parses the query without debug output
  -> Execution.prepare selects a compiled plan or interpreter fallback
  -> Execution.load reads and validates the source
       -> whole value with the original plan
       -> selected value with a residual compiled plan
  -> Execution.execute_loaded collects results
     or Execution.fold_loaded consumes results in order
  -> Core renders each complete Json.t
  -> the CLI writes atomically or flushes each result line
```

### Prepared execution

`Execution.t` is abstract. `Execution.prepare` returns one of two private
representations:

- `Plan plan` for a fully compiled expression.
- `Fallback expression` when any part is unsupported.

Preparation does not evaluate the expression. Compiled execution never retries
through the interpreter after a runtime error.

The private plan distinguishes single-result and multi-result nodes. A
single-result node is not necessarily a scalar. `List` and `Map` also produce
one result.

The compiler currently supports:

| Shape | Compiled forms |
|---|---|
| Values | identity and literals |
| Access | root keys, fixed indices, multiple indices, and iteration |
| Composition | pipes and commas |
| Collections | array construction and `map` |
| Filtering | `empty` and `select` |
| Operators | operations with two single-result operands |

Unsupported forms force whole-expression fallback. `length`, functions,
bindings, optional access, sorting, and control flow are examples of forms that
remain interpreted.

Each execution call owns its cursor state. Prepared plans and loaded values are
immutable and reusable after success, failure, halt, or callback exception.

### Shared runtime semantics

The compiled executor and interpreter use private `Runtime` functions for
literals, operators, truthiness, key access, indices, iteration, and formatted
runtime errors. `source/dune` declares `Runtime` as a private module.

This seam prevents compiled and interpreted execution from developing separate
numeric, access, and diagnostic rules.

### Pull results

`Execution.fold` drains either a compiled cursor or `Interpreter.fold`.
`Core.run_iter` renders one complete `Json.t` before it calls `emit`.

The fold removes only the final top-level result list. Collection expressions
such as array construction and `map` can still materialize intermediate lists.

The fold contract is:

- Results keep their current order.
- A late error or halt can follow earlier callback calls.
- Callback exceptions escape unchanged.
- Callbacks receive no output separator.
- The CLI adds LF and flushes each complete result line.

`Core.run` and default CLI output still collect results and publish them only
after successful execution.

### Selective input retention

`Json.Input` owns these source adapters:

```ocaml
type source =
  | String of string
  | File of string
  | Channel of in_channel
  | Value of Json.t
```

`Execution.load` analyzes a compiled plan for one unconditional leading root
key. For `.account.profile.name`, the reader can retain the complete `account`
value and execution uses the residual `.profile.name` plan.

The reader returns `Selected value` only after it validates the complete
document and EOF. It preserves these rules:

- The first duplicate root member wins.
- Later duplicate members are still validated.
- A missing member retains the complete object for existing diagnostics.
- A non-object root retains the complete value for existing type errors.
- Discarded containers do not build lists.
- Discarded strings and numbers use the normal validation path.
- `File` closes its owned channel. `Channel` remains borrowed and open.
- `Value` returns the supplied value without parsing.

Selection is conservative. Commas, operations, root collections, and fallback
plans use whole input when they obstruct the leading-key shape. A suffix after
the selected key can still contain compiled commas or collections.

`Execution.loaded` binds the selected or whole value to the correct plan. Its
abstract type prevents callers from applying the original leading-key plan to
an already selected value.

### Core error order

`Core.run_input` and default `Core.run_input_iter` parse the query silently,
validate the source, and then report the result:

1. An input error wins over a query parse error.
2. Debug AST output appears only after valid input.
3. Execution starts only after valid input.

This order also applies when `debug=true`, even with `When_ready`. Without debug,
eligible `When_ready` queries can execute before EOF. Query failures stop output
but drain the input, so a later input error still wins.

### Callers

- Normal CLI calls use `Core.run_input` or `Core.run_input_iter`.
- `--stream-output` requests `When_ready` and flushes each result.
- JavaScript string execution uses atomic `Core.run_input`.
- The REPL keeps a complete parsed value and uses the tree calls.
- `--stream-output` has no effect in the REPL.

## Semantic invariants

Future work must preserve these existing behaviors:

- Pipes drain each upstream value through the downstream plan in depth-first
  order.
- Commas drain the left branch before the right branch for the same input.
- Opening a later branch must not evaluate it early.
- Member lookup uses the first duplicate key.
- Object iteration includes duplicate values in stored order.
- Negative indices count from the end.
- Multiple indices preserve requested order and duplicates.
- Only `false` and `null` are false.
- `select` yields once for each truthy predicate result.
- Boolean operators evaluate both expression operands.
- An incomplete array constructor or `map` result is not yielded after failure.
- Callback exceptions are not query errors and keep their identity.
- Every execution call starts with fresh mutable state.

## Current limits

- Default calls, barriers, fallback, and debug mode validate before execution.
- Selection removes only one leading root key.
- The selected subtree is complete and can be large.
- Members before a late or missing selection are materialized while searching.
- Discarded scalar validation can allocate temporary buffers and values.
- `fold` cannot ask the producer to stop through a public cancellation result.
- The sink and selective-reader benchmarks measure allocation volume, not peak
  memory, bounded memory, or first-result latency.

## Measured evidence

The in-process benchmark checks collected results exactly before timing. The
sink fold uses a checksum, while execution tests check result order and values.
The benchmark has no hard performance threshold. The completed task recorded
these local medians:

| Slice | Time result | Allocation result |
|---|---:|---:|
| Fold 16,384 outputs instead of collecting a list | 66.1% less | 26.1% less |
| Select early root member from an 87,366-byte input | 18.2% less | 60.8% less |
| Select late root member | 4.1% less | unchanged |
| Full-input fallback control | 0.8% more | unchanged |

These results show that the seams remove measured work in their fixtures. They
do not prove end-to-end CLI latency or a general memory bound.

### Event-input test and first-result evidence

On 2026-09-19, the release CLI Cram suite passed on Linux with OCaml
`5.5.0~beta1`. The private `stream_probe` uses `Unix.create_process`,
close-on-exec pipes, and `Runtime_events.Timestamp` monotonic deadlines. It
requires both residual outputs before sending the remaining input, then checks
the full output and exit status:

```text
root: before EOF "1\n11\n"; final "1\n11\n2\n12\n"; exit 0
member: before EOF "1\n11\n"; final "1\n11\n2\n12\n"; exit 0
```

An isolated wrapper forced the real CLI into validation-first mode. The probe
rejected it at its five-second deadline with empty stdout. The real streaming
CLI passed both cases. Windows execution has not been checked in this slice.

The first-result fixture wraps `benchmarks/big.json` in a `rows` member with a
trailing `tail` field: 574,926 input bytes and 1,618 rendered outputs. The query
`.rows[] | .id` uses a verified compiled `Member_items rows` cut. Both policies'
complete outputs matched before timing, with first output `1`.

The requested `--iterations 1 --warmup 1 --samples 3` run stopped in the earlier
prepared-execution table with `Non-positive elapsed time`. It did not reach the
first-result table. A follow-up run used `--iterations 1000 --warmup 1 --samples 3`
and passed every result check. Iterations do not apply to the first-result
table. Its three paired samples still used one fresh call per policy:

```text
Workload                  W first ns   A first ns    W first B    A first B Time delta Alloc delta Samples
event_member_first           46968.5    4760980.6     607992.0    3657768.0     -99.0%     -83.4%       3
```

`W` is `When_ready`; `A` is `After_validation`. These are local medians to the
first rendered library callback, including query parse/prepare and JSON parsing.
The source string stays retained. B measures allocation volume to that callback,
not peak RSS. The first callback records its counters before checking the
result, and every call continues to EOF with exact output checks. Fixture load,
process startup, and stdout are excluded. This single run does not establish a
general speedup or memory bound. See `benchmarks/README.md` for the measurement
boundary and the separate repeated Linux RSS procedure. Peak RSS has not been
measured in this slice.

## Event-input stage

This section defines the implemented source-fold contract. The controlled-pipe
probe tests pre-EOF CLI output. A separate benchmark measures the first rendered
library callback. Fresh-process peak-RSS measurements remain separate work.

### Caller usage

Existing library calls keep validation-before-output by default:

```ocaml
Core.run_input_iter ~emit query source
```

The CLI requests early input delivery only for `--stream-output`:

```ocaml
Core.run_input_iter ~input_delivery:Core.When_ready ~emit query source
```

`When_ready` permits early delivery. It does not promise it. Execution selects
the validated path for unsupported plans and barriers.

### Shape

Keep `Execution.loaded` unchanged. A live source is mutable, single-use, and can
own an open file. It must not enter the validated, immutable, reusable type.

The explicit publication policy is:

```ocaml
type input_delivery =
  | After_validation
  | When_ready
```

The iterator call keeps validation-first delivery as its default:

```ocaml
val run_input_iter :
  ?input_delivery:input_delivery ->
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  emit:(string -> unit) ->
  string ->
  input ->
  (unit, string) result
```

Execution owns plan eligibility and source routing:

```ocaml
val fold_source :
  input_delivery:input_delivery ->
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  init:'a ->
  f:('a -> Json.t -> 'a) ->
  t ->
  Json.Input.source ->
  'a fold_result
```

The first private plan analysis identifies only these cuts:

```ocaml
type stream_cut =
  | Root_items of plan
  | Member_items of string * plan
```

The plan in each cut runs against one complete child. The cut is derived from
the compiled plan. A separate eligibility Boolean must not duplicate this fact.

`Json.Input` receives a narrow structural request, not an AST or execution plan:

```ocaml
type item_location =
  | Root
  | Member of string

type 'a step =
  | Continue of 'a
  | Validate_rest of 'a

type 'a items_result =
  | Folded of 'a
  | Materialized of selection

val fold_items :
  at:item_location ->
  init:'a ->
  f:('a -> t -> 'a step) ->
  source ->
  ('a items_result, string) result
```

`fold_items` delivers complete immediate array elements or object values in
source order. It returns `Materialized` without prior item callbacks when the
requested structure is absent or unsuitable. Success still means that the
complete document and EOF passed validation.

### Module map

| Module | Responsibility |
|---|---|
| CLI | Select atomic or early delivery; frame and flush output |
| Core | Parse, preserve debug policy, render, and map terminal results |
| Execution | Choose backend, derive stream cuts, route sources, and execute each item |
| Json.Input | Parse requested items, validate discarded input, and own source cleanup |
| Runtime | Preserve value operations and diagnostics |
| Interpreter | Preserve whole-input fallback |

The live call chain remains short:

```text
CLI -> Core.run_input_iter -> Execution.fold_source -> Json.Input.fold_items
                                               \-> compiled item executor
```

### Routing policy

| Policy and plan | Path |
|---|---|
| `After_validation` | Existing `load` then `fold_loaded` |
| `When_ready` with a proven cut | Item fold and residual compiled execution |
| `When_ready` without a cut | Existing validated path |
| Interpreter fallback | Whole-input validation then `Interpreter.fold` |
| `debug=true` in the first slice | Existing validated path |

Each item must be fully parsed and its boundary validated before execution.
Execution must drain all outputs for one item before the reader advances to the
next item.

`Materialized (Whole value)` executes the original prepared query.
`Materialized (Selected value)` executes iteration followed by the cut residual
on the selected scalar. This preserves iteration errors even when the residual
would emit nothing. Neither path retries or reparses the source.

### Barrier classification

A materialization barrier means that a complete value or result collection is
required before the next operation can proceed. Barrier scope matters. A local
barrier after an item cut does not force whole-document retention.

| Query shape | First event-input treatment |
|---|---|
| `.[]` | Stream complete root children |
| `.rows[] \| .name` | Stream complete `rows` children |
| `.rows[] \| select(.active)` | Stream complete `rows` children |
| `.rows[] \| [.a, .b]` | Stream children; collect one local output per child |
| `.rows[] \| map(.id)` | Stream children; materialize within each complete child |
| `[.rows[]]` | Validate and materialize input first |
| `.rows \| map(.id) \| .[]` | Validate and materialize selected value first |
| `.rows[-1]` | Validate and materialize the selected array first |
| `.rows[], .rows[]` | Validate first because branch order requires replay |
| Unsupported expression | Whole-input interpreted fallback |

Do not rewrite `map(f) | .[]` as `.[] | f`. A collection hides partial results
when a later item fails. The rewrite would change visible output.

### Errors and source lifetime

The live source fold must enforce these rules:

- Early results do not imply successful input validation.
- A malformed tail can follow earlier output in `When_ready` mode.
- A query failure stops result callbacks.
- The first policy saves a query failure and validates the remaining
  input. A later input error wins. Otherwise the saved query error returns.
- Callback exceptions abort immediately and escape unchanged.
- Parser error conversion must not surround callback execution.
- Owned files close on success, input error, query error, and callback exception.
- Borrowed channels remain open, but their position after interruption is not
  guaranteed because the parser can read ahead.
- No failure can restart the source or select interpreter fallback.

Continuing validation after a query failure preserves current input-error
precedence, but it can wait indefinitely for an open input producer. This
tradeoff is accepted for the first slice.

### Synthesis decision

Three independent design runners explored a minimal fold seam, a recursive
structural request, and an unchanged CLI-first interface. The runners did not
provide model diversity.

The selected design uses the minimal fold seam as its base because it gives
callers high leverage through one policy and one source fold. It adopts the
CLI simplicity of the CLI-first candidate and the scope-local barrier analysis
from the recursive candidate. It keeps nested structural events and public plan
analysis out of the first slice because no current caller needs them.

### Tradeoffs accepted

- We accept complete item allocation in exchange for existing value semantics
  and diagnostics.
- We accept conservative cut recognition in exchange for a small correctness
  proof.
- We accept delayed output for barriers and fallback in exchange for unchanged
  behavior.
- We accept retaining root fields before a selected member in exchange for
  exact missing-key diagnostics.
- We accept validation after early output in exchange for detecting malformed
  tails.

### Alternatives considered

**Change `Core.run_input_iter` for every caller.** This has the smallest type
change, but it silently weakens the documented validation-before-callback
contract for external OCaml callers.

**Expose a public pull cursor.** This makes callers responsible for abandonment,
EOF validation, and source cleanup.

**Expose general JSON parser events.** This moves parser nesting and validation
details into Execution and requires a second evaluator.

**Use recursive structural requests now.** This supports nested iteration, but
it enlarges the reader interface before the root and leading-member cuts prove
their value.

**Put lazy containers in `Json.t`.** This spreads single-use source lifetime and
replay constraints through Runtime and the interpreter.

**Replay or spool every input.** This can support more branch shapes, but it adds
unbounded memory or temporary-storage policy before measurements require it.

## Open questions and risks

- Is root iteration plus one leading root-member iteration sufficient for the
  first event slice?
- Can diagnostics continue to retain large object prefixes, or will future work
  need bounded diagnostic summaries?
- Compiled plans cannot currently halt. A future compiled halt must use the same
  saved-terminal-state drain policy as a query failure.
- CLI errors currently share stdout with results. Should a separate change move
  errors to stderr and return a failure status before event input ships?

## Implementation sequence

1. Add pure stream-cut analysis to `Execution` and test eligible, barrier, and
   fallback plans without changing source reading.
2. Add `Json.Input.fold_items` reader tests for pre-EOF delivery, malformed
   tails, duplicates, scalar boundaries, callbacks, and source ownership.
3. Add `Execution.fold_source` and compare each eligible result and error with
   the validated path.
4. Add optional `input_delivery` to `Core.run_input_iter` and pass `When_ready`
   only from CLI `--stream-output`.
5. Add a pipe-controlled Cram test that withholds EOF and observes both residual
   outputs for the first child before it sends the tail.
6. Benchmark first-result latency and allocation volume. Measure peak RSS in
   separate repeated fresh-process runs.

## Verification boundary

The event-input stage is complete only when these checks pass:

- Default calls still produce no callback or debug output before valid EOF.
- Eligible `When_ready` calls emit while the producer withholds EOF.
- Malformed tails fail after any already emitted prefix.
- Barriers and fallback remain validation-first.
- Results, order, errors, numeric representations, and duplicate behavior match
  validated execution.
- Callback exception identity and source cleanup match existing contracts.
- Prepared plans and loaded inputs remain reusable.
- Release build, full tests, format checks, JavaScript smoke checks, benchmarks,
  and `git diff --check` pass on the final tree.

## Current implementation references

- `source/Execution.ml` and `source/Execution.mli`
- `source/Runtime.ml` and `source/Runtime.mli`
- `source/Interpreter.ml` and `source/Interpreter.mli`
- `source/Core.ml` and `source/Core.mli`
- `source/jotason/Read.mll` and `source/jotason/Read.mli`
- `source/test/Test_execution.ml`
- `source/jotason/test/Test_read.ml`
- `cli/cli.ml`, `cli/test/basic.t`, `cli/test/source.t`, and `cli/test/stream_probe.ml`
- `benchmarks/bench_execution.ml` and `benchmarks/README.md`
