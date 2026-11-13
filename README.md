# Jakarta Persistence entity lifecycle, modeled and proved in TLA+

A small mathematical model of the entity lifecycle in one persistence context, based on [Jakarta Persistence 4.0-M4, section 3.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a1060). It includes an annotated specification, executable model-checking scenarios, and a proof checked by the TLA+ Proof System (TLAPS).

The model describes `persist`, `remove`, `detach`, `refresh`, and `merge`. It distinguishes a Java object's identity from its persistent identity, so a detached object and its managed copy can represent the same database record.

## What this project does

TLA+ describes a system as a sequence of snapshots and rules for moving between them. Here, each snapshot records which objects exist, their lifecycle states, and their persistent identities. An operation describes an allowed transition between two snapshots.

| Entity state | Persistent identity | Associated with this context | Removal pending |
| --- | --- | --- | --- |
| New | No | No | No |
| Managed | Yes | Yes | No |
| Detached | Yes | No | No |
| Removed | Yes | Yes | Yes |

For example, merging a detached object representing `Customer/42` returns a different, managed object representing `Customer/42`. The original object remains detached. Merging it again can return the same managed target.

There are two ways to verify the model:

- **TLC model checking:** explore all reachable snapshots for specific, finite sets of objects and identities, looking for a violation of the stated properties.
- **TLAPS proof checking:** check an inductive argument that the properties hold for any sets satisfying the model's assumptions. First establish the rules initially, then show that every allowed operation preserves them.

Neither tool runs Java code or connects to a database. Verification applies to the mathematical model; it does not certify a persistence provider or establish full Jakarta Persistence conformance.

## Files and reading order

| File | Purpose |
| --- | --- |
| [EntityLifecycle.tla](EntityLifecycle.tla) | The model, with a notation guide and explanations of the data, rules, and operations. Start here. |
| [EntityLifecycle_proof.tla](EntityLifecycle_proof.tla) | The inductive proof, with explanations of each claim and the proof notation. |
| [EntityLifecycle.cfg](EntityLifecycle.cfg) | TLC settings for three object slots and two persistent identities. |
| [EntityLifecycleScenarios.tla](EntityLifecycleScenarios.tla) | A 17-operation sequence exercising lifecycle changes, ignored calls, and merge behavior. |
| [EntityLifecycleScenarios.cfg](EntityLifecycleScenarios.cfg) | TLC settings for the scenario checks. |

## Properties established

The proof establishes three main claims:

1. **Consistency always holds (`ELCorrect`).** Objects have permitted states and identities. An allocated object has no persistent identity exactly when it is new. Two different objects associated with the context cannot have the same persistent identity; this includes objects marked for removal.
2. **Detached objects stay detached (`ELDetachedCorrect`).** Within the modeled operations, a detached source never becomes managed itself, including when passed to merge.
3. **Merge preserves its source (`ELMergeSourceUnchanged`).** Merge leaves the source's lifecycle state and persistent identity unchanged. For a new or detached source, the returned target is a different object.

The scenario checks exercise persist–remove–persist, detachment, cancellation of pending removal, merge of a new source, merge of a detached source into both a fresh and an existing managed target, and specified no-op cases. The test driver requires the sequence to finish, so an accidentally disabled operation cannot make the checks pass without being exercised.

## Run the checks

Run the following commands from the repository root. You need Java for TLC, and a separate TLAPS installation for the proof.

### Model checking with TLC

Download the official [TLA+ tools](https://github.com/tlaplus/tlaplus/releases/tag/v1.8.0) into the ignored `.tools` directory:

```sh
mkdir -p .tools
curl -fL https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar \
  -o .tools/tla2tools.jar
```

Check the lifecycle model and then the scenario:

```sh
java -XX:+UseParallelGC -Xmx512m -cp .tools/tla2tools.jar tlc2.TLC EntityLifecycle
java -XX:+UseParallelGC -Xmx512m -cp .tools/tla2tools.jar tlc2.TLC EntityLifecycleScenarios
```

Both commands should report `Model checking completed. No error has been found.` TLC stores generated data under `states/`, which is ignored by Git. Change the constant sets in the configuration files to explore other model sizes; the scenario configuration assumes exactly three object slots and two identities.

### Proof checking with TLAPS

Install TLAPS using the [official installation instructions](https://github.com/tlaplus/tlapm#installation--use) and put its `bin` directory on your `PATH`. The verified build came from the [1.6.0-pre release](https://github.com/tlaplus/tlapm/releases/tag/1.6.0-pre).

```sh
tlapm --strict --nofp EntityLifecycle_proof.tla
```

`--strict` treats failed or incomplete proofs as errors. `--nofp` disables reuse of cached proof results. TLAPS should report `All 93 obligations proved.` An obligation is a logical subproblem generated from the proof, not a test case or an execution sequence. Generated proof data under `.tlacache/` is ignored by Git.

### Verification record

Checked on November 13, 2026:

| Check | Result |
| --- | --- |
| Lifecycle model | 352 distinct reachable states; 2,707 generated; no errors |
| Scenario | 32 distinct states; all 17 operations reached; no errors |
| Proof | All 93 obligations proved, with proof-cache reuse disabled |

Tools used: Java 25.0.2; TLC build `2026.11.06.222357` (`d8fb231`, v1.8.0 prerelease); TLAPS `ff40755` (1.6.0-pre), with bundled Z3 4.8.9, Zenon, and LS4 backends. Prerelease downloads may change; these identifiers record the builds used for the results above.

## Model boundaries

The model covers successful lifecycle effects in one persistence context. It leaves out entity field values, database contents, transactions, exception timing, cascading, versions, concurrent access, and context closure. Refresh therefore leaves the modeled snapshot unchanged; flush and lock have no modeled actions. Removed objects are marked as pending removal, without modeling the eventual database deletion.

Object slots and identities are finite resources. Creating an object or a managed copy needs an unused slot; assigning a new persistent identity needs an unused identity. Exhaustion disables the corresponding action and does not represent a JPA exception. Identity assignment is atomic and identities are never reused.

Merging a detached source whose identity is represented by a removed object in the context is excluded from the successful-operation subset. The model also does not track the portability restriction on reusing a removed object after detachment.

The claims concern safety: which states and transitions are permitted. The lifecycle specification allows executions to pause indefinitely and does not require an eventual flush or commit. Only the scenario driver adds a progress requirement to ensure its prescribed operations are exercised.

## References

- [Jakarta Persistence 4.0-M4: Entity Instance Lifecycle](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a1060) supplies the lifecycle rules and referenced operation semantics.
- [TwoPhase.tla](https://github.com/tlaplus/Examples/blob/master/specifications/transaction_commit/TwoPhase.tla) inspired the specification's organization.
- [TCommit_proof.tla](https://github.com/tlaplus/Examples/blob/master/specifications/transaction_commit/TCommit_proof.tla) inspired the inductive proof structure.
