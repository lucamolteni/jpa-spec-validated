import VersoManual
import Veil
import Lifecycle.Document

open Verso.Code.External
open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open Lifecycle.Document

set_option veil.smt.trust false
set_option veil.solver "grind"
set_option verso.code.warnLineLength 200

#doc (Manual) "Entity foundations, lifecycle, and specification notice" =>
%%%
tag := "lifecycle-model"
number := false
%%%


:::formalization
_Formalized Specification_

The numbered sections are excerpts from Jakarta Persistence 4.0-M4
(May 25, 2026, DRAFT), authored by the Jakarta Persistence Team. Each excerpt keeps
its original section number.
Blocks labelled _Formalized Specification_ contain the project's explanations
and checked Lean code.

Copyright (c) 2019, 2024 Eclipse Foundation.
Copyright (c) 2026 Eclipse Foundation AISBL. This software or document includes
material copied from or derived from [Jakarta Persistence 4.0-M4](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html).
The complete Eclipse Foundation Specification License v1.1 notice appears below.
:::

{specBoundary "begin:entities"}

# 2. Entities
%%%
number := false
%%%

{specBoundary "end:entities"}

{specBoundary "begin:a18"}

## 2.1. The Entity Class
%%%
number := false
%%%

The entity class must be annotated with the {lit}`Entity` annotation or declared as an {lit}`entity` in its XML descriptor.

- The entity class must be a top-level class or a static inner class. An enum, record, or interface may not be designated as an entity.

- The entity class must have a {lit}`public` or {lit}`protected` constructor with no parameters, which is called by the persistence provider runtime to instantiate the entity.\[[2](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_2)\] This constructor is usually declared in the Java source code, but it might be added using source or bytecode processing by the build process or runtime environment.\[[3](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_3)\] The entity class may have additional constructors for use by the application.

- The entity class must be non-{lit}`final`. Every method and persistent instance variable of the entity class must also be non-{lit}`final`.

An entity might be an abstract class, or it might be a concrete class. An entity may extend a non-entity class, or it may extend another entity class. A non-entity class may extend an entity class.

The persistent state of an entity is represented by instance variables, which may correspond to JavaBeans properties. An instance variable may be directly accessed only within the methods of the entity, by the entity instance itself. An instance variable of an entity must _not_ be directly accessed by a client of the entity. The state of the entity is available to clients only through the methods of the entity—​that is, via accessor (getter/setter) methods, or via other business methods.

{specBoundary "end:a18"}

{specBoundary "begin:_footnotedef_2"}

[2](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_2). The term "persistence provider runtime" refers to the runtime environment of the persistence implementation. In a JakartaEE environment, this might be the Jakarta EE container itself, or a third-party persistence provider implementation integrated with the container.

{specBoundary "end:_footnotedef_2"}

{specBoundary "begin:_footnotedef_3"}

[3](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_3). When the constructor is added by tooling or by the container, the entity source code is not portable to environments where such tooling is unavailable.

{specBoundary "end:_footnotedef_3"}

:::formalization
_Formalized Specification_

An entity class describes a kind of Java object;
an entity instance is an individual object of that class. For example, suppose
that both {lit}`Person` and {lit}`Employee` are entity classes and
{lit}`Employee` extends {lit}`Person`. Creating two {lit}`Employee` objects
produces two instances of the same entity class.

Our lifecycle model represents individual instances. It assumes they belong
to valid entity classes; it does not check annotations, constructors, or the
other class requirements above.

We use Veil, a modeling language embedded in Lean, to declare the model and its
operations. The following command opens a module named {lit}`EntityLifecycle`.

```lean
veil module EntityLifecycle
```

The type {lit}`entity` represents individual Java objects, the instances
discussed in section 2.1. Each value identifies one possible object. The model
does not record its class or fields.

```lean
type entity
```
:::

{specBoundary "begin:a132"}

## 2.4. Primary Keys and Entity Identity
%%%
number := false
%%%

Every entity must have a primary key. The value of its primary key uniquely identifies an entity instance within a persistence context and to operations of the {lit}`EntityManager` or {lit}`EntityAgent`, as described in [Chapter 3](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a1060), and represents the _persistent identity_ of the instance, a concept which is defined more carefully later in [Section 3.6.10](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#managed-entities).

The primary key must be declared by:

- the entity class that is the root of the entity hierarchy, or

- a mapped superclass that is a (direct or indirect) superclass of all entity classes in the entity hierarchy.

A primary key must be defined exactly once in each entity hierarchy.

> *Note*

  Terminology Note: In the community, the primary key of an entity is usually called its _identifier_, but for historical reasons that term is not used in this specification.

A primary key comprises one or more fields or properties (attributes) of the entity class.

- A _simple primary key_ is a single persistent field or property of the entity class whose type is one of the legal simple primary key types listed below. The {lit}`Id` annotation defined in [Section 11.2.24](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14827) or {lit}`id` XML element must be used to identify the simple primary key.

- A _composite primary key_ may be declared as either a single persistent field or property, or as a set of fields or properties, as described below.\[[11](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_11)\] A _primary key class_ must be defined to represent the composite primary key.

  - If the composite primary key is represented by a single field or property of the entity, the {lit}`EmbeddedId` annotation defined by [Section 11.2.18](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14687) identifies the primary key, and the type of the annotated field or property is the primary key class.

  - Otherwise, when the composite primary key encompasses multiple fields or properties, the {lit}`Id` annotation defined by [Section 11.2.24](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14827) identifies the fields and properties which belong to the composite key, and the {lit}`IdClass` annotation defined by [Section 11.2.25](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14836) must specify the primary key class.

A simple primary key or a field or property belonging to a composite primary key must have one of the following basic types:

- any Java primitive type, or {lit}`java.lang` wrapper for a primitive type, \[[12](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_12)\]

- {lit}`java.lang.String`,

- {lit}`java.util.UUID`,

- {lit}`java.time.LocalDate`, {lit}`java.util.Date`, or {lit}`java.sql.Date`,

- {lit}`BigDecimal` or {lit}`BigInteger` from {lit}`java.math`.

If a primary key field or property has type {lit}`java.util.Date`, the temporal type must be explicitly specified as {lit}`DATE` using the {lit}`Temporal` annotation defined by [Section 11.2.56](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a16361), or by equivalent XML.

If the primary key is a composite primary key derived from the primary key of another entity, the primary key may contain an attribute whose type is that of the primary key of the referenced entity, as specified below in [Section 2.4.2](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a149).

An entity with a primary key involving any type other than the types listed above is not portable. If the primary key is generated by the persistence provider, as defined by [Section 11.2.23](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14790), and its type is not {lit}`long`, {lit}`int`, {lit}`java.util.UUID`, {lit}`java.lang.String`, {lit}`java.lang.Long`, or {lit}`java.lang.Integer`, the entity is not portable.

The application must not change the value of the primary key of an entity instance after the instance is made persistent\[[13](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_13)\]. If the application does change the value of a primary key of an entity instance after the entity instance is made persistent, the behavior is undefined.\[[14](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnotedef_14)\]

{specBoundary "end:a132"}

{specBoundary "begin:_footnotedef_11"}

[11](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_11). Composite primary keys often arise when mapping a legacy database with primary keys comprising multiple columns.

{specBoundary "end:_footnotedef_11"}

{specBoundary "begin:_footnotedef_12"}

[12](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_12). Although tolerated by Jakarta Persistence, approximate numeric types (floating point types) should never be used in primary keys.

{specBoundary "end:_footnotedef_12"}

{specBoundary "begin:_footnotedef_13"}

[13](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_13). This includes not changing the value of a mutable type that is primary key or an attribute of a composite primary key.

{specBoundary "end:_footnotedef_13"}

{specBoundary "begin:_footnotedef_14"}

[14](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#_footnoteref_14). The implementation may, but is not required to, throw an exception. Portable applications must not rely on any such specific behavior.

{specBoundary "end:_footnotedef_14"}

:::formalization
_Formalized Specification_

Object identity tells us whether two references point to the same Java object.
Persistent identity tells us which persistent entity an object represents.
The root entity class is the highest entity class in the inheritance hierarchy.
Section 3.6.10 defines persistent identity as the pair consisting of that class
and the primary-key value.

In the example from section 2.1, suppose {lit}`Person` is the root entity class.
An {lit}`Employee` with primary key 7 has persistent identity {lit}`(Person, 7)`.
If {lit}`Book` is another root entity class, a book with key 7 has a different
persistent identity, {lit}`(Book, 7)`. Conversely, a detached
{lit}`Employee` and the managed copy returned by merge can be distinct Java
objects with the same persistent identity.

The model uses the abstract type {lit}`identity` to compare persistent identities.
Its declaration gives no access to the class or key separately. The type also
includes {lit}`noIdentity`, introduced in section 3.6 to represent the absence
of a persistent identity.

```lean
type identity
```
:::

{specBoundary "begin:a1060"}

# 3. Entity Operations
%%%
number := false
%%%

{specBoundary "end:a1060"}

{specBoundary "begin:a1929"}

## 3.6. Entity Instance Lifecycle
%%%
number := false
%%%

Any entity instance can be characterized as being in one of the following _lifecycle states_ with respect to a given persistence context:

- A *new* entity instance has no persistent identity and is not yet associated with any persistence context.

- A *managed* entity instance is an instance with a persistent identity that is currently associated with a persistence context.

- A *detached* entity instance is an instance with a persistent identity that is not (or no longer) associated with a persistence context.

- A *removed* entity instance is an instance with a persistent identity, and associated with a persistence context, that is scheduled for removal from the database upon transaction commit.

Certain operations of {lit}`EntityManager` modify the lifecycle state of an entity instance. The following subsections describe the effect of such lifecycle operations.

{specBoundary "end:a1929"}

:::formalization
_Formalized Specification_

With entity instances and persistent identities defined
in Chapter 2, we now describe their lifecycle states and operations within one
persistence context.

The four lifecycle states defined above become an enumeration:

```lean
enum phase = {new, managed, detached, removed}
```

We use {lit}`noIdentity` to represent the absence of a persistent identity.
In Veil, {lit}`individual` declares a single named value of the specified type,
and {lit}`immutable` means that operations cannot change that value.

```lean
immutable individual noIdentity : identity
```

To check the lifecycle of the entities, we now define a relation and a function.
The first one, {lit}`created`, tracks whether an instance has been constructed,
whether or not it is attached to a persistence context. A newly constructed
instance is transient, but {lit}`created` remains true when it becomes managed
or detached. The function {lit}`e_phase` instead tracks the phase the instance is in.

You might wonder why {lit}`e_phase e = new` is not enough and why we also need to
track whether the instance has been constructed.

That's because {lit}`new` is the initial value of {lit}`e_phase e`, and the model
includes identifiers for possible instances that haven't yet been constructed.
So we must define how {lit}`e_phase e` behaves even when the object represented by
{lit}`e` doesn't exist yet, that is, when {lit}`created e = false`. In that case,
{lit}`new` is only a placeholder.

For each entity instance, we define a {lit}`created` relation to state whether
it has been constructed. “Relation” here is a mathematical term used in proof
assistants such as Lean. It does not mean a JPA relationship.
A {lit}`relation` records a true-or-false fact for its arguments.
In Lean, predicates commonly return {lit}`Prop`. Veil's stored relations return
{lit}`Bool` so their values can be computed when executing the model checker.
Here, {lit}`entity → Bool` means that each entity has a Boolean value, which
operations can update.

```lean
relation created : entity → Bool
```

The function {lit}`e_phase` records each instance's lifecycle state.

```lean
function e_phase : entity → phase
```

The function {lit}`pid` records each instance's persistent identity, or
{lit}`noIdentity` if it has none.

```lean
function pid : entity → identity
```

With these declarations in place, {lit}`#gen_state` generates the Lean type that
holds the model's state.

```lean
#gen_state
```

So far, we have introduced the type {lit}`identity` and named one value of that
type, {lit}`noIdentity`, to represent the absence of a persistent identity.
We have not yet required the type to contain any other values. If {lit}`noIdentity`
were its only value, the persist operation could never assign a persistent
identity to a new instance.

We therefore assume that the same type contains at least one other value that
can represent a persistent identity.

```lean
assumption [nonempty_identities] ∃ i, i ≠ noIdentity
```

To express the specification's requirements and reason about them in the
following proofs, we introduce names for three conditions on the model's state:

- {lit}`belongsToContext e`: instance {lit}`e` belongs to the persistence context
  represented by this model.
- {lit}`pendingRemoval e`: instance {lit}`e` is marked for database deletion.
- {lit}`identityAvailable i` means identity {lit}`i` is available to assign to an instance.

These conditions are defined using the information we already record: which
instances have been constructed, their lifecycle states, and their persistent
identities. Veil calls these definitions *ghost relations*: they give us
vocabulary for describing and reasoning about the state without adding
independently stored information.

The model describes one fixed persistence context. Each instance's lifecycle
state is interpreted relative to that context. Constructing an instance leaves
it in the {lit}`new` state, outside the context. Successfully persisting that
instance changes its state to {lit}`managed`, establishing its association with
the context.

The condition {lit}`belongsToContext e` holds when {lit}`e` has been constructed
and its lifecycle state is either {lit}`managed` or {lit}`removed`. The check
{lit}`created e` only establishes that the object has been constructed; it says
nothing about who constructed it. The {lit}`removed` state means marked for
database deletion while still associated with the context, as defined in the
specification above. This membership condition therefore differs from
{lit}`EntityManager.contains()`, which excludes removed instances.

When an operation changes {lit}`e_phase e` to {lit}`detached`, the membership
condition is no longer satisfied, so {lit}`belongsToContext e` is false.
We use this condition in the identity uniqueness requirement and the merge
operation.

```lean
ghost relation belongsToContext (e : entity)
  := created e ∧ (e_phase e = managed ∨ e_phase e = removed)
```

The condition {lit}`pendingRemoval e` holds when instance {lit}`e` has been
constructed and its lifecycle state is {lit}`removed`. It describes scheduled
database deletion; the model does not represent the deletion itself.

```lean
ghost relation pendingRemoval (e : entity)
  := created e ∧ e_phase e = removed
```

The condition {lit}`identityAvailable i` holds when {lit}`i` is an actual persistent identity
and no constructed instance has that identity. This includes checking detached
instances, even though they are outside the context. We exclude
{lit}`noIdentity` because it represents the absence of an identity.
For every instance {lit}`e`, if it has been constructed, its
identity must differ from {lit}`i`.

```lean
ghost relation identityAvailable (i : identity)
  := i ≠ noIdentity ∧ ∀ e, created e → pid e ≠ i
```

Initially, no instances have been constructed. We give every possible instance
the default lifecycle state {lit}`new` and the identity value {lit}`noIdentity`.
The {lit}`after_init` block establishes these initial values. Here the uppercase
variable {lit}`E` makes each assignment apply to every entity, and {lit}`:=`
assigns a value.

```lean
after_init {
  created E := false
  e_phase E := new
  pid E := noIdentity
}
```
:::

{specBoundary "begin:lifecycle-operations"}

### 3.6.1. Lifecycle Operations
%%%
number := false
%%%

The fundamental operations of an {lit}`EntityManager` are:

- {lit}`persist()` to make a new entity persistent, as defined in [Section 3.6.3](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#persist),

- {lit}`remove()`, to remove a persistent entity from the database, as defined in [Section 3.6.4](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#remove),

- {lit}`flush()`, to force synchronization of pending modifications with the database, as defined in [Section 3.6.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#flush),

- {lit}`refresh()`, to reload an entity from the database, as defined in [Section 3.6.7](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#refresh),

- {lit}`detach()`, to disassociate an entity from its persistence context, as defined in [Section 3.6.8](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#detach),

- {lit}`merge()`, to copy the state of a detached instance into the persistence context, and

- {lit}`lock()` to obtain a lock an entity instance or to upgrade the lock level currently held, as defined in [Section 3.9](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a2052).

The methods {lit}`persist()`, {lit}`remove()`, {lit}`refresh()`, {lit}`detach()`, and {lit}`merge()` are called _lifecycle operations_.

The {lit}`cascade` annotation element of a relationship modeling annotation, as defined in [Section 2.11](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a516), specifies which lifecycle operations propagate to associated entities. Each lifecycle operation is identified by the corresponding member of the enumeration {lit}`CascadeType`.

```
public enum CascadeType {ALL, PERSIST, MERGE, REMOVE, REFRESH, DETACH}
```

The value {lit}`cascade=ALL` is equivalent to {lit}`cascade={PERSIST, MERGE, REMOVE, REFRESH, DETACH}`.

> *Note*

  The cascade functionality is most typically used to model parent-child relationships. A closely related feature is orphan removal, which is defined below in [Section 3.6.5](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#orphan-removal).

Information about how lifecycle operations interact with transactions may be found below in [Section 3.7.2](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#entity-manager-transactions).

{specBoundary "end:lifecycle-operations"}

{specBoundary "begin:entity-instance-creation"}

### 3.6.2. Entity Instance Creation
%%%
number := false
%%%

An instance of an entity class may be created using the {lit}`new` operator. A newly instantiated instance is not considered persistent—​that is, it is not considered to represent a record in the database—​and the new instance is not associated with a persistence context. A new instance is not considered to have a well-defined persistent identity until it is made persistent.

{specBoundary "end:entity-instance-creation"}

:::formalization
_Formalized Specification_

You can't create already created entities

```lean
action Create (e : entity) {
  require ¬ created e
  created e := true
  assert ¬ belongsToContext e
  assert pid e = noIdentity
}
```
:::

{specBoundary "begin:persist"}

### 3.6.3. Persisting an Entity Instance
%%%
number := false
%%%

A new instance becomes persistent when it is passed as an argument to the {lit}`persist()` method of {lit}`EntityManager` or when the persist operation cascades from another instance to the new instance.

Let {lit}`e` be an instance of an entity class. If {lit}`e` is passed as an argument to the {lit}`persist()` method of {lit}`EntityManager`, or if the persist operation is applied to {lit}`e` via cascade:

- if {lit}`e` is a new entity, it becomes managed and a new record represented by {lit}`e` will be inserted into the database at or before transaction commit as a result of the flush operation specified below in [Section 3.6.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#flush);

- if {lit}`e` is a managed entity already associated with the persistence context, {lit}`e` itself is ignored by the persist operation;

- if {lit}`e` is a removed entity, it becomes managed; or

- if {lit}`e` is a detached entity, either an {lit}`EntityExistsException` is thrown immediately, or an {lit}`EntityExistsException` or some other subtype of {lit}`PersistenceException` is thrown when the persistence context is flushed or when the transaction commits.

- If {lit}`e` is new, managed, or removed, the persist operation is also applied to every entity {lit}`t` referenced by a relationship owned by {lit}`e` and annotated with the {lit}`cascade` element value {lit}`cascade=PERSIST` or {lit}`cascade=ALL` or mapped as such by the equivalent XML descriptor element.

Ordinarily, the persist operation assigns a persistent identity to the entity. If the primary key of the entity is a generated value, as defined by [Section 11.2.23](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a14790), the primary key is generated as part of the persist operation, and the generated value is made available to the application by setting the primary key field or property of the entity. As a special exception to this rule, if the primary key generation strategy of an entity is {lit}`IDENTITY`, the persistence provider is permitted to delay assignment of the primary key until pending modifications are synchronized with the database, as defined by [Section 3.6.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#flush). Indeed, when {lit}`persist()` is called with no active transaction, the persistence provider is _required_ to delay generation and assignment of {lit}`IDENTITY` primary keys.

{specBoundary "end:persist"}

:::formalization
_Formalized Specification_

Persist requires a created instance whose lifecycle
state is new, managed, or removed. The two {lit}`require` conditions below
exclude instances that have not been constructed and calls on detached instances.

For a new instance, {lit}`let i : identity :| identityAvailable i` chooses an
available identity. The symbol {lit}`:|` introduces the condition on that
choice. Any identity satisfying it is allowed, and the proofs must cover every
such choice. The action assigns this identity and makes the instance managed.

For a removed instance, the action changes its state back to managed, cancelling
its pending removal. For an already managed instance, neither branch applies,
so the modeled state remains unchanged.

```lean
action Persist (e : entity) {
  require created e
  require e_phase e ≠ detached
  if e_phase e = new then
    let i : identity :| identityAvailable i
    pid e := i
    e_phase e := managed
  else if e_phase e = removed then
    e_phase e := managed
}
```

Identity assignment and the change to managed happen in one model step. This
simplifies the specification's rules for delayed {lit}`IDENTITY` assignment.
Assigned identities are never released for reuse in this model. In a finite
model, persisting a new instance becomes impossible when no identity is
available. This limit does not represent a JPA exception.
:::

{specBoundary "begin:remove"}

### 3.6.4. Removal
%%%
number := false
%%%

A managed entity instance becomes removed when it is passed as an argument to the {lit}`remove()` method of {lit}`EntityManager` or when the remove operation cascades from another instance to the managed instance.

Let {lit}`e` be an instance of an entity class. If {lit}`e` is passed as an argument to the {lit}`remove()` method of {lit}`EntityManager`, or if the remove operation is applied to {lit}`e` via cascade:

- if {lit}`e` is a new entity, {lit}`e` itself is ignored by the remove operation;

- if {lit}`e` is a managed entity, it is marked as removed and the record represented by {lit}`e` is scheduled for deletion from the database at or before transaction commit as a result of the flush operation specified below in [Section 3.6.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#flush);

- if {lit}`e` is a removed entity, {lit}`e` itself is ignored by the remove operation; or

- if {lit}`e` is a detached entity, an {lit}`IllegalArgumentException` is thrown or a failure occurs later when the flush operation occurs.

- If {lit}`e` is new, managed, or removed, the remove operation is also applied to every entity {lit}`t` referenced by a relationship owned by {lit}`e` and annotated with the {lit}`cascade` element value {lit}`cascade=REMOVE` or {lit}`cascade=ALL` or mapped as such by the equivalent XML descriptor element.

The {lit}`remove()` method does not change the state held by fields of the entity instance itself.

{specBoundary "end:remove"}

:::formalization
_Formalized Specification_

Remove requires a created instance that is not
detached. It changes a managed instance's lifecycle state to {lit}`removed`.
For new or already removed instances, it leaves the state unchanged.

```lean
action Remove (e : entity) {
  require created e
  require e_phase e ≠ detached
  if e_phase e = managed then
    e_phase e := removed
}
```

The action does not change the instance's persistent identity. Since
{lit}`belongsToContext` includes removed instances, it also preserves context
membership.
The definition {lit}`pendingRemoval` becomes true when a managed instance is
removed; deletion of a database record is outside the model.
:::

{specBoundary "begin:refresh"}

### 3.6.7. Refreshing an Entity Instance
%%%
number := false
%%%

The state of a managed entity instance is refreshed from the database when it is passed as an argument to the {lit}`refresh()` method of {lit}`EntityManager` or when the refresh operation cascades from another instance to the managed instance.

Let {lit}`e` be an instance of an entity class. If {lit}`e` is passed as the first argument to the {lit}`refresh()` method of {lit}`EntityManager`, or if the refresh operation is applied to {lit}`e` via cascade:

- if {lit}`e` is a managed entity, the state of {lit}`e` is refreshed from the database by reading the record represented by {lit}`e` and modifying the state of {lit}`e` to match, overwriting any pending modifications made to the entity; or

- if {lit}`e` is a new, detached, or removed entity, the {lit}`IllegalArgumentException` is thrown.

- If {lit}`e` is managed, the refresh operation is also applied to every entity {lit}`t` referenced by a relationship owned by {lit}`e` and annotated with the {lit}`cascade` element value {lit}`cascade=REFRESH` or {lit}`cascade=ALL` or mapped as such by the equivalent XML descriptor element.

{specBoundary "end:refresh"}

:::formalization
_Formalized Specification_

Only a managed entity may successfully refresh.
Refresh reloads fields from the database, but neither fields nor database
contents are part of our state. The action therefore leaves the modeled state
unchanged.

Its only requirement is that the instance exists and is managed. With no
assignments in the body, this is an allowed step that preserves every value.

```lean
action Refresh (e : entity) {
  require created e ∧ e_phase e = managed
}
```
:::

{specBoundary "begin:detach"}

### 3.6.8. Evicting an Entity Instance from the Persistence Context
%%%
number := false
%%%

A managed entity instance is removed from the persistence context when it is passed as an argument to the {lit}`detach()` method of {lit}`EntityManager` or when the detach operation cascades from another instance to the managed instance.

Let {lit}`e` be an instance of an entity class. If {lit}`e` is passed as an argument to the {lit}`detach()` method of {lit}`EntityManager`, or if the detach operation is applied to {lit}`e` via cascade:

- if {lit}`e` is a managed entity, it is removed from the persistence context and becomes detached;

- if {lit}`e` is a new or detached entity, it is ignored by the detach operation;

- if {lit}`e` is a removed entity, it becomes detached, and the scheduled removal of the record represented by {lit}`e` is cancelled.

- If {lit}`e` is managed or removed, the detach operation is also applied to every entity {lit}`t` referenced by a relationship owned by {lit}`e` and annotated with the {lit}`cascade` element value {lit}`cascade=DETACH` or {lit}`cascade=ALL` or mapped as such by the equivalent XML descriptor element.

Portable applications should not pass removed entities that have been detached from the persistence context to methods of {lit}`EntityManager`.

Entities which referenced {lit}`e` before detachment continue to reference {lit}`e` after detachment.

> *Note*

  Pending modifications to the state of the entity, including removal of the entity, are never synchronized to the database after the entity is evicted from the persistence context. If such pending modifications exist, an application must call the {lit}`flush()` method before calling {lit}`detach()` if portable behavior is required. A portable application must not assume that pending modifications have not been written to the database if the {lit}`flush()` method was not called before {lit}`detach()`. More information about synchronization may be found above in [Section 3.6.6](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#flush).

{specBoundary "end:detach"}

:::formalization
_Formalized Specification_

Detach requires a created instance. It changes a
managed or removed instance to {lit}`detached` and leaves a new or already
detached instance unchanged. Its persistent identity is preserved in every case.

```lean
action Detach (e : entity) {
  require created e
  if e_phase e = managed ∨ e_phase e = removed then
    e_phase e := detached
}
```

After detachment, both {lit}`belongsToContext e` and {lit}`pendingRemoval e`
are false.
This represents leaving the context and, for a removed instance, cancelling
pending removal. We do not record whether an instance was removed before it
was detached, so the model does not enforce the specification's restriction on
passing such instances to later {lit}`EntityManager` calls.
:::

{specBoundary "begin:a1982"}

### 3.6.9. Detached Entities
%%%
number := false
%%%

{specBoundary "end:a1982"}

{specBoundary "begin:merge"}

#### 3.6.9.2. Merging Detached Entity State
%%%
number := false
%%%

The merge operation allows for the propagation of state from detached entities to managed instances associated with a persistence context. Given a detached instance, the merge operation returns a managed instance with the same persistent identity and state as the detached instance, but with a distinct Java object identity.

Let {lit}`e` be an instance of an entity class. If {lit}`e` is passed as an argument to the {lit}`merge()` method of {lit}`EntityManager`, or if the merge operation is applied to {lit}`e` via cascade, a merged object {lit}`e2` is produced:

- if {lit}`e` is a detached entity, the persistent state of {lit}`e` is copied to a pre-existing managed entity instance {lit}`e2` of the same identity or, if there is no such pre-existing managed entity, a new managed copy {lit}`e2` of {lit}`e` is created;

- if {lit}`e` is a new entity instance, a new managed entity instance {lit}`e2` is created and the state of {lit}`e` is {lit}`copied` to {lit}`e2`;

- if {lit}`e` is a removed entity instance, an {lit}`IllegalArgumentException` is thrown or a failure occurs later when the flush operation occurs; or

- if {lit}`e` is a managed entity, {lit}`e` itself is ignored by the merge operation and the merged object {lit}`e2` is taken to be identical to {lit}`e`.

- If {lit}`e` is new, managed, or detached, the merge operation is also applied to every entity {lit}`t` referenced by a relationship owned by {lit}`e` and annotated with the {lit}`cascade` element value {lit}`cascade=MERGE` or {lit}`cascade=ALL` or mapped as such by the equivalent XML descriptor element. For every such {lit}`t` referenced by {lit}`e`, {lit}`e2` is set to reference the object {lit}`t2` produced by applying the merge operation to {lit}`t`.

- For every entity {lit}`t` referenced by {lit}`e` via an association, navigation of the same association from {lit}`e2` yields a reference to a managed object {lit}`s` with the same persistent identity as {lit}`t`.

If {lit}`e` has a version, as defined in [Section 2.5](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a2060), the persistence provider must validate that {lit}`e` and {lit}`e2` have the same version, either during processing of the merge operation, or later when the flush operation occurs or when the transaction commits.

The persistence provider must ignore unfetched attributes of detached instances when merging. A persistence provider is permitted to report an exception if an entity instance with unfetched lazy attributes instantiated by a different persistence provider runtime is passed to {lit}`merge()`.

> *Note*

  When this sort of interoperability across different persistence provider runtimes from different vendors is required, the application must not use lazy loading.

{specBoundary "end:merge"}

:::formalization
_Formalized Specification_

Merge involves two instances: the source {lit}`e`
and the returned instance {lit}`target`. We include the result as an action
argument so that the model can describe which object is returned; the Java
method still takes only the source argument. The source must have been created
and must not be removed.

For a new source, the target must be an instance that has not yet been created.
The action assigns it an available identity and makes it managed. It leaves the source
new and without a persistent identity.

For a detached source, an existing target must be managed and have the source's
identity. If the target has not been created, the action first checks that no
instance in the context has that identity. It then creates a managed target
with the source's identity. In both cases, the source stays detached.

For a managed source, the final branch requires {lit}`target = e`: merge returns
the source itself and changes nothing. These cases form one action below.

```lean
action Merge (e target : entity) {
  require created e
  require e_phase e ≠ removed
  if e_phase e = new then
    require ¬ created target
    let i : identity :| identityAvailable i
    pid target := i
    created target := true
    e_phase target := managed
  else if e_phase e = detached then
    if created target then
      require belongsToContext target ∧ e_phase target = managed ∧ pid target = pid e
    else
      require ∀ other, belongsToContext other → pid other ≠ pid e
      created target := true
      e_phase target := managed
      pid target := pid e
  else
    require target = e
}
```

If a removed instance in the context has a detached source's identity, neither
detached branch can succeed: that instance is not a managed target, and its
presence prevents creation of another target. We exclude this situation from
the successful calls represented by the model.

Creating a managed copy requires an entity value that has not yet been used.
Merging a new source also requires an available identity, assigned in the same step.
If either required value is unavailable, the action cannot occur. As with
construction and persist, this is a model limit, not a JPA exception. Copying
fields and checking versions are outside the model.
:::

{specBoundary "begin:managed-entities"}

### 3.6.10. Managed Entities
%%%
number := false
%%%

It is the responsibility of the persistence provider to ensure that at most one entity instance belonging to a given persistence context has a given persistent identity. The persistent identity of an entity class instance is represented as a pair comprising:

1. the class of the root entity of the entity class inheritance hierarchy to which the entity class belongs, together with

2. the value of the primary key of the entity instance, as defined above in [Section 2.4](https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html#a132).

Therefore, if the entity type {lit}`X` is a subclass of the root entity type {lit}`Y`, and {lit}`x` is an instance of {lit}`X` with primary key {lit}`k`, the persistent identity of {lit}`x` is _({lit}`Y`,{lit}`k`)_.

It is the responsibility of the application to ensure that an instance of an entity class is associated with at most one persistence context. If an entity instance is made managed in more than one persistence context, the behavior is undefined and unportable.

The {lit}`contains()` method of {lit}`EntityManager` determines whether an entity instance is managed in the associated persistence context. The {lit}`contains()` method returns {lit}`true` if and only if:

- the argument is a managed entity instance associated with the given persistence context, and

- the argument entity is not marked as removed.

The effect of cascading persist, merge, remove, or detach is immediately visible to the {lit}`contains()` method, whereas the actual insertion, update, or deletion of the database record represented by the entity is deferred until the flush operation occurs.

{specBoundary "end:managed-entities"}

:::formalization
_Formalized Specification_

We now state the conditions that the model must
preserve. An {lit}`invariant` is a condition we prove true initially and after
every allowed operation. Its name in square brackets identifies the condition
in later proofs.

First, an instance is new if and only if it has no persistent identity.
The symbol {lit}`↔` means “if and only if,” so the condition applies in both
directions. The uppercase variable {lit}`E` makes this statement apply to every
entity value.

```lean
invariant [identityOK] (e_phase E = new ↔ pid E = noIdentity)
```

An instance that has not been constructed must retain its initial lifecycle
state and identity. Once an instance has been created, this condition places
no further restriction on it.

```lean
invariant [uncreatedOK] ¬ created E → e_phase E = new ∧ pid E = noIdentity
```

Finally, two instances in the context with the same persistent identity must
be the same Java object. We declare this as a {lit}`safety` property: a condition
that must hold in every reachable state. Here {lit}`E` and {lit}`OTHER` range
over every pair of instances.

```lean
safety [uniqueIdentity] belongsToContext E ∧ belongsToContext OTHER ∧ pid E = pid OTHER → E = OTHER
```

Because {lit}`belongsToContext` includes managed and removed instances,
uniqueness applies to both. Detached instances are outside the context and may
share an identity with a managed copy.

We prove that the initial state satisfies all three conditions, then show that
each operation preserves them whenever they hold before the operation.

The command {lit}`#gen_spec` turns our initialization, actions, and properties
into Lean definitions used by the proofs.

```lean
#gen_spec
```

Initially, every instance is new and has {lit}`noIdentity`, so the identity
condition holds. The command {lit}`prove_veil_invariant_goal` identifies the
initialization or action and the property to prove. The phrase {lit}`using tr`
selects its transition relation: the definition of the allowed before-and-after
states. After {lit}`by`, we give Lean the proof instructions.

The tactic {lit}`grind` automatically combines the available facts to construct
a proof. Lean's kernel checks that proof; we do not accept a solver's answer
without a proof.

```lean
prove_veil_invariant_goal initializer identityOK using tr by
  grind
```

Initialization also gives every uncreated instance its required defaults.

```lean
prove_veil_invariant_goal initializer uncreatedOK using tr by
  grind
```

No instance belongs to the context initially, so two context members cannot
have conflicting identities.

```lean
prove_veil_invariant_goal initializer uniqueIdentity using tr by
  grind
```

An unconstructed instance starts in phase {lit}`new` with {lit}`noIdentity`,
and {lit}`Create` changes only its construction flag. Since only managed and
removed instances belong to the context, both assertions in {lit}`Create` hold.
The {lit}`doesNotThrow` proof checks this for every construction from a state
satisfying the model's invariants. The {lit}`using wp` form works backward from
the assertions to the conditions before construction.

```lean
prove_veil_invariant_goal Create doesNotThrow using wp by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind
```

Creation also preserves the three invariants. The new instance is outside the
context, so it cannot duplicate the identity of a context member.

The uniqueness proof explicitly uses the fact that the four lifecycle states
are distinct. The command {lit}`have` names that fact {lit}`hd`, and
{lit}`simp` rewrites it into facts that {lit}`grind` can use.

```lean
prove_veil_invariant_goal Create identityOK using tr by
  grind

prove_veil_invariant_goal Create uncreatedOK using tr by
  grind

prove_veil_invariant_goal Create uniqueIdentity using tr by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind
```

Persist gives a new instance an actual identity when making it managed, or
makes a removed instance managed without changing its identity. It never
modifies an uncreated instance. The {lit}`identityAvailable` condition ensures that an
identity assigned to a new instance cannot collide with one in the context.

```lean
prove_veil_invariant_goal Persist identityOK using tr by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind

prove_veil_invariant_goal Persist uncreatedOK using tr by
  grind

prove_veil_invariant_goal Persist uniqueIdentity using tr by
  grind
```

Remove changes managed instances to removed. Both states require a persistent
identity and belong to the context, so the identity and uniqueness conditions
continue to hold. Uncreated instances are untouched.

```lean
prove_veil_invariant_goal Remove identityOK using tr by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind

prove_veil_invariant_goal Remove uncreatedOK using tr by
  grind

prove_veil_invariant_goal Remove uniqueIdentity using tr by
  grind
```

Refresh makes no assignments. Each of the three conditions therefore remains
true for exactly the same state as before the call.

```lean
prove_veil_invariant_goal Refresh identityOK using tr by
  grind

prove_veil_invariant_goal Refresh uncreatedOK using tr by
  grind

prove_veil_invariant_goal Refresh uniqueIdentity using tr by
  grind
```

Detach preserves identity while changing managed or removed instances to
detached. These states all have persistent identities. Removing an instance
from the context cannot introduce an identity conflict, and the action leaves
uncreated instances untouched.

```lean
prove_veil_invariant_goal Detach identityOK using tr by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind

prove_veil_invariant_goal Detach uncreatedOK using tr by
  grind

prove_veil_invariant_goal Detach uniqueIdentity using tr by
  grind
```

Merge either returns an existing managed instance or creates a managed target.
A new target receives an actual identity. For a new source, merge assigns an
available identity to the target. For a detached source, creation requires that
the source's identity is absent from the context. These conditions preserve
uniqueness, while all other uncreated instances retain their defaults.

```lean
prove_veil_invariant_goal Merge identityOK using tr by
  have hd := phase_EnumClass.distinct (phase := phase)
  simp [distinctN_cons] at hd
  grind

prove_veil_invariant_goal Merge uncreatedOK using tr by
  grind

prove_veil_invariant_goal Merge uniqueIdentity using tr by
  grind
```

With the individual proofs supplied, {lit}`#check_invariants` checks that the
invariant obligations have been discharged.

```lean
#check_invariants
```

The command {lit}`#gen_theorems` assembles the checked results into theorems
that the execution proofs in the next chapter can use.

```lean
#gen_theorems
```

The command {lit}`#gen_executable` generates executable versions of the same
actions for finite model checks.

```lean
#gen_executable
```

We can now explore a small instance of the model. The Lean type {lit}`Fin 3`
contains the values 0, 1, and 2. We use these for three possible Java objects
and three identity values. Reserving identity 0 for {lit}`noIdentity` leaves
two actual persistent identities.

The command {lit}`#model_check interpreted` explores the reachable states of
this finite instance and checks the model's properties. This is an executable
check for these bounds; the proofs above apply without those bounds.

```lean
#model_check interpreted { entity := Fin 3, identity := Fin 3 } { noIdentity := 0 }
```

This completes the lifecycle module.

```lean
end EntityLifecycle
```
:::

{specBoundary "begin:notice"}

Copyright (c) 2019, 2024 Eclipse Foundation.

# Eclipse Foundation Specification License - v1.1
%%%
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
