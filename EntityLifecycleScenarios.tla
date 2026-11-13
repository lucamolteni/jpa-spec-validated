--------------------- MODULE EntityLifecycleScenarios ---------------------
(* A finite regression scenario using the actual lifecycle actions.      *)
(* Fairness belongs ONLY to this test driver: it makes a disabled step   *)
(* fail EventuallyFinished instead of silently passing state invariants. *)
EXTENDS EntityLifecycle, Naturals

CONSTANTS Source, FirstCopy, SecondCopy
ASSUME /\ Entities = {Source, FirstCopy, SecondCopy}
       /\ Cardinality(Entities) = 3
       /\ Cardinality(Identities) = 2

VARIABLE step
testVars == <<vars, step>>

TestInit == ELInit /\ step = 0

TestNext ==
    \/ /\ step < 17
       /\ CASE step = 0  -> Create(Source)
            [] step = 1  -> Remove(Source)             \* new: ignored
            [] step = 2  -> Detach(Source)             \* new: ignored
            [] step = 3  -> Merge(Source, FirstCopy)   \* source stays new
            [] step = 4  -> Merge(FirstCopy, FirstCopy)
            [] step = 5  -> Persist(Source)            \* different identity
            [] step = 6  -> Persist(Source)            \* managed: ignored
            [] step = 7  -> Refresh(Source)
            [] step = 8  -> Remove(Source)
            [] step = 9  -> Remove(Source)             \* removed: ignored
            [] step = 10 -> Persist(Source)            \* cancel removal
            [] step = 11 -> Detach(Source)
            [] step = 12 -> Merge(Source, SecondCopy)  \* fresh managed copy
            [] step = 13 -> Merge(Source, SecondCopy)  \* reuse managed copy
            [] step = 14 -> Detach(Source)             \* detached: ignored
            [] step = 15 -> Remove(SecondCopy)
            [] step = 16 -> Detach(SecondCopy)         \* cancel removal
       /\ step' = step + 1
    \/ /\ step = 17
       /\ UNCHANGED testVars

TestSpec == TestInit /\ [][TestNext]_testVars /\ WF_testVars(TestNext)
EventuallyFinished == <> (step = 17)

ExpectedStates ==
    CASE step <= 3 -> <<"new", "new", "new">>
      [] step <= 5 -> <<"new", "managed", "new">>
      [] step <= 8 -> <<"managed", "managed", "new">>
      [] step <= 10 -> <<"removed", "managed", "new">>
      [] step = 11 -> <<"managed", "managed", "new">>
      [] step = 12 -> <<"detached", "managed", "new">>
      [] step <= 15 -> <<"detached", "managed", "managed">>
      [] step = 16 -> <<"detached", "managed", "removed">>
      [] step = 17 -> <<"detached", "managed", "detached">>

ScenarioOK ==
    /\ step \in 0..17
    /\ <<entityState[Source], entityState[FirstCopy],
         entityState[SecondCopy]>> = ExpectedStates
    /\ createdEntities = (CASE step = 0 -> {}
                      [] step <= 3 -> {Source}
                      [] step <= 12 -> {Source, FirstCopy}
                      [] OTHER -> Entities)
    /\ (step >= 6 => identity[Source] # identity[FirstCopy])
    /\ (step >= 13 => identity[Source] = identity[SecondCopy])
    /\ (step \in {9, 10} => PendingRemoval = {Source})
    /\ (step = 16 => PendingRemoval = {SecondCopy})
    /\ (step \notin {9, 10, 16} => PendingRemoval = {})
    /\ (step >= 12 => Source \notin Context)
    /\ (step = 17 => SecondCopy \notin Context)

(* These are restrictions of the successful-operation abstraction, not   *)
(* assertions about whether a Java method call can physically be made.   *)
ExcludedCalls ==
    \A e \in createdEntities :
        /\ (entityState[e] # "managed" => ~ENABLED Refresh(e))
        /\ (entityState[e] = "detached" =>
               /\ ~ENABLED Persist(e)
               /\ ~ENABLED Remove(e))
        /\ (entityState[e] = "removed" =>
               ~ENABLED (\E target \in Entities : Merge(e, target)))
        /\ (entityState[e] = "managed" =>
               \A target \in Entities \ {e} : ~ENABLED Merge(e, target))
===========================================================================
