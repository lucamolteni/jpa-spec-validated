import VersoManual
import Lifecycle.Model

open Verso.Code.External
open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option veil.smt.trust false
set_option verso.code.warnLineLength 200

#doc (Manual) "Formalization addition: finite regression checks" =>
%%%
tag := "lifecycle-checks"
number := false
%%%

The proofs cover arbitrary entity and identity types. We also execute the
model with small finite types to check specific behaviors and compare them
with the earlier TLA+ model. All transitions come from the actions defined in
the lifecycle chapter.

We place the check definitions in the same namespace and make Veil's names
and the model's notation available.

```lean
namespace EntityLifecycle
open Veil
open scoped EntityLifecycle
```

We use three possible Java objects, identified by 0, 1, and 2. The identity
type has the same three values. {lit}`FiniteState` names the concrete state
representation for these types; {lit}`FiniteLabel` names an operation together
with its arguments, such as {lit}`Persist 0` or {lit}`Merge 0 1`.

```lean
abbrev FiniteState := State (FieldConcreteType (Fin 3) (Fin 3) phase_IndT)
abbrev FiniteLabel := Label (Fin 3) (Fin 3) phase_IndT
```

The fixed background information reserves identity 0 for {lit}`noIdentity`,
leaving identities 1 and 2 available for persistent instances.

```lean
def finiteTheory : Theory (Fin 3) (Fin 3) phase_IndT := { noIdentity := 0 }
```

Veil's {lit}`enumerableTransitionSystem` supplies the initial states and the
possible results of each action. We disable its routine logging and report
the results of our checks below.

```lean
local instance : LogSwitch := ⟨false⟩
def finiteSystem := enumerableTransitionSystem (Fin 3) (Fin 3) phase_IndT finiteTheory
```

These three accessors read an instance's construction flag, lifecycle state,
and persistent identity from the concrete state representation. Their longer
bodies connect the checks to Veil's generated storage for those values.

```lean
def createdAt (s : FiniteState) (e : Fin 3) : Bool := (instFieldRepresentation (Fin 3) (Fin 3) phase_IndT .created).get s.created e
def phaseAt (s : FiniteState) (e : Fin 3) : phase_IndT := (instFieldRepresentation (Fin 3) (Fin 3) phase_IndT .e_phase).get s.e_phase e
def pidAt (s : FiniteState) (e : Fin 3) : Fin 3 := (instFieldRepresentation (Fin 3) (Fin 3) phase_IndT .pid).get s.pid e
```

For comparison with the saved results, we assign each lifecycle state a
number. This encoding affects only how we record test results.

```lean
def phaseCode : phase_IndT → Nat
  | .new => 0 | .managed => 1 | .detached => 2 | .removed => 3
```

The function {lit}`stateKey` records all three objects in a fixed order. For
each object it writes the construction flag, encoded lifecycle state, and
identity. A semicolon separates one object's values from the next.

```lean
def stateKey (s : FiniteState) : String :=
  String.intercalate ";" ([0, 1, 2].map fun (e : Fin 3) =>
    s!"{if createdAt s e then 1 else 0},{phaseCode (phaseAt s e)},{(pidAt s e).val}")
```

The function {lit}`labelKey` gives each operation and its arguments a stable
text representation. The scenario uses these names to select the prescribed
call from the available transitions.

```lean
def labelKey : FiniteLabel → String
  | .Create e => s!"Create({e.val})"
  | .Persist e => s!"Persist({e.val})"
  | .Remove e => s!"Remove({e.val})"
  | .Refresh e => s!"Refresh({e.val})"
  | .Detach e => s!"Detach({e.val})"
  | .Merge e t => s!"Merge({e.val},{t.val})"
```

We list the three objects and define a Boolean check for context membership.
It uses the same condition as {lit}`belongsToContext`: an instance has been
created and is managed or removed. In executable Boolean expressions,
{lit}`&&` means “and,” {lit}`||` means “or,” and {lit}`==` tests equality.

```lean
def entities : List (Fin 3) := [0, 1, 2]
def inContext (s : FiniteState) (e : Fin 3) : Bool :=
  createdAt s e && (phaseAt s e == .managed || phaseAt s e == .removed)
```

The helper {lit}`ensure` stops a check with an error message when a condition
is false. The type {lit}`IO Unit` describes an executable computation with
effects, such as reporting an error, and no meaningful return value.

```lean
def ensure (ok : Bool) (message : String) : IO Unit :=
  unless ok do throw (IO.userError message)
```

For each state, we check the three consistency conditions directly: new iff
no identity, defaults for uncreated instances, and unique identities among
context members. These executable assertions check the finite results;
the general proofs remain in the preceding chapters.

```lean
def checkState (s : FiniteState) : IO Unit := do
  for e in entities do
    ensure ((phaseAt s e == .new) == (pidAt s e == 0)) "identity invariant"
    unless createdAt s e do
      ensure (phaseAt s e == .new && pidAt s e == 0) "uncreated defaults"
    for other in entities do
      if inContext s e && inContext s other && pidAt s e == pidAt s other then
        ensure (e == other) "unique context identity"

```

The function {lit}`successors` obtains every allowed next state from Veil's
generated implementation. It checks each resulting state and confirms that
detached instances stay detached. For merge, it checks that the source's
attributes are preserved and that new or detached sources have distinct targets.

The remaining checks ensure that excluded calls never appear among successful
transitions: merge on a removed instance, refresh on a nonmanaged instance,
and persist or remove on a detached instance.

```lean
/-- Enumerate actual Veil actions, and check transition-level contracts and exclusions. -/
def successors (s : FiniteState) : IO (List (FiniteLabel × FiniteState)) := do
  let out := finiteSystem.tr finiteTheory s
  ensure out.failures.isEmpty "Veil assertion failure"
  for (label, t) in out.successes do
    checkState t
    for e in entities do
      if createdAt s e && phaseAt s e == .detached then
        ensure (phaseAt t e == .detached) "detached preservation"
    match label with
    | .Merge e target =>
      ensure (phaseAt t e == phaseAt s e && pidAt t e == pidAt s e) "merge source attributes"
      if phaseAt s e == .new || phaseAt s e == .detached then
        ensure (target != e) "merge target distinctness"
      ensure (phaseAt s e != .removed) "removed merge excluded"
      if phaseAt s e == .managed then ensure (target == e) "managed merge target"
    | .Refresh e => ensure (phaseAt s e == .managed) "nonmanaged refresh excluded"
    | .Persist e | .Remove e => ensure (phaseAt s e != .detached) "detached call excluded"
    | _ => pure ()
  return out.successes

```

TLC, the model checker used for the earlier TLA+ implementation, produced saved
sets of states and transitions under {lit}`verification/`. The function
{lit}`compareFixture` compares a newly computed set with the corresponding
saved file and reports missing or extra entries. It compares the entries
themselves, not just their counts.

```lean
def compareFixture (name : String) (actual : Std.HashSet String) : IO Unit := do
  let lines := (← IO.FS.readFile (s!"verification/{name}.txt")).splitOn "\n"
  let expected := Std.HashSet.ofList (lines.filter (! ·.isEmpty))
  let missing := expected.toList.filter (!actual.contains ·)
  let extra := actual.toList.filter (!expected.contains ·)
  ensure (missing.isEmpty && extra.isEmpty)
    s!"{name}: {missing.length} missing, {extra.length} extra; first differences: {missing.take 3}, {extra.take 3}"
  IO.println s!"{name}: {actual.size} match the original TLC graph"
```

Starting from the single initial state, {lit}`checkGraph` explores every
reachable state. It keeps a queue of states to visit and adds a successor
only if it has not seen that state before. Each transition is recorded as
a pair of state keys. Finally, both the states and the transitions are compared
with the saved results. The 10,000-state guard is a resource limit for this
check, not a restriction on the model's mathematical state space.

```lean
def checkGraph : IO Unit := do
  let mut queue := finiteSystem.initStates.toArray
  ensure (queue.size == 1) "exactly one initial state"
  let mut seen : Std.HashSet String := .ofList (queue.toList.map stateKey)
  let mut edges : Std.HashSet String := {}
  let mut index := 0
  while index < queue.size do
    let s := queue[index]!
    checkState s
    for (_, t) in ← successors s do
      let key := stateKey t
      edges := edges.insert (stateKey s ++ ">" ++ key)
      unless seen.contains key do
        seen := seen.insert key
        queue := queue.push t
        ensure (queue.size ≤ 10000) "graph exceeded the regression check's resource limit"
    index := index + 1
  compareFixture "lifecycle-states" seen
  compareFixture "lifecycle-edges" edges

```

The scenario follows 17 prescribed calls. Object 0 starts new; merging it
creates managed object 1. Later, object 0 is persisted, removed, restored,
and detached. Merging that detached source creates object 2 with the same
identity. The final calls remove and then detach object 2. Repeated calls
also exercise cases where an operation leaves the state unchanged.

```lean
/-- Exactly the original 17 prescribed operations, in order. -/
def scenario : List FiniteLabel := [
  .Create 0, .Remove 0, .Detach 0, .Merge 0 1, .Merge 1 1,
  .Persist 0, .Persist 0, .Refresh 0, .Remove 0, .Remove 0,
  .Persist 0, .Detach 0, .Merge 0 2, .Merge 0 2, .Detach 0,
  .Remove 2, .Detach 2]
```

For each number of completed calls, {lit}`expectedPhases` lists the expected
lifecycle states of objects 0, 1, and 2, in that order. Position zero describes
the initial state, before any calls.

```lean
def expectedPhases (step : Nat) : List phase_IndT :=
  if step ≤ 3 then [.new, .new, .new]
  else if step ≤ 5 then [.new, .managed, .new]
  else if step ≤ 8 then [.managed, .managed, .new]
  else if step ≤ 10 then [.removed, .managed, .new]
  else if step = 11 then [.managed, .managed, .new]
  else if step = 12 then [.detached, .managed, .new]
  else if step ≤ 15 then [.detached, .managed, .managed]
  else if step = 16 then [.detached, .managed, .removed]
  else [.detached, .managed, .detached]
```

After every call, we check those lifecycle states, which objects have been
created, their identity relationships, and any pending removal. For example,
after the thirteenth call, detached object 0 and managed object 2 must share
an identity. The final checks also confirm that detached instances are outside
the context.

```lean
def checkScenarioState (step : Nat) (s : FiniteState) : IO Unit := do
  ensure (step ≤ 17) "scenario step range"
  ensure (entities.map (phaseAt s) == expectedPhases step) s!"phases at step {step}"
  let expectedCreated : List (Fin 3) :=
    if step = 0 then [] else if step ≤ 3 then [0] else if step ≤ 12 then [0, 1] else entities
  ensure (entities.filter (createdAt s) == expectedCreated) s!"created entities at step {step}"
  if step ≥ 6 then ensure (pidAt s 0 != pidAt s 1) "distinct allocated identities"
  if step ≥ 13 then ensure (pidAt s 0 == pidAt s 2) "detached copy identity"
  let pending := entities.filter fun e => createdAt s e && phaseAt s e == .removed
  let expectedPending : List (Fin 3) :=
    if step = 9 || step = 10 then [0] else if step = 16 then [2] else []
  ensure (pending == expectedPending) s!"pending removal at step {step}"
  if step ≥ 12 then ensure (!inContext s 0) "source outside context"
  if step = 17 then ensure (!inContext s 2) "second copy outside context"

```

The scenario driver keeps every state that can result from the calls so far,
including both possible assignments of identities 1 and 2. For each state,
the next prescribed call must have at least one successful result. A disabled
call fails the check instead of silently ending that execution.

After all 17 calls, both identity assignments must reach the end. We compare
the resulting states and transitions with the saved scenario, including the
unchanged final step used by the earlier driver.

```lean
/-- Each prefix must enable the next prescribed call, for every identity choice.
A disabled operation throws; it cannot make invariant checks pass vacuously. -/
def checkScenario : IO Unit := do
  ensure (scenario.length == 17) "scenario length"
  let mut frontier := finiteSystem.initStates
  let mut states : Std.HashSet String := {}
  let mut edges : Std.HashSet String := {}
  for s in frontier do
    checkScenarioState 0 s
    states := states.insert ("0|" ++ stateKey s)
  for (call, step) in scenario.zipIdx do
    let mut next := []
    let mut keys : Std.HashSet String := {}
    for s in frontier do
      let selected := (← successors s).filter fun (label, _) => labelKey label == labelKey call
      ensure (!selected.isEmpty) s!"operation {step + 1} ({labelKey call}) disabled at {stateKey s}"
      for (_, t) in selected do
        checkScenarioState (step + 1) t
        let key := s!"{step + 1}|{stateKey t}"
        states := states.insert key
        edges := edges.insert (s!"{step}|{stateKey s}>" ++ key)
        unless keys.contains key do
          keys := keys.insert key
          next := t :: next
    frontier := next
  ensure (frontier.length == 2) "both identity assignments must finish"
  for s in frontier do
    -- The original driver explicitly stutters once it has finished.
    let key := "17|" ++ stateKey s
    edges := edges.insert (key ++ ">" ++ key)
  compareFixture "scenario-states" states
  compareFixture "scenario-edges" edges
  IO.println "All 17 operations reached for both identity assignments; all assertions and excluded calls checked."

```

The entry point runs the complete graph comparison and the scenario. Run it
from the repository root with
{lit}`lake env lean --run Lifecycle/Checks.lean`; any failed assertion makes
the command fail.

```lean
def runChecks : IO Unit := do
  checkGraph
  checkScenario

end EntityLifecycle

def main : IO Unit := EntityLifecycle.runChecks
```
