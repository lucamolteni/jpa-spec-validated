------------------------- MODULE EntityLifecycle --------------------------
(***************************************************************************)
(* A safety model of entity instances in ONE persistence context.        *)
(*                                                                       *)
(* START HERE                                                            *)
(*                                                                       *)
(* This file describes allowed behavior mathematically. It is not Java   *)
(* code and does not execute EntityManager calls. Imagine a sequence of  *)
(* snapshots: each snapshot records which entities exist, their          *)
(* lifecycle                                                             *)
(* states, and their persistent identities. Each operation below         *)
(* describes                                                             *)
(* how one snapshot may follow another.                                  *)
(*                                                                       *)
(* The four lifecycle states mean:                                       *)
(*   new      - no persistent identity, outside the persistence context; *)
(*   managed  - has a persistent identity and belongs to the context;    *)
(*   detached - has a persistent identity but is outside the context;    *)
(*   removed  - still belongs to the context, with removal pending.      *)
(* A removed entity has not disappeared from memory. This model records  *)
(* its removal status but does not perform the eventual database         *)
(* deletion.                                                             *)
(*                                                                       *)
(* Read the file in this order: the data being tracked, the consistency  *)
(* rules, the starting snapshot, the operations, then ELSpec (the        *)
(* complete                                                              *)
(* description of allowed executions). The companion                     *)
(* EntityLifecycle_proof                                                 *)
(* proves that the operations preserve those consistency rules.          *)
(*                                                                       *)
(* Source: Jakarta Persistence 4.0-M4, sections 3.6.2-3.6.9.2:           *)
(* https://jakarta.ee/specifications/persistence/4.0/                    *)
(* jakarta-persistence-spec-4.0-M4.html#a1060                            *)
(* Structure inspired by tlaplus/Examples,                               *)
(* transaction_commit/TwoPhase.tla:                                      *)
(* constants, variables, invariant, initialization, actions, Next, Spec. *)
(*                                                                       *)
(* "Entities" means Java entity instances. Two entities may represent    *)
(* the same database record. Entities names the possible instances;      *)
(* Identities contains persistent identities (entity-type/primary-key    *)
(* pairs). Instance identity and persistent identity are separate        *)
(* because a detached entity and its managed copy can represent one      *)
(* record.                                                               *)
(* For example, entities e1 and e2 can both represent Customer/42, while *)
(* being different Java entities. At most one of them can be associated  *)
(* with the persistence context at a time.                               *)
(*                                                                       *)
(* We model successful lifecycle effects only. Failed calls and          *)
(* exception                                                             *)
(* timing are excluded. Fields, copying field values, database records,  *)
(* cascades, versions, transactions, and context closure are abstracted  *)
(* out.                                                                  *)
(* Refresh therefore stutters. Flush and lock have no modeled actions.   *)
(* No fairness, eventual flush, or eventual commit is required.          *)
(* "Safety" means ruling out invalid states or transitions; it does not  *)
(* mean guaranteeing progress. An execution may pause forever.           *)
(*                                                                       *)
(* The model permits a finite number of entities. Create and Merge can   *)
(* create another entity only while that limit has not been reached.     *)
(* Persistent identities are never reused and may also run out. Reaching *)
(* either limit disables the corresponding action; it is not a JPA       *)
(* error.                                                                *)
(* Identity generation is atomic; database-dependent generation is       *)
(* omitted.                                                              *)
(* Merging a detached source while its identity is represented by a      *)
(* removed entity is outside this model's successful-operation subset.   *)
(* We do not track the portability restriction on reusing an entity      *)
(* after                                                                 *)
(* detaching it from the removed state. This is not a conformance model. *)
(***************************************************************************)
(* Import the library that defines finite-set operations.                *)
EXTENDS FiniteSets

(***************************************************************************)
(* NOTATION USED BELOW                                                   *)
(*                                                                       *)
(* Name == expression   defines a reusable name, not a program           *)
(* assignment.                                                           *)
(* /\ and \/            logical AND and OR. Indentation groups           *)
(* conditions.                                                           *)
(* P => Q               if P is true, Q must be true.                    *)
(* P <=> Q              P is true exactly when Q is true.                *)
(* = and #              equality and inequality.                         *)
(* {} and {e}           the empty set and the set containing just e.     *)
(* e \in S / e \notin S e belongs / does not belong to set S.            *)
(* A \subseteq B        every member of A belongs to B.                  *)
(* A \cup B / A \ B     set union / set difference.                      *)
(* \A e \in S : P       P holds for every e in S.                        *)
(* \E e \in S : P       there is at least one e in S for which P holds.  *)
(* {e \in S : P}        select the members of S satisfying P.            *)
(* {f[e] : e \in S}     collect the values of f[e] for all e in S.       *)
(* f[e]                 look up the value for e in the function/map f.   *)
(* [A -> B]             the set of all maps from A to B.                 *)
(* [e \in S |-> value]  construct a map with that value for each e in S. *)
(* <<a, b>>             a tuple grouping values together.                *)
(*                                                                       *)
(* A prime (') means the next snapshot: createdEntities' is the next     *)
(* value of                                                              *)
(* createdEntities. Unprimed names refer to the current snapshot.        *)
(* [f EXCEPT ![e] = v] means a map equal to f except that e maps to v.   *)
(* Inside EXCEPT, @ means the old value at the entry being updated.      *)
(* UNCHANGED x means x' = x; for a tuple it applies to every component.  *)
(*                                                                       *)
(* An action is a condition on two snapshots, not a sequence of          *)
(* commands.                                                             *)
(* All its AND-connected conditions hold together. Unprimed conditions,  *)
(* such as e \in createdEntities, restrict when the action is allowed    *)
(* (guards).                                                             *)
(* The equations for primed values describe its effect in one atomic     *)
(* step.                                                                 *)
(***************************************************************************)

(* Constants are fixed for an entire execution. Entities is the set of   *)
(* possible entities; Identities is the set of persistent identities.    *)
(* NoIdentity is a special marker for "no persistent identity yet".      *)
(* EntityLifecycle.cfg assigns concrete values for a small TLC check.    *)
CONSTANTS Entities, Identities, NoIdentity

(* Preconditions on those constants: both pools are finite and nonempty, *)
(* and the no-identity marker cannot also be a persistent identity.      *)
ASSUME /\ IsFiniteSet(Entities) /\ Entities # {}
       /\ IsFiniteSet(Identities) /\ Identities # {}
       /\ NoIdentity \notin Identities

(* Variables can change between snapshots. createdEntities records which *)
(* entities have actually been created. The maps include initial values  *)
(* for all possible entities, even those that have not been created yet. *)
VARIABLES createdEntities, \* Entities that have been created so far.
          entityState,     \* Lifecycle state of each created entity.
          identity         \* Persistent identity, or NoIdentity.

(* vars groups the complete snapshot; States lists allowed lifecycle     *)
(* names.                                                                *)
vars == <<createdEntities, entityState, identity>>
States == {"new", "managed", "detached", "removed"}

(* These three sets are computed from the variables, not stored          *)
(* separately.                                                           *)
(* Context includes entities scheduled for removal, until they detach.   *)
Context == {e \in createdEntities : entityState[e] \in {"managed", "removed"}}
(* Leaving the removed state automatically removes an entity from this   *)
(* set.                                                                  *)
PendingRemoval == {e \in createdEntities : entityState[e] = "removed"}
(* An identity held even by a detached entity is not available for       *)
(* reuse.                                                                *)
FreshIdentities == Identities \ {identity[e] : e \in createdEntities}

(* Consistency rule 1: createdEntities is a subset of Entities; the maps *)
(* give each entity a permitted state and identity (or the special       *)
(* marker).                                                              *)
(* These are mathematical type checks, not declarations of Java classes. *)
ELTypeOK ==
    /\ createdEntities \subseteq Entities
    /\ entityState \in [Entities -> States]
    /\ identity \in [Entities -> Identities \cup {NoIdentity}]

(* Consistency rule 2: an existing entity has no persistent identity if  *)
(* and only if it is new. Managed, detached and removed entities         *)
(* therefore                                                             *)
(* have identities. Entities not yet created keep their initial map      *)
(* values.                                                               *)
ELIdentityOK ==
    /\ \A e \in createdEntities :
           (entityState[e] = "new") <=> (identity[e] = NoIdentity)
    /\ \A e \in Entities \ createdEntities :
           /\ entityState[e] = "new"
           /\ identity[e] = NoIdentity

(* Consistency rule 3: if two context members have equal persistent      *)
(* identities, they must be the same entity. A detached entity can share *)
(* an identity with a context member because it is outside Context.      *)
ELUniqueIdentity ==
    \A e, other \in Context : identity[e] = identity[other] => e = other

(* Initially no entities exist. Create adds them later. Both maps        *)
(* already                                                               *)
(* contain new/NoIdentity values for every possible entity.              *)
(* The three rules above are properties to verify, not filters that      *)
(* silently discard invalid snapshots. The proof establishes they hold.  *)
ELInit ==
    /\ createdEntities = {}
    /\ entityState = [e \in Entities |-> "new"]
    /\ identity = [e \in Entities |-> NoIdentity]

---------------------------------------------------------------------------
Create(e) ==
    (***********************************************************************)
    (* Application construction (3.6.2), not an EntityManager operation. *)
    (* Choose an entity not yet created and add it to createdEntities.   *)
    (* Its initial map values already describe a new entity, so those    *)
    (* values stay unchanged. "Not yet created" is not a lifecycle       *)
    (* state.                                                            *)
    (* Creation neither assigns a persistent identity nor joins Context. *)
    (***********************************************************************)
    /\ e \in Entities \ createdEntities
    /\ createdEntities' = createdEntities \cup {e}
    /\ UNCHANGED <<entityState, identity>>

Persist(e) ==
    (***********************************************************************)
    (* 3.6.3: assign a fresh identity to a new instance, or cancel       *)
    (* removal.                                                          *)
    (* A managed instance is ignored; detached calls are excluded.       *)
    (* Read the three OR branches as alternatives:                       *)
    (*   new: choose an unused identity and make this same entity        *)
    (* managed;                                                          *)
    (*   removed: make it managed again, keeping its identity;           *)
    (*   managed: leave the snapshot unchanged.                          *)
    (* None of these branches creates a second Java entity. For a new    *)
    (* source, the action needs an identity available in                 *)
    (* FreshIdentities.                                                  *)
    (* No detached branch is given because failures are outside the      *)
    (* model.                                                            *)
    (***********************************************************************)
    /\ e \in createdEntities
    /\ \/ /\ entityState[e] = "new"
          /\ \E id \in FreshIdentities :
                 /\ identity' = [identity EXCEPT ![e] = id]
                 /\ entityState' = [entityState EXCEPT ![e] = "managed"]
          /\ UNCHANGED createdEntities
       \/ /\ entityState[e] = "removed"
          /\ entityState' = [entityState EXCEPT ![e] = "managed"]
          /\ UNCHANGED <<createdEntities, identity>>
       \/ /\ entityState[e] = "managed"
          /\ UNCHANGED vars

Remove(e) ==
    (* 3.6.4: mark for removal; no database deletion is modeled here.    *)
    (* Managed becomes removed; new and already-removed entities stay as *)
    (* they are. The identity is retained, and a managed entity remains  *)
    (* in Context after becoming removed. Detached sources are excluded. *)
    (* @ reads the old lifecycle state; only "managed" needs an update.  *)
    /\ e \in createdEntities
    /\ entityState[e] \in {"new", "managed", "removed"}
    /\ entityState' = [entityState EXCEPT
           ![e] = IF @ = "managed" THEN "removed" ELSE @]
    /\ UNCHANGED <<createdEntities, identity>>

Detach(e) ==
    (* 3.6.8: detach also cancels pending removal of a removed instance. *)
    (* Managed and removed become detached; new and detached stay as is. *)
    (* The persistent identity is retained. Context and PendingRemoval   *)
    (* are computed from entityState, so changing removed to detached    *)
    (* both removes context membership and cancels the pending removal.  *)
    /\ e \in createdEntities
    /\ entityState' = [entityState EXCEPT
           ![e] = IF @ \in {"managed", "removed"} THEN "detached" ELSE @]
    /\ UNCHANGED <<createdEntities, identity>>

Refresh(e) ==
    (* 3.6.7: a successful refresh changes fields, not lifecycle state.  *)
    (* Only managed entities are eligible. Since field values and        *)
    (* database                                                          *)
    (* records are absent here, success leaves the whole modeled         *)
    (* snapshot                                                          *)
    (* unchanged. This does not mean refresh has no effect in Java, nor  *)
    (* that a real refresh cannot fail when the database row is missing. *)
    /\ e \in createdEntities
    /\ entityState[e] = "managed"
    /\ UNCHANGED vars

Merge(e, target) ==
    (***********************************************************************)
    (* 3.6.9.2: target denotes the returned entity. Field copying is     *)
    (* abstracted out. The source's state and identity never change.     *)
    (* A new managed entity is created only when there is no managed     *)
    (* target.                                                           *)
    (* Think of this as: returnedEntity = entityManager.merge(e).        *)
    (* The parameter target identifies returnedEntity; it is not an      *)
    (* extra                                                             *)
    (* argument supplied to the Java API. The branches describe:         *)
    (*   new source: create a distinct managed target with a fresh       *)
    (*     persistent identity. The source remains new with NoIdentity.  *)
    (*   detached source: use an existing managed target of the same     *)
    (*     identity, or create a new managed target with that identity   *)
    (*     if no entity in Context represents it. The source stays       *)
    (*     detached. Copying into an existing target changes no modeled  *)
    (*     variables because field values have been left out.            *)
    (*   managed source: the target is the source itself; nothing        *)
    (* changes.                                                          *)
    (* Removed sources are excluded. For a detached source, an identity  *)
    (* already represented by a removed entity is also excluded here.    *)
    (*                                                                   *)
    (* Example: detach entity e1 representing Customer/42, then merge    *)
    (* it.                                                               *)
    (* A new target e2 can become managed with identity Customer/42      *)
    (* while                                                             *)
    (* e1 remains detached. Merging e1 again can return that same e2.    *)
    (***********************************************************************)
    /\ e \in createdEntities
    /\ target \in Entities
    /\ \/ /\ entityState[e] = "new"
          /\ target \in Entities \ createdEntities
          /\ \E id \in FreshIdentities :
                 identity' = [identity EXCEPT ![target] = id]
          /\ createdEntities' = createdEntities \cup {target}
          /\ entityState' = [entityState EXCEPT ![target] = "managed"]
       \/ /\ entityState[e] = "detached"
          /\ \/ /\ target \in Context
                /\ entityState[target] = "managed"
                /\ identity[target] = identity[e]
                /\ UNCHANGED vars
             \/ /\ \A other \in Context : identity[other] # identity[e]
                /\ target \in Entities \ createdEntities
                /\ createdEntities' = createdEntities \cup {target}
                /\ entityState' = [entityState EXCEPT ![target] = "managed"]
                /\ identity' = [identity EXCEPT ![target] = identity[e]]
       \/ /\ entityState[e] = "managed"
          /\ target = e
          /\ UNCHANGED vars

(* The next-step rule permits any ONE of the listed actions whose guards *)
(* are satisfied, for any eligible entity and merge target. The choices  *)
(* are nondeterministic: no caller order or scheduling policy is         *)
(* imposed.                                                              *)
(* This OR does not mean that all operations happen in a single step.    *)
ELNext ==
    \/ \E e \in Entities : Create(e)
    \/ \E e \in createdEntities :
           Persist(e) \/ Remove(e) \/ Detach(e) \/ Refresh(e)
             \/ (\E target \in Entities : Merge(e, target))

---------------------------------------------------------------------------
(* THE COMPLETE SPECIFICATION                                            *)
(* [] means "always", over the entire sequence of snapshots.             *)
(* [ELNext]_vars means either ELNext happens or all variables in vars    *)
(* remain unchanged. An unchanged snapshot is called a stuttering step.  *)
(* Read ELSpec as: start in ELInit, then always take an allowed step or  *)
(* leave the snapshot unchanged. Stuttering permits an execution to wait *)
(* indefinitely; there is no requirement to eventually call an           *)
(* operation.                                                            *)
ELSpec == ELInit /\ [][ELNext]_vars

(* In this restricted model a detached source stays detached, including  *)
(* when merged. The managed target is always a different entity.         *)
(* At every transition, inspect every existing entity: if it is detached *)
(* before the transition, it must also be detached afterwards. This is a *)
(* property checked against ELSpec, not an extra restriction in ELNext.  *)
(* A managed entity may still become detached; the statement only        *)
(* protects                                                              *)
(* entities that were already detached. Its scope is this model's        *)
(* actions.                                                              *)
ELDetachedStaysDetached ==
    [] [\A e \in createdEntities :
           entityState[e] = "detached" => entityState'[e] = "detached"]_vars

(* Proof scripts for the following claims are in EntityLifecycle_proof:  *)
(*   ELSpec => [](ELTypeOK /\ ELIdentityOK /\ ELUniqueIdentity)          *)
(*   ELSpec => ELDetachedStaysDetached                                   *)
(* Keep the claims as comments here so importing this module does not    *)
(* introduce unproved theorem facts into the companion proof's context.  *)
(* TLC checks the finite instance configured in EntityLifecycle.cfg.     *)
(* TLAPS checks the companion mathematical proof for arbitrary constant  *)
(* sets satisfying ASSUME. TLC checks specific configured set sizes by   *)
(* exploring reachable snapshots. Neither tool executes a JPA provider.  *)
===========================================================================
