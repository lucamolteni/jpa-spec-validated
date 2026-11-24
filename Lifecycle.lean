import Lifecycle.Model
import Lifecycle.Proofs
import Lifecycle.Checks
import Lifecycle.Audit

open Verso.Genre Manual

#doc (Manual) "Jakarta Persistence: Entity Instance Lifecycle" =>

This book models how construction and lifecycle operations affect an entity's
state and persistent identity in one persistence context. Sections 2.1 and 2.4
introduce entity instances and identity. Selected parts of section 3.6 pair
the lifecycle rules with checked Lean/Veil code. The proofs, finite regression
checks, and proof trust audit follow.

{include 1 Lifecycle.Model}

{include 1 Lifecycle.Proofs}

{include 1 Lifecycle.Checks}

{include 1 Lifecycle.Audit}
