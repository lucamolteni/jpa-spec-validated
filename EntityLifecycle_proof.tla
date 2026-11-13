---------------------- MODULE EntityLifecycle_proof -----------------------
(***************************************************************************)
(* WHAT THIS FILE DOES                                                     *)
(*                                                                         *)
(* EntityLifecycle.tla defines a mathematical model of entity operations.   *)
(* This companion file gives arguments that TLAPS, the TLA+ Proof System,  *)
(* checks to establish properties of that model. It is not Java code and   *)
(* does not run an EntityManager or connect to a database.                  *)
(*                                                                         *)
(* Think of the model as a sequence of snapshots. Each snapshot records    *)
(* which objects exist, their lifecycle states, and their persistent       *)
(* identities. An operation such as Persist or Detach relates one snapshot *)
(* to the next. Here, "state" can mean an entire snapshot; entityState[e]  *)
(* specifically means one object's new/managed/detached/removed status.    *)
(*                                                                         *)
(* The main argument is induction:                                        *)
(*   1. The consistency rules hold in the initial snapshot.                *)
(*   2. Every allowed operation preserves them if they already hold.       *)
(*   3. Therefore they hold in every snapshot of every allowed execution.   *)
(* Step 2 examines every operation, not just one example execution.         *)
(*                                                                         *)
(* The final claims, with their names below, are:                          *)
(*   ELCorrect: typing and identity consistency always hold.               *)
(*   ELDetachedCorrect: a detached object stays detached in this model.    *)
(*   ELMergeSourceUnchanged: merge preserves the source's lifecycle state  *)
(*     and persistent identity; a new or detached source is distinct from  *)
(*     the returned managed target.                                       *)
(*                                                                         *)
(* TLC, used with EntityLifecycle.cfg, explores a particular finite model  *)
(* (three object slots and two identities). This proof does not choose     *)
(* those sizes: it applies to any finite, nonempty sets satisfying the     *)
(* model's assumptions. An individual model still has finite resources.    *)
(*                                                                         *)
(* These are safety claims: they describe what cannot go wrong. They do    *)
(* not require an operation to happen eventually or prove that a record   *)
(* reaches the database. Fields, transactions, exceptions and cascades are *)
(* outside the model. Nothing here proves that a Java persistence provider *)
(* implements these rules, or that this abstraction captures all of JPA.   *)
(*                                                                         *)
(* The proof structure follows the example at:                            *)
(* tlaplus/Examples/specifications/transaction_commit/TCommit_proof.tla.    *)
(*                                                                         *)
(* Check with: tlapm --strict --nofp EntityLifecycle_proof.tla              *)
(* Verified 2026-11-13: TLAPS 1.6.0-pre (ff40755), bundled Z3 4.8.9,       *)
(* Zenon and LS4 backends. All 93 obligations proved with cache reuse      *)
(* disabled. There are no OMITTED or admitted proof steps below.           *)
(* An "obligation" is a logical subproblem generated from the proof. The  *)
(* count of 93 is not a count of tests, objects, or execution sequences.    *)
(***************************************************************************)
(* EXTENDS imports the model's definitions and TLAPS's proof tools. *)
EXTENDS EntityLifecycle, TLAPS

(***************************************************************************)
(* READING THE NOTATION                                                    *)
(*                                                                         *)
(* P == expression   defines a name; it is not an assignment.              *)
(* P /\ Q            P and Q both hold.                                   *)
(* P => Q            if P holds, then Q must hold.                         *)
(* \A e \in Objects  for every object e in the set Objects.                *)
(* e \notin S        e is not a member of the set S.                       *)
(* target # e        target and e are different objects.                   *)
(* entityState[e]    look up e's lifecycle state in the current snapshot.  *)
(* entityState'[e]   look it up in the NEXT snapshot; ' means "next".      *)
(* Inv'              evaluate all of Inv in the next snapshot.             *)
(* []Inv             Inv holds now and at every later point in execution. *)
(* UNCHANGED vars    every variable in the tuple vars keeps its value.     *)
(* [ELNext]_vars     either an allowed operation occurs, or vars stay     *)
(*                   unchanged. The latter is called a stuttering step.   *)
(*                                                                         *)
(* THEOREM introduces a claim; LEMMA introduces a supporting claim. Both   *)
(* need proofs. <1>, <2>, <3> indicate nested reasoning, and numbers such   *)
(* as <1>2 name steps that later steps may cite. They are not time steps.  *)
(*                                                                         *)
(* ASSUME ... PROVE ... states the premises and conclusion of a local     *)
(* argument. NEW e selects an arbitrary symbolic object for that argument;*)
(* it does not create an entity. CASE separates possible situations.       *)
(* SUFFICES replaces a goal with a sufficient goal; that reduction is also *)
(* checked. BY cites facts and proof tools; DEF unfolds named definitions. *)
(* USE DEF makes definitions available to the following proof steps.       *)
(* SMT asks an automated solver to establish a logical step. PTL invokes  *)
(* temporal reasoning for statements about executions. OBVIOUS requests   *)
(* an automatic check of a simple step; it does not skip verification.     *)
(* QED closes the current argument using its cited supporting steps.      *)
(***************************************************************************)

(* Inv is the combined "invariant": a rule that should hold in every      *)
(* reachable snapshot. Its three parts are defined in EntityLifecycle:    *)
(*   ELTypeOK: allocated objects, lifecycle states, and identities belong *)
(*     to their declared sets.                                            *)
(*   ELIdentityOK: an allocated object has NoIdentity exactly when it is   *)
(*     new. Unused slots retain their initial new/NoIdentity placeholders. *)
(*   ELUniqueIdentity: two distinct objects associated with this context  *)
(*     cannot have the same persistent identity. Associated objects here  *)
(*     include both managed and removed objects.                          *)
(* A detached object and a managed copy MAY share a persistent identity:  *)
(* uniqueness applies within the context, not across all Java objects.    *)
Inv == ELTypeOK /\ ELIdentityOK /\ ELUniqueIdentity

(* Read this as: for each existing object, if it is detached before this  *)
(* step, it is detached afterwards. This compares two snapshots, whereas  *)
(* Inv describes a single snapshot. It does not forbid detaching a        *)
(* managed object, and it does not say that a managed copy cannot exist.  *)
DetachedStep ==
    \A e \in allocated :
        entityState[e] = "detached" => entityState'[e] = "detached"

(* Starting point of induction: initially no objects are allocated and    *)
(* every reserved slot has new/NoIdentity placeholders. Thus all three    *)
(* consistency rules hold before the first operation.                     *)
LEMMA InitialInvariant == ELInit => Inv
    BY SMT DEF ELInit, Inv, ELTypeOK, ELIdentityOK, ELUniqueIdentity,
               States, Context

---------------------------------------------------------------------------
(* Strengthen the induction step with the detached-source property.       *)
(* Each action must preserve all three conjuncts together: typing alone  *)
(* is insufficient to show that persistent identities remain consistent. *)
(* Read the formula below as: given a consistent snapshot and an allowed  *)
(* step (including doing nothing), the next snapshot is consistent AND    *)
(* every previously detached object remains detached.                     *)
(* A case only covers calls permitted by that action's definition. An     *)
(* excluded call is not proved to succeed or to throw a specific exception.*)
LEMMA LifecycleStep ==
    Inv /\ [ELNext]_vars => Inv' /\ DetachedStep
<1> SUFFICES ASSUME Inv, [ELNext]_vars
             PROVE Inv' /\ DetachedStep
    OBVIOUS
<1> USE DEF Inv, ELTypeOK, ELIdentityOK, ELUniqueIdentity, States,
           Context, DetachedStep, vars
<1>1. ASSUME NEW e \in Objects, Create(e)
      PROVE Inv' /\ DetachedStep
    (* Creation exposes a slot already initialized as new/NoIdentity; it   *)
    (* neither changes existing objects nor adds a member to Context.     *)
    BY <1>1, SMT DEF Create
<1>2. ASSUME NEW e \in allocated, Persist(e)
      PROVE Inv' /\ DetachedStep
    <2>1. CASE entityState[e] = "new"
        (* The new identity differs from every existing object's identity.*)
        BY <1>2, <2>1, SMT DEF FreshIdentities, Persist
    <2>2. CASE entityState[e] = "removed"
        (* The object was already in Context with this same identity. *)
        BY <1>2, <2>2, SMT DEF Persist
    <2>3. CASE entityState[e] = "managed"
        BY <1>2, <2>3, SMT DEF Persist
    <2> QED BY <1>2, <2>1, <2>2, <2>3 DEF Persist
<1>3. ASSUME NEW e \in allocated, Remove(e)
      PROVE Inv' /\ DetachedStep
    (* Managed and removed objects are both in Context. No identity changes.*)
    BY <1>3, SMT DEF Remove
<1>4. ASSUME NEW e \in allocated, Detach(e)
      PROVE Inv' /\ DetachedStep
    (* Context can only shrink. Detached objects retain their identity. *)
    BY <1>4, SMT DEF Detach
<1>5. ASSUME NEW e \in allocated, Refresh(e)
      PROVE Inv' /\ DetachedStep
    (* Refresh can change entity fields in Java. Fields are absent from   *)
    (* this model, so it changes none of the variables being proved safe. *)
    BY <1>5, SMT DEF Refresh
<1>6. ASSUME NEW e \in allocated, NEW target \in Objects, Merge(e, target)
      PROVE Inv' /\ DetachedStep
    <2>1. CASE entityState[e] = "new"
        (* A fresh slot and fresh identity are used; the source stays new. *)
        BY <1>6, <2>1, SMT DEF FreshIdentities, Merge
    <2>2. CASE entityState[e] = "detached"
        <3>1. CASE target \in allocated
            (* The pre-existing target has the source's identity; only    *)
            (* unmodeled fields are copied, so all model variables stutter.*)
            BY <1>6, <3>1, <2>2, SMT DEF Merge
        <3>2. CASE target \notin allocated
            (* The source identity is absent from Context. Adding a fresh *)
            (* managed copy therefore preserves uniqueness in Context.    *)
            BY <1>6, <3>2, <2>2, SMT DEF Merge
        <3> QED BY <3>1, <3>2
    <2>3. CASE entityState[e] = "managed"
        BY <1>6, <2>3, SMT DEF Merge
    <2> QED BY <1>6, <2>1, <2>2, <2>3 DEF Merge
<1>7. CASE UNCHANGED vars
    (* Doing nothing also preserves the rules. This case lets executions  *)
    (* pause or stop making progress without violating a safety claim.    *)
    BY <1>7, SMT
<1> QED BY <1>1, <1>2, <1>3, <1>4, <1>5, <1>6, <1>7 DEF ELNext

---------------------------------------------------------------------------
(* MAIN RESULT: every execution described by ELSpec always satisfies Inv. *)
(* ELSpec starts with ELInit and permits only ELNext or stuttering steps. *)
(* The two lemmas supply the base and preservation steps; PTL combines    *)
(* them into the conclusion for the whole execution.                      *)
THEOREM ELCorrect == ELSpec => []Inv
<1>1. ELInit => Inv
    BY InitialInvariant
<1>2. Inv /\ [ELNext]_vars => Inv'
    BY LifecycleStep
<1> QED BY <1>1, <1>2, PTL DEF ELSpec

(* ELCorrect supplies Inv at every point. LifecycleStep then guarantees   *)
(* DetachedStep at every transition. Therefore, once an object becomes    *)
(* detached, no later modeled operation makes that SAME object managed.   *)
(* This is a consequence of the operations in this restricted model, not  *)
(* a claim about every possible persistence API or context arrangement.   *)
THEOREM ELDetachedCorrect == ELSpec => ELDetachedStaysDetached
<1>1. Inv /\ [ELNext]_vars => [DetachedStep]_vars
    BY LifecycleStep
<1> QED BY ELCorrect, <1>1, PTL
           DEF ELSpec, ELDetachedStaysDetached, DetachedStep

---------------------------------------------------------------------------
(* An action-level contract covering new, detached, and managed sources.  *)
(* This is stronger than merely preserving the detached lifecycle state. *)
(* Read it as: for any source e and returned target, a permitted merge    *)
(* from a consistent snapshot leaves e's lifecycle state and identity     *)
(* unchanged. For a new or detached source, target must be a different    *)
(* object. A managed source may be its own target.                        *)
(*                                                                       *)
(* Example: source is detached with identity Customer/42. After merge,    *)
(* source is still detached with Customer/42; the operation returns a     *)
(* different managed object representing Customer/42. The definitions in  *)
(* the model determine the target's state and identity; this theorem      *)
(* specifically establishes the source-preservation contract.             *)
(* "Unchanged" here concerns the two modeled attributes, not all entity *)
(* fields. No claim about copying field values is proved by this model.   *)
THEOREM ELMergeSourceUnchanged ==
    \A e, target \in Objects :
        Inv /\ Merge(e, target) =>
            /\ entityState'[e] = entityState[e]
            /\ identity'[e] = identity[e]
            /\ (entityState[e] \in {"new", "detached"} => target # e)
<1> SUFFICES ASSUME NEW e \in Objects, NEW target \in Objects,
                   Inv, Merge(e, target)
             PROVE /\ entityState'[e] = entityState[e]
                   /\ identity'[e] = identity[e]
                   /\ (entityState[e] \in {"new", "detached"} => target # e)
    OBVIOUS
<1>1. CASE target \notin allocated
    (* Only an unused slot is updated; the source is already allocated. *)
    BY <1>1, SMT DEF Inv, ELTypeOK, Merge, Context, vars
<1>2. CASE target \in allocated
    (* Existing-target and managed-source branches stutter. A detached    *)
    (* source cannot be the managed target since their states differ.     *)
    BY <1>2, SMT DEF Inv, ELTypeOK, Merge, Context, vars
<1> QED BY <1>1, <1>2
===========================================================================
