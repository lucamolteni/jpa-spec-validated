import VersoManual
import Veil

open Lean
open Verso ArgParse Doc Elab Genre Manual

namespace Lifecycle.Document

-- Invisible boundaries let preservation checks identify original prose across headings.
block_extension Block.spec (boundary : String) where
  data := Json.str boundary
  traverse _ _ _ := pure none
  toHtml := open Verso.Output.Html in
    some <| fun _ _ _ data _ => do
      let .str boundary := data
        | reportError "Expected specification boundary" *> pure .empty
      pure {{<span data-spec={{boundary}}></span>}}
  toTeX := some <| fun _ _ _ _ _ => pure .empty

structure SpecBoundary where
  value : String

meta instance : FromArgs SpecBoundary DocElabM where
  fromArgs := SpecBoundary.mk <$> .positional `boundary .string

@[block_command]
meta def specBoundary : BlockCommandOf SpecBoundary := fun ⟨boundary⟩ => do
  ``(Verso.Doc.Block.other (Block.spec $(quote boundary)) #[])

-- Keep project commentary visibly distinct from the specification.
block_extension Block.formalization where
  traverse _ _ _ := pure none
  toHtml := open Verso.Output.Html in
    some <| fun _ go _ _ content => do
      pure {{<aside class="formalization" style="border-left: 3px solid #718096; padding-left: 1em;">
        {{← content.mapM go}}
      </aside>}}
  toTeX := some <| fun _ go _ _ content => do
    return .seq (← content.mapM go)

@[directive]
meta def formalization : DirectiveExpanderOf Unit := fun () blocks => do
  let content ← blocks.mapM elabBlock
  ``(Verso.Doc.Block.other Block.formalization #[ $[ $content ],* ])

end Lifecycle.Document
