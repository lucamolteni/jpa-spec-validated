import Lifecycle.Model
import Lifecycle.Proofs
import Lifecycle.Checks
import Lifecycle.Audit

open Verso.Code.External
open Verso.Genre Manual
open Lifecycle.Document

#doc (Manual) "Jakarta Persistence" =>

This book models how construction and lifecycle operations affect an entity's
state and persistent identity in one persistence context. Sections 2.1 and 2.4
introduce entity instances and identity. Selected parts of section 3.6 pair
the lifecycle rules with checked Lean/Veil code. The proofs, finite regression
checks, and proof trust audit follow.

{include 1 Lifecycle.Model}

{include 1 Lifecycle.Proofs}

{include 1 Lifecycle.Checks}

{include 1 Lifecycle.Audit}

# Open question
%%%
tag := "open-question"
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
