# Jakarta Persistence lifecycle, formalized in Lean and Veil

A literate, executable model of one persistence context, alongside selected
sections of **Jakarta Persistence 4.0-M4**. Sections **§2.1** and **§2.4**
introduce the types for entity instances and persistent identities. The excerpts
from **§3.6** cover lifecycle states, construction, persist, remove, refresh,
detach, merge, and identity uniqueness. Each excerpt keeps its original wording,
number, references, and footnotes.
Clearly labelled *Formalized Specification* passages and checked Lean/Veil code
explain the mathematical interpretation. Each chapter is a prose-first Verso
Manual document: ordinary prose follows `#doc (Manual)`, and `lean` code fences
contain the actual checked implementation. Later blocks and importing chapters
use those same declarations; there is no separate copy of the code for display.

Start with [the lifecycle chapter](Lifecycle/Model.lean). Its source is
[Jakarta Persistence 4.0-M4, May 25, 2026 (DRAFT)](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a1929),
authored by the Jakarta Persistence Team. This is documentation of a mathematical
model, not a replacement technical specification. The opening credits identify the source and authors. The complete
Eclipse Foundation Specification License v1.1 closes the book and is also saved
in [the pinned source notice](spec/notice.html).

## Build and read

Install [Elan](https://github.com/leanprover/elan), Git, Python 3, and a C/C++ toolchain
(Xcode Command Line Tools on macOS; Clang and libc++ development libraries on Linux).
The first build downloads dependencies and solver libraries and takes longer.
Lean **4.35.0**, Veil, Verso, and every transitive dependency are pinned by
[lean-toolchain](lean-toolchain), [lakefile.lean](lakefile.lean), and
[lake-manifest.json](lake-manifest.json). Keep the manifest; `lake update` is only
needed when deliberately changing dependency versions.

From the repository root:

```sh
lake build                            # Model, proofs, axiom audit, finite Veil check
lake env lean --run Lifecycle/Checks.lean  # Exact graphs and 17-operation scenario
lake exe generate-book                # Generate the complete single-page book
```

Run the Lean build and model checks with `sh scripts/check.sh`. Generate HTML
separately with `lake exe generate-book`, or use the live preview below. HTML is
generated under `.lake/build/book/html-single/`; open its `index.html`. The
document includes the chapter, execution proofs, finite checks, and trust audit.
No publication or upstream fork is part of this repository change.

[Lifecycle.lean](Lifecycle.lean) assembles the four Manual documents.
[Main.lean](Main.lean) uses Verso's `manualMain` to render the compiled book;
it promotes the model's chapters into the book's table of contents and loads
the document separately so the finite checker's existing `main` entry
point remains available. `specBoundary` commands mark original passages for
on-demand HTML review, and `formalization` directives visibly distinguish project
commentary. These markers do not duplicate the specification or implementation.

## Live preview

Run the preview once, then leave it running while editing:

```sh
./preview.sh
```

Open <http://127.0.0.1:8000/>. Saving a Lean source file in the project root or
under `Lifecycle/`, or changing the dependency manifest or toolchain, automatically
rebuilds the book and refreshes the browser. Build errors appear in the terminal;
the last successful page remains available until a build succeeds. Press Ctrl+C
to stop. The launcher also works from another directory, and `python3 preview.py`
can be used directly.

## Proved guarantees

[Lifecycle/Proofs.lean](Lifecycle/Proofs.lean) establishes three named theorems from
the **same Veil actions** that are executed by the finite checks:

| Theorem | Guarantee |
| --- | --- |
| `ELCorrect` | Every state of every initialized execution is consistent: new iff no identity, uncreated slots retain their defaults, and context members have unique persistent identities. |
| `ELDetachedCorrect` | Each allowed transition, including stuttering, preserves the detached state of every already-created detached instance. |
| `ELMergeSourceUnchanged` | A successful merge leaves its source's lifecycle state and persistent identity unchanged; a new or detached source differs from its returned target. |

`ELSpec` assumes initialization and allowed steps, **not** the invariant. Its
consistency proof uses induction over execution time and the checked initialization
and action preservation lemmas. Lean's types enforce the former typing invariant.
A Java instance and its persistent identity are separate: a detached source and
its managed copy may represent the same database record.

`veil.smt.trust` is disabled in the build and formalization. Veil's `grind` backend
and explicit Lean proofs produce kernel-checked proof terms while Verso elaborates
the code fences. There are no unfinished proofs.
[The audit](Lifecycle/Audit.lean) checks every model theorem and rejects axioms
other than Lean's standard `propext`, `Classical.choice`, and `Quot.sound`, including
trusted solver results and compiler-based proof shortcuts. All three main theorems
use only those three standard axioms. Executable model checks are separate
regression evidence, not substitutes for kernel-checked proofs.

## Scenarios and migration evidence

[The finite checks](Lifecycle/Checks.lean) execute the current Veil model with
three entities and two persistent identities (plus the no-identity marker).
`sh scripts/check.sh` builds the proofs and runs the trust audit on their axiom
dependencies. It then runs the finite checker, which reads the four state and
edge files in [verification/](verification/) and compares them with the graphs
computed by Veil. A missing or extra state or transition fails the check. The
driver also checks consistency, detached preservation, merge-source preservation,
and excluded calls.

The scenario reproduces all 17 operations, including ignored calls, cancellation
of removal, and merge into fresh and existing targets. Every prefix must enable
its next prescribed call for **every** identity choice. Both identity assignments
must finish; a disabled operation fails the check. All original assertions are
retained. This finite driver checks progress by exhausting a strictly advancing
17-step sequence; under the original driver's weak fairness this is the same
completion requirement. It adds no fairness to the lifecycle model.

Validation during migration on November 23, 2026:

| Check | Result |
| --- | --- |
| Original TLC lifecycle | 352 states; 2,707 generated; no errors |
| Original TLC scenario | 32 states; all 17 operations reached; no errors |
| Original TLAPS, `--strict --nofp` | All 93 obligations proved |
| Veil lifecycle graph | All 352 states and 1,533 distinct edges match TLC |
| Veil scenario graph | All 32 states and 33 distinct edges match TLC |

[verification/migration.json](verification/migration.json) records provenance,
checksums, and interpretation differences. The original check logs and canonical
finite graphs are retained under `verification/`. The TLA+ model, proof,
configurations, and scenario are available in Git at commit `8974e1f`; they are no
longer part of the working formalization. To reproduce the migration baselines,
use [scripts/migration.py](scripts/migration.py) with the recorded TLC and TLAPS
binaries; it restores the historical files into a temporary directory.

The saved specification fragments in `spec/` provide context for an optional
[HTML review skill](.agents/skills/review-jpa-html/SKILL.md), invoked as `$review-jpa-html`.
It compares the rendered chapter with those fragments, including paragraph order,
heading levels, lists, references, and notices, and checks that the displayed Lean
code matches the source. This review runs only when explicitly requested; routine
checks and preview builds do not run it. Specification checksums are not checked.

## Scope and limitations

The model covers successful effects of construction, `persist`, `remove`,
`detach`, `refresh`, and `merge` in one context. Removed instances retain their
identity and context membership until detached; eventual database deletion is
unmodeled. `belongsToContext` includes removed instances and is not
`EntityManager.contains()`.

Fields, database contents, transactions, exception timing, cascades, orphan
removal, versions, concurrency, context closure/clear, retrieval, serialization,
and lazy/load state are unformalized. Refresh checks that the instance is managed.
The model has no actions for flush or lock.
The model neither executes Java nor certifies a provider's conformance.

Pools are fixed, nonempty, and finite in the intended model. Exhaustion disables
allocation and is not a JPA exception. Identity assignment is atomic and identities
are never reused. The Lean proofs do not need finiteness and also hold for infinite
pools; finite regression checks preserve the original bounds.

Merging a detached source whose identity is represented by a removed context
member is excluded from the successful-operation subset. The portability
restriction on reuse after detaching a removed entity is not enforced. Executions
may stutter indefinitely: no eventual flush, commit, or lifecycle call is promised.
