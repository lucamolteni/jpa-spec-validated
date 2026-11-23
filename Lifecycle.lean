import Lifecycle.Model
import Lifecycle.Proofs
import Lifecycle.Checks
import Lifecycle.Audit

open Verso.Genre Manual

#doc (Manual) "Jakarta Persistence: Entity Instance Lifecycle" =>

This book introduces entities and identity with selected Jakarta Persistence
4.0-M4 sections (§2.1, §2.2.2, and the text of §2.4 before its subsections),
then presents the complete §3.6 together with an executable Lean/Veil model,
its proofs, finite regression checks, and proof trust audit.
All project commentary and checked Lean code are formalization additions.

{include 1 Lifecycle.Model}

{include 1 Lifecycle.Proofs}

{include 1 Lifecycle.Checks}

{include 1 Lifecycle.Audit}
