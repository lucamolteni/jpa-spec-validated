import VersoManual
import Lifecycle.Model

open Verso.Code.External
open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option veil.smt.trust false
set_option verso.code.warnLineLength 200

#doc (Manual) "Guarantees for complete executions" =>
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

Consider one of those steps. Two books have been constructed. Book {lit}`a`
is marked for removal and still occupies identity 7 in the context. Book
{lit}`b` is new. Suppose the available identities are 8 and 9. Which next
states can {lit}`persist(b)` produce?

```diagram (cssWidth := "min(100%, 35em)")
open Illuminate Diagram in
let snapshot := fun name phase =>
  namedWithAnchors name (frame (vsep 6 [text "a   removed · ID 7", text phase { bold := true }] .left)
    (padding := 10) (cornerRadius := 4))
let before := snapshot `before "b   new · no ID"
let outcomes := vsep 18 [snapshot `eight "b   managed · ID 8", snapshot `nine "b   managed · ID 9"]
hsep 62 [before, outcomes]
  |>.connectEdge `before.east { point := `eight.west, arrowhead := some {} }
  |>.connectEdge `before.east { point := `nine.west, arrowhead := some {} }
```

Each arrow is one possible result of the same call. Identity 7 is excluded
because {lit}`a` still has it. The preservation proof covers every choice
that {lit}`identityAvailable` permits, including both branches shown here.

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

Suppose a detached book and a managed book both represent ID 7. What does
{lit}`result = merge(a)` return if {lit}`b` already refers to the managed book?

```diagram (cssWidth := "min(100%, 31em)")
open Illuminate Diagram in
let refLabel := fun name label => namedWithAnchors name (text label { bold := true })
let book := fun name phase =>
  namedWithAnchors name (frame (vsep 5 [text "Book · ID 7", text phase { bold := true }])
    (padding := 10) (cornerRadius := 4))
let source := hsep 76 [refLabel `a "a", book `detached "detached"]
let refs := vsep 16 [refLabel `b "b", refLabel `result "result"]
let target := hsep 76 [refs, book `managed "managed"]
vsep 20 [source, target] .right
  |>.connectEdge `a.east { point := `detached.west, arrowhead := some {} }
  |>.connectEdge `b.east { point := `managed.west, arrowhead := some {} }
  |>.connectEdge `result.east { point := `managed.west, arrowhead := some {} }
```

Each arrow is a Java reference. Here {lit}`result == b` and {lit}`result != a`.
The call returns the existing managed object. The argument keeps its detached
state and its identity.

The proof expands that relation and the derived conditions with {lit}`dsimp`,
simplifies the generated state operations with {lit}`simp` and {lit}`veil_simp`,
and lets {lit}`grind` establish the result. This proves the claim about the
{lit}`Merge` action defined in §3.6.9.2.

```lean
/-- A successful merge preserves the source's two modeled attributes. -/
theorem ELMergeSourceUnchanged (th : Background E I) (s t : Snapshot E I)
    (e target : E) (_hs : Inv th s)
    (hm : Merge.ext.tr _ _ E I phase_IndT _ e target th s t) :
    t.e_phase e = s.e_phase e ∧ t.pid e = s.pid e ∧
      (s.e_phase e = .new ∨ s.e_phase e = .detached → target ≠ e) := by
  dsimp [Merge.ext.tr, belongsToContext, identityAvailable] at hm
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
      Detach.ext.tr, Merge.ext.tr, belongsToContext, identityAvailable] at ht) <;>
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

Follow a book through a sequence of calls in one context. Initially {lit}`a`
is managed with ID 7. After detaching it, we merge it and use the returned
reference {lit}`b` for the remaining calls.

```diagram (cssWidth := "min(100%, 32em)")
open Illuminate Diagram in
let heading := fun label => some (text label { bold := true })
let cell := fun label => some (text label {})
grid #[
  #[heading "After the call", heading "Original (a)", heading "Copy (b)"],
  #[cell "detach(a)", cell "detached", cell "—"],
  #[cell "b = merge(a)", cell "detached", cell "managed"],
  #[cell "remove(b)", cell "detached", cell "removed"],
  #[cell "persist(b)", cell "detached", cell "managed"]
] (hSpacing := 24) (vSpacing := 12)
```

Removing the copy and then cancelling its removal both change {lit}`b`.
Read down the middle column to see what the detached-state theorem guarantees
about {lit}`a` across those same steps.

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

What would {lit}`em.contains(book)` return immediately after a lifecycle call?
In the Jakarta Persistence 4.0-M4 TCK, {lit}`persistBasicTest1` expects false
for a newly constructed object. {lit}`removeBasicTest3` checks for true after
persist, and {lit}`removeBasicTest5` expects false immediately after removal.
These are observations an application can make within one context, before
commit. See the [new object check](https://github.com/jakartaee/persistence/blob/4.0.0-M4/tck/spec-tests/src/main/java/ee/jakarta/tck/persistence/core/entitytest/persist/basic/Client.java#L82-L96),
[persist check](https://github.com/jakartaee/persistence/blob/4.0.0-M4/tck/spec-tests/src/main/java/ee/jakarta/tck/persistence/core/entitytest/remove/basic/Client.java#L162-L173),
and [remove check](https://github.com/jakartaee/persistence/blob/4.0.0-M4/tck/spec-tests/src/main/java/ee/jakarta/tck/persistence/core/entitytest/remove/basic/Client.java#L283-L299).

We can prove the answer for every successful modeled action and every object
{lit}`e` we might ask about. Persist makes its argument managed. Merge makes
its returned target managed. Create, remove, and detach leave their argument
outside the set reported by {lit}`contains()`. Refresh preserves the answer.
For other objects the previous answer continues to hold. In particular, asking
about a detached source after merge still gives false even when asking about
its managed copy gives true.

In the statement, {lit}`call` names the operation and its arguments.
{lit}`NextTr` says this particular call takes the model from {lit}`s` to
{lit}`t`. The {lit}`match` expression selects the rule for that operation.

```lean
theorem ELContainsAfterCall (th : Background E I) (s t : Snapshot E I)
    (call : Label E I phase_IndT) (e : E)
    (step : NextTr _ _ E I phase_IndT _ th s call t) :
    entityManagerContains e th t ↔
      match call with
      | .Persist a | .Merge _ a => e = a ∨ entityManagerContains e th s
      | .Create a | .Remove a | .Detach a => e ≠ a ∧ entityManagerContains e th s
      | .Refresh _ => entityManagerContains e th s := by
  cases call <;>
    dsimp [NextTr, Create.ext.tr, Persist.ext.tr, Remove.ext.tr, Refresh.ext.tr,
      Detach.ext.tr, Merge.ext.tr, belongsToContext, identityAvailable] at step <;>
    (try dsimp [FieldRepresentation.get, FieldRepresentation.setSingle, getFrom, setIn, readFrom] at step) <;>
    (try simp only [CanonicalField.set, FieldUpdatePat.match, IteratedArrow.curry,
      IteratedArrow.uncurry, IteratedProd.patCmp] at step) <;>
    (try dsimp at step) <;>
    (try veil_simp +instances only [smtSimp] at step) <;>
    dsimp [entityManagerContains, FieldRepresentation.get, getFrom] <;>
    simp only [phase_EnumClass.new, phase_EnumClass.managed, phase_EnumClass.detached,
      phase_EnumClass.removed] at step ⊢
  case Persist a _ => cases h : s.e_phase a <;> grind
  case Merge a _ _ => cases h : s.e_phase a <;> grind
  all_goals grind
```

We close the namespace after the action and execution proofs.

```lean
end EntityLifecycle
```
