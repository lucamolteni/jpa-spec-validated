import VersoManual
import Lifecycle.Model

open Verso.Code.External
open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option veil.smt.trust false
set_option verso.code.warnLineLength 200

#doc (Manual) "Formalization addition: guarantees for complete executions" =>
%%%
tag := "lifecycle-proofs"
number := false
%%%

The lifecycle chapter proved that initialization establishes the three
consistency conditions and that each operation preserves them. We now use
those results to prove properties of entire executions: sequences of states
connected by allowed operations.

We reopen the {lit}`EntityLifecycle` namespace so these theorems belong to the
same model. The {lit}`open` commands make the library names and model notation
available in the code below.

```lean
namespace EntityLifecycle
open Veil Classical
open scoped EntityLifecycle
```

The abbreviation {lit}`Snapshot` names the model's state type for entity type
{lit}`E` and identity type {lit}`I`. An {lit}`abbrev` gives an existing expression
a shorter name. The generated type {lit}`phase_IndT` represents our four
lifecycle states.

```lean
abbrev Snapshot (E I : Type) := State (FieldAbstractType E I phase_IndT)
```

The abbreviation {lit}`Background` names the fixed information for an execution,
including the chosen value of {lit}`noIdentity`. Veil calls this information
the model's {lit}`Theory`.

```lean
abbrev Background (E I : Type) := Theory E I phase_IndT
```

The proofs use arbitrary entity and identity types. The square-bracketed
requirements supply equality decisions ({lit}`DecidableEq`) and a default value
({lit}`Inhabited`) for each type. A default value also ensures the type is
nonempty. No bound on the number of values is required.

```lean
variable {E I : Type} [DecidableEq E] [Inhabited E] [DecidableEq I] [Inhabited I]
```

The proposition {lit}`Inv th s` says that state {lit}`s` satisfies all three
consistency conditions under background information {lit}`th`. The result type
{lit}`Prop` means this is a statement to prove. Underscores in the expression
let Lean infer arguments from their context.

```lean
abbrev Inv (th : Background E I) (s : Snapshot E I) : Prop :=
  Invariants _ _ E I phase_IndT _ th s
```

The proposition {lit}`Assumes th` collects the model's assumptions. In our
model, this requires an identity value other than {lit}`noIdentity`.

```lean
abbrev Assumes (th : Background E I) : Prop := Assumptions _ E I phase_IndT th
```

An execution is a function from natural numbers to snapshots: {lit}`execution 0`
is its initial state, and {lit}`execution (n + 1)` follows {lit}`execution n`.
We define {lit}`ELSpec` to require initialization and, at each step, either an
unchanged state or a transition described by one of the model's actions.
{lit}`Init` and {lit}`NextStep` are the definitions generated from those actions.

This definition does not assume consistency; we will prove it. The
{lit}`noncomputable` keyword allows us to use the logical transition definitions
without requiring an algorithm to decide whether an infinite execution
satisfies them.

```lean
noncomputable def ELSpec (th : Background E I) (execution : Nat → Snapshot E I) : Prop :=
  Init _ _ E I phase_IndT _ th (execution 0) ∧
  ∀ n, execution (n + 1) = execution n ∨ NextStep _ _ E I phase_IndT _ th (execution n) (execution (n + 1))
```

An execution may remain unchanged indefinitely. These theorems therefore do
not promise that an operation eventually occurs. Database flush and transaction
commit remain outside the model.

Our first theorem combines the three initialization proofs into {lit}`Inv`.
The arguments {lit}`ha` and {lit}`hi` are proofs of the assumptions and
initialization conditions. The tactic {lit}`exact` supplies the required proof;
the angle brackets group the proofs of the three conditions together.

```lean
theorem InitialInvariant (th : Background E I) (s : Snapshot E I)
    (ha : Assumes th) (hi : Init _ _ E I phase_IndT _ th s) : Inv th s := by
  exact ⟨initializer_identityOK_tr _ _ E I phase_IndT _ th default s ⟨ha, trivial⟩ hi,
    initializer_uncreatedOK_tr _ _ E I phase_IndT _ th default s ⟨ha, trivial⟩ hi,
    initializer_uniqueIdentity_tr _ _ E I phase_IndT _ th default s ⟨ha, trivial⟩ hi⟩
```

Next, we prove that one allowed operation preserves consistency. The arguments
describe a consistent starting state {lit}`s` and an allowed transition to
{lit}`t`. The proof extracts the operation's label with {lit}`rcases` and then
uses {lit}`cases` to consider each possible action. Each branch combines that
action's three preservation proofs from the lifecycle chapter.

```lean
theorem LifecycleStep (th : Background E I) (s t : Snapshot E I)
    (ha : Assumes th) (hs : Inv th s)
    (hn : NextStep _ _ E I phase_IndT _ th s t) : Inv th t := by
  rcases hn with ⟨label, ht⟩
  cases label with
  | Create e =>
    exact ⟨Create_identityOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Create_uncreatedOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Create_uniqueIdentity_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht⟩
  | Persist e =>
    exact ⟨Persist_identityOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Persist_uncreatedOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Persist_uniqueIdentity_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht⟩
  | Remove e =>
    exact ⟨Remove_identityOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Remove_uncreatedOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Remove_uniqueIdentity_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht⟩
  | Refresh e =>
    exact ⟨Refresh_identityOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Refresh_uncreatedOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Refresh_uniqueIdentity_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht⟩
  | Detach e =>
    exact ⟨Detach_identityOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Detach_uncreatedOK_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht,
      Detach_uniqueIdentity_tr _ _ E I phase_IndT _ e th s t ⟨ha, hs⟩ ht⟩
  | Merge e target =>
    exact ⟨Merge_identityOK_tr _ _ E I phase_IndT _ e target th s t ⟨ha, hs⟩ ht,
      Merge_uncreatedOK_tr _ _ E I phase_IndT _ e target th s t ⟨ha, hs⟩ ht,
      Merge_uniqueIdentity_tr _ _ E I phase_IndT _ e target th s t ⟨ha, hs⟩ ht⟩

```

We can now prove consistency at every position in an execution. Induction
starts at position zero, where {lit}`InitialInvariant` applies. At each next
position, either the state is unchanged or {lit}`LifecycleStep` preserves the
conditions. The notation {lit}`∀ n` makes the result apply to every position.

```lean
/-- Consistency holds at every time in every allowed execution. -/
theorem ELCorrect (th : Background E I) (execution : Nat → Snapshot E I)
    (ha : Assumes th) (h : ELSpec th execution) : ∀ n, Inv th (execution n) := by
  intro n
  induction n with
  | zero => exact InitialInvariant th (execution 0) ha h.1
  | succ n ih =>
    rcases h.2 n with heq | hnext
    · simpa only [heq] using ih
    · exact LifecycleStep th (execution n) (execution (n + 1)) ha ih hnext

```

Merge preserves the source's lifecycle state and persistent identity. If the
source is new or detached, it also returns a different Java object. In the
statement below, {lit}`s` and {lit}`t` are the states before and after the call,
and {lit}`Merge.ext.tr` is the transition relation generated from our action.

The proof expands that relation and the derived conditions with {lit}`dsimp`,
simplifies the generated state operations with {lit}`simp` and {lit}`veil_simp`,
and lets {lit}`grind` establish the result. This proves the claim about the
action already defined in the chapter.

```lean
/-- A successful merge preserves the source's two modeled attributes. -/
theorem ELMergeSourceUnchanged (th : Background E I) (s t : Snapshot E I)
    (e target : E) (_hs : Inv th s)
    (hm : Merge.ext.tr _ _ E I phase_IndT _ e target th s t) :
    t.e_phase e = s.e_phase e ∧ t.pid e = s.pid e ∧
      (s.e_phase e = .new ∨ s.e_phase e = .detached → target ≠ e) := by
  dsimp [Merge.ext.tr, belongsToContext, fresh] at hm
  dsimp [FieldRepresentation.get, FieldRepresentation.setSingle, getFrom, setIn, readFrom] at hm
  simp only [CanonicalField.set, FieldUpdatePat.match, IteratedArrow.curry,
    IteratedArrow.uncurry, IteratedProd.patCmp] at hm
  dsimp at hm
  veil_simp +instances only [smtSimp] at hm
  simp only [phase_EnumClass.new, phase_EnumClass.managed, phase_EnumClass.detached,
    phase_EnumClass.removed] at hm
  grind

```

A created instance that is already detached remains detached after any allowed
operation. In particular, merge creates or returns a managed target while
leaving the detached source as it is. We first prove this for a single step.
The proof considers each action and simplifies its transition definition.

```lean
/-- Every allowed operation preserves an already-created detached entity. -/
theorem DetachedStep (th : Background E I) (s t : Snapshot E I)
    (hn : NextStep _ _ E I phase_IndT _ th s t)
    (e : E) (hc : s.created e = true) (hd : s.e_phase e = .detached) :
    t.e_phase e = .detached := by
  rcases hn with ⟨label, ht⟩
  cases label <;>
    (try dsimp [NextTr, Create.ext.tr, Persist.ext.tr, Remove.ext.tr, Refresh.ext.tr,
      Detach.ext.tr, Merge.ext.tr, belongsToContext, fresh] at ht) <;>
    (try dsimp [FieldRepresentation.get, FieldRepresentation.setSingle, getFrom, setIn, readFrom] at ht) <;>
    (try simp only [CanonicalField.set, FieldUpdatePat.match, IteratedArrow.curry,
      IteratedArrow.uncurry, IteratedProd.patCmp] at ht) <;>
    (try dsimp at ht) <;>
    (try veil_simp +instances only [smtSimp] at ht) <;>
    (try simp only [phase_EnumClass.new, phase_EnumClass.managed, phase_EnumClass.detached,
      phase_EnumClass.removed] at ht) <;>
    grind
```

We extend the single-step result to every adjacent pair of execution states.
If the state is unchanged, the instance is still detached; otherwise,
{lit}`DetachedStep` supplies the result for the operation that occurred.

```lean
/-- The original always/next detached-state contract, including stuttering. -/
theorem ELDetachedCorrect (th : Background E I) (execution : Nat → Snapshot E I)
    (h : ELSpec th execution) :
    ∀ n e, (execution n).created e = true → (execution n).e_phase e = .detached →
      (execution (n + 1)).e_phase e = .detached := by
  intro n e hc hd
  rcases h.2 n with heq | hn
  · simpa only [heq] using hd
  · exact DetachedStep th (execution n) (execution (n + 1)) hn e hc hd
```

The execution theorems are complete, so we close their namespace.

```lean
end EntityLifecycle
```
