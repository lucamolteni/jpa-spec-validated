import VersoManual
import Lifecycle.Proofs

open Verso.Code.External
open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option veil.smt.trust false
set_option verso.code.warnLineLength 200

#doc (Manual) "Formalization addition: proof trust audit" =>
%%%
tag := "lifecycle-audit"
number := false
%%%

The last check asks what assumptions our proofs depend on. An axiom is a
statement accepted without a proof. We allow only three standard Lean axioms:

- {lit}`propext`: logically equivalent propositions are equal.
- {lit}`Classical.choice`: a value can be selected from any nonempty type.
- {lit}`Quot.sound`: equivalent elements represent the same value in a quotient
  type, a type that treats those elements as equal.

The command {lit}`run_cmd` runs the following audit while Lean builds this
chapter. It first checks that the three main results exist as theorems. It then
visits every theorem in the {lit}`EntityLifecycle` namespace and uses
{lit}`collectAxioms` to find its dependencies. Any axiom outside the allowed list
fails the build through {lit}`throwError`.

This also rejects unfinished proofs and unchecked solver answers, which would
introduce additional axioms. The executable checks in the previous chapter
provide separate evidence about the finite model; they are not used as proofs
of the general theorems.

```lean
open Lean in
run_cmd do
  let allowed := [``propext, ``Classical.choice, ``Quot.sound]
  let required := [``EntityLifecycle.ELCorrect, ``EntityLifecycle.ELDetachedCorrect,
    ``EntityLifecycle.ELMergeSourceUnchanged]
  for name in required do
    unless (← getConstInfo name).isTheorem do
      throwError "Missing checked theorem: {name}"
  let mut count : Nat := 0
  for (name, info) in (← getEnv).constants.toList do
    if (`EntityLifecycle).isPrefixOf name && info.isTheorem then
      count := count + 1
      for axiomName in ← collectAxioms name do
        unless allowed.contains axiomName do
          throwError "Unapproved axiom in {name}: {axiomName}"
  logInfo m!"Audited {count} model theorems: only propext, Classical.choice, Quot.sound allowed."

```

We also print the axiom dependencies of the consistency theorem. The command
{lit}`#print axioms` reports the axioms used by a theorem, including those used
indirectly through other theorems.

```lean
#print axioms EntityLifecycle.ELCorrect
```

The next command reports the dependencies of the theorem that a detached
instance stays detached after each step.

```lean
#print axioms EntityLifecycle.ELDetachedCorrect
```

Finally, we report the dependencies of the theorem that merge preserves its
source's lifecycle state and identity and returns a distinct target for a new
or detached source.

```lean
#print axioms EntityLifecycle.ELMergeSourceUnchanged
```
