import Lifecycle.Model
import Lifecycle.Proofs
import Lifecycle.Checks
import Lifecycle.Audit

open Verso.Code.External
open Verso.Genre Manual
open Lifecycle.Document

section
open EntityLifecycle
open Verso.Genre.Manual.InlineLean

-- The example uses the finite model from Checks. The book renderer places
-- these checked blocks in the formalization following the persist boundary.
#docs (Manual) Lifecycle.persistExample "A book becomes managed" :=
:::::::
Let {lit}`book` stand for one Java object. The first row pairs construction
({lit}`Book book = new Book();`) with the phase of that object immediately
afterward, {lit}`new`. The second row calls {lit}`em.persist(book)` on the
same reference and expects {lit}`managed`. The Lean proof {lit}`by decide`
asks Lean to check both rows against the finite model for every allowed
choice of persistent identity.

```lean
example : followsPhases book [
    (.Create book,  .new),
    (.Persist book, .managed)
  ] := by decide
```

To see the phases along one execution, run the calls with {lit}`#eval`.
In a scratch Lean file in this project, put {lit}`import Lifecycle.Checks`
on the first line and {lit}`open EntityLifecycle` on the next.

```lean (name := persistPhases)
#eval showLifecycle book [.Create book, .Persist book]
```

```leanOutput persistPhases
new → managed
```

The Jakarta Persistence TCK checks what {lit}`EntityManager.contains()`
reports for these cases. It expects {lit}`false` for a newly constructed
object and {lit}`true` for the reference just passed to {lit}`persist`.
The two phases above show the corresponding lifecycle states.
[New object check](https://github.com/jakartaee/persistence/blob/4.0.0-M4/tck/spec-tests/src/main/java/ee/jakarta/tck/persistence/core/entitytest/persist/basic/Client.java#L82-L96)
· [Check after persist](https://github.com/jakartaee/persistence/blob/4.0.0-M4/tck/spec-tests/src/main/java/ee/jakarta/tck/persistence/core/entitytest/remove/basic/Client.java#L162-L173)

When {lit}`em.persist(book)` is called a second time, the book is already
managed and stays managed.

```lean (name := repeatedPersistPhases)
#eval showLifecycle book [.Create book, .Persist book, .Persist book]
```

```leanOutput repeatedPersistPhases
new → managed → managed
```
:::::::

end

#doc (Manual) "Jakarta Persistence" =>

This book models how construction and lifecycle operations affect an entity's
state and persistent identity in one persistence context. Sections 2.1 and 2.4
introduce entity instances and identity. Selected parts of section 3.6 pair
the lifecycle rules with checked Lean/Veil code. The {ref "verification"}[Verification]
chapter explains what we can prove and how we check the model.

{include 1 Lifecycle.Model}

# Verification
%%%
tag := "verification"
number := false
%%%

There are two reasons we decided to formalize the specification. The first is
to make our interpretation of the Jakarta Persistence text unambiguous. For the
lifecycle rules we model, a reader can tell exactly which outcomes the model
permits. The second is to prove that those rules uphold the guarantees we expect
of them.

What it means to prove something correct depends on what we are trying to
verify. For an algorithm, we might prove that for every input satisfying its
preconditions, the algorithm produces a result that satisfies its
specification. In our case, we are writing the specification itself. We state
properties that should hold whenever its rules are followed, then prove that
every execution those rules permit satisfies the stated properties.

We decided to model the lifecycle of an entity as a state machine. We first
wrote the model in TLA+ and then ported it to Veil, a language for describing
state machines in Lean 4. Some lifecycle rules are expressed directly by the
types we choose. For example, we define a type with four possible values, so
Lean enforces that an entity’s lifecycle state is *new*, *managed*, *detached*,
or *removed*. Other rules relate several objects. Within one persistence
context, each persistent identity belongs to at most one entity instance. We
express this rule in Veil as an *invariant*, a condition that must hold
throughout an execution. Veil generates the statements we need to prove about
initialization and each allowed operation. We prove that the invariant holds
in the initial state and that each operation preserves it. By induction, it
then holds after any number of operations. Lean’s kernel checks each step of
that argument.

In {ref "lifecycle-proofs"}[Guarantees for complete executions],
we also prove properties that relate one state to the next. At any point in
an allowed execution, if an entity instance is detached, that same instance is
still detached after the next step. For {lit}`merge`, we can say more about
the object passed as its argument. Every successful merge preserves that
object’s lifecycle state and persistent identity. If the argument was new or
detached, the object returned by {lit}`merge` is a different Java instance.
We also prove what {lit}`EntityManager.contains()` reports after each modeled
operation. For example, immediately after a managed instance is removed the
answer is false, even though the instance still occupies its identity in the context.

Our {ref "lifecycle-checks"}[finite regression checks]
test whether the port preserves the behavior of the earlier TLA+ model
in a finite configuration. With three Java objects and two usable persistent
identities, we compare every reachable state and transition in Veil with the
results saved from the TLA+ model checker in {lit}`verification/`. We also
replay a sequence of 17 lifecycle operations and check that every permitted
identity choice lets the sequence run to completion. Repeating these
comparisons after an edit lets us detect changes in the model’s behavior.

Another way to verify an implementation is to check its recorded behavior
against a formal specification. This technique is called *trace validation*.
To apply it to Hibernate ORM, we could add tracing to its lifecycle operations,
run its Java test suite, and save the sequence of calls and resulting entity
states to text files. A checker could then follow each trace and verify that
the Veil model permits every observed step. This would complement the Jakarta
Persistence Technology Compatibility Kit (TCK) by checking the lifecycle
behavior exercised by Hibernate’s tests.

Once Lean has checked a proof, we can ask what assumptions the result depends
on. Lean calls a statement accepted without proof an *axiom*. A theorem can
depend on an axiom indirectly, through another theorem used in its proof. Our
{ref "lifecycle-audit"}[proof trust audit]
follows those dependencies for every theorem in the
lifecycle model. During each build, it checks that the main guarantees
exist as theorems and that every model theorem depends only on axioms from an
explicit list of three standard Lean axioms. An unfinished proof or a solver
answer accepted without a checked proof would introduce an axiom outside that
list and cause the build to fail.

{include 1 Lifecycle.Proofs}

{include 1 Lifecycle.Checks}

{include 1 Lifecycle.Audit}

# Open questions
%%%
tag := "open-question"
number := false
%%%

Formalizing the specification requires us to make our interpretation of its
wording explicit. Lean proves that the resulting model satisfies the properties
we state. Where the wording is ambiguous, another interpretation may be just
as plausible. The examples in this section show how writing the formalization
differently can reveal that an expected property no longer holds. This helps
us identify ambiguous wording in the original specification and catch bugs in
the rules before anyone implements them.

## Merging a removed entity
%%%
number := false
%%%

What should {lit}`merge(a)` do when {lit}`a` is detached
and another object with the same persistent identity is marked for removal?
Suppose {lit}`Book` has no version or relationships, a book with ID {lit}`7L`
exists, and a transaction is active.

```
Book a = em.find(Book.class, 7L);
em.detach(a);
Book b = em.merge(a);  // a stays detached. b is managed.
em.remove(b);
Book c = em.merge(a);  // The argument is still a.
```

Two readings are plausible. The uniqueness rule in §3.6.10 suggests that
{lit}`b` still occupies the identity and blocks creation of a copy. Read on its
own, §3.6.9.2 calls for a new copy because there is no *managed* instance with
that identity. To test the second reading, {lit}`lake run failOnDuplicateIdentity`
applies the diff below to a temporary copy of the model's {lit}`Merge` action
and runs Veil's finite model checker. The line is the condition for creating
a fresh copy of the detached source {lit}`e` (here, {lit}`a`).

```
-      require ∀ other, belongsToContext other → pid other ≠ pid e
+      require ∀ other, e_phase other = managed → pid other ≠ pid e
```

The original line requires every object in the context to have a persistent
identity different from {lit}`a`'s. After {lit}`remove(b)`, {lit}`b` still
belongs to the context and has the same identity as {lit}`a`, so it blocks
creation of {lit}`c`. This preserves uniqueness but leaves the outcome of the
Java call open. The model specifies no successful merge for this case.

The replacement checks only objects whose lifecycle state is {lit}`managed`.
It skips {lit}`b` because its state is {lit}`removed`. The final {lit}`merge(a)`
can now create {lit}`c`, leaving two objects in the context with the same
persistent identity. Veil reports the resulting violation of {lit}`uniqueIdentity`
(§3.6.10).

{specBoundary "begin:notice"}

Copyright (c) 2019, 2024 Eclipse Foundation.

# Eclipse Foundation Specification License - v1.1
%%%
tag := "specification-license"
number := false
%%%

By using and/or copying this document, or the Eclipse document from which this statement is linked or incorporated by reference, you (the licensee) agree that you have read, understood, and will comply with the following terms and conditions:

Permission to copy, and distribute the contents of this document, or the Eclipse Foundation document from which this statement is linked, in any medium for any purpose and without fee or royalty is hereby granted, provided that you include the following on ALL copies of the document, or portions thereof, that you use:

- link or URL to the original Eclipse Foundation document.

- All existing copyright notices, or if one does not exist, a notice (hypertext is preferred, but a textual representation is permitted) of the form: "Copyright (c) \[$date-of-document\] Eclipse Foundation AISBL [\[url to this license\]](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#url%20to%20this%20license) "

Inclusion of the full text of this NOTICE must be provided. We request that authorship attribution be provided in any software, documents, or other items or products that you create pursuant to the implementation of the contents of this document, or any portion thereof.

No right to create modifications or derivatives of Eclipse Foundation documents is granted pursuant to this license, except anyone may prepare and distribute derivative works and portions of this document in software that implements the specification, in supporting materials accompanying such software, and in documentation of such software, PROVIDED that all such works include the notice below. HOWEVER, the publication of derivative works of this document for use as a technical specification is expressly prohibited.

The notice is:

"Copyright (c) \[$date-of-document\] Eclipse Foundation AISBL. This software or document includes material copied from or derived from \[title and URI of the Eclipse Foundation specification document\]."

## Disclaimers
%%%
number := false
%%%

THIS DOCUMENT IS PROVIDED "AS IS," AND TO THE EXTENT PERMITTED BY APPLICABLE LAW THE COPYRIGHT HOLDERS AND THE ECLIPSE FOUNDATION AISBL MAKE NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, OR TITLE; THAT THE CONTENTS OF THE DOCUMENT ARE SUITABLE FOR ANY PURPOSE; NOR THAT THE IMPLEMENTATION OF SUCH CONTENTS WILL NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.

TO THE EXTENT PERMITTED BY APPLICABLE LAW THE COPYRIGHT HOLDERS AND THE ECLIPSE FOUNDATION AISBL WILL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF ANY USE OF THE DOCUMENT OR THE PERFORMANCE OR IMPLEMENTATION OF THE CONTENTS THEREOF.

The name and trademarks of the copyright holders or the Eclipse Foundation AISBL may NOT be used in advertising or publicity pertaining to this document or its contents without specific, written prior permission. Title to copyright in this document will at all times remain with copyright holders.

{specBoundary "end:notice"}
