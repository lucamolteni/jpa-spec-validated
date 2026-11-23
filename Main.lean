import VersoManual
import Lifecycle.Document

open Verso Doc Genre Manual

-- Load the compiled document without importing the finite-check driver's `main`.
-- This keeps `lake env lean --run Lifecycle/Checks.lean` and all its declarations.
unsafe def main (args : List String) : IO UInt32 := do
  Lean.initSearchPath (← Lean.findSysroot)
  Lean.withImportModules #[{ module := `Lifecycle }] {} fun env => do
    let name := %docName Lifecycle
    let some info := env.find? name | throw <| IO.userError "Missing compiled lifecycle book"
    unless info.type == Lean.mkApp (Lean.mkConst ``VersoDoc) (Lean.mkConst ``Manual) do
      throw <| IO.userError "Expected a compiled Verso Manual document"
    let book ← IO.ofExcept <| env.evalConst (VersoDoc Manual) {} name (checkMeta := false)
    -- The model spans JPA chapters 2 and 3. Promote those chapters into the
    -- book instead of adding a document-title level to the specification TOC.
    let part := book.toPart
    let some model := part.subParts[0]? | throw <| IO.userError "Missing model document"
    let part := { part with
      content := part.content ++ model.content
      subParts := model.subParts ++ part.subParts.extract 1 part.subParts.size }
    manualMain part (options := args) (config := {
      destination := ".lake/build/book"
      emitHtmlSingle := .immediately
      emitHtmlMulti := .no
      rootTocDepth := none
    })
