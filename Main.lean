import VersoManual
import Lifecycle.Document

open Verso Doc Genre Manual

private partial def sectionIds (state : TraverseState) (part : Part Manual) : List String := Id.run do
  let children := part.subParts.toList.flatMap (sectionIds state)
  let some id := part.metadata.bind (·.id) | return children
  let some dest := state.externalTags[id]? | return children
  return dest.htmlId.toString :: children

-- The pinned Verso renderer leaves the root contents links empty in single-page
-- HTML. Fill them with the section IDs from the same document traversal.
private def linkSinglePageContents : ExtraStep := fun mode config state book => do
  unless mode matches .single do return
  let path := config.destination / "html-single" / "index.html"
  let html ← IO.FS.readFile path
  let some start := html.find? "<ol class=\"section-toc\">" | return
  let rest := html.sliceFrom start
  let some stop := rest.find? "</section>" | return
  let contents := (rest.sliceTo stop).toString
  let first :: entries := contents.splitOn "<a href=\"\">" | return
  if entries.isEmpty then return
  let ids := book.subParts.toList.flatMap (sectionIds state)
  unless ids.length == entries.length do
    throw <| IO.userError "Section count differs from the single-page table of contents"
  let links := String.join (ids.zipWith (fun id entry => s!"<a href=\"#{id}\">{entry}") entries)
  IO.FS.writeFile path ((html.sliceTo start).toString ++ first ++ links ++ (rest.sliceFrom stop).toString)

private partial def insertPersistExample (part : Part Manual) (exampleBlocks : Array (Doc.Block Manual)) :
    Option (Part Manual) := Id.run do
  let boundary := Lifecycle.Document.Block.spec "end:persist"
  -- Verso wraps each expanded block command and directive in a concat.
  let isBoundary : Doc.Block Manual → Bool
    | .concat #[.other ext _] => ext == boundary
    | _ => false
  if let some i := part.content.findIdx? isBoundary then
    let some (.concat #[.other aside blocks]) := part.content[i + 1]? | return none
    if aside != Lifecycle.Document.Block.formalization then return none
    let content := part.content.set! (i + 1) (.concat #[.other aside (blocks ++ exampleBlocks)])
    return some { part with content }
  for (child, i) in part.subParts.zipIdx do
    if let some updated := insertPersistExample child exampleBlocks then
      return some { part with subParts := part.subParts.set! i updated }
  return none

-- Load the compiled document without importing the finite-check driver's `main`.
-- This keeps `lake env lean --run Lifecycle/Checks.lean` and all its declarations.
private unsafe def loadPart (env : Lean.Environment) (name : Lean.Name) : IO (Part Manual) := do
  let some info := env.find? name | throw <| IO.userError s!"Missing compiled document {name}"
  unless info.type == Lean.mkApp (Lean.mkConst ``VersoDoc) (Lean.mkConst ``Manual) do
    throw <| IO.userError s!"Expected {name} to be a compiled Verso Manual document"
  let doc ← IO.ofExcept <| env.evalConst (VersoDoc Manual) {} name (checkMeta := false)
  return doc.toPart

unsafe def main (args : List String) : IO UInt32 := do
  Lean.initSearchPath (← Lean.findSysroot)
  Lean.withImportModules #[{ module := `Lifecycle }] {} fun env => do
    let part ← loadPart env (%docName Lifecycle)
    let examplePart ← loadPart env `Lifecycle.persistExample
    -- The model spans JPA chapters 2 and 3. Promote those chapters into the
    -- book instead of adding a document-title level to the specification TOC.
    let some model := part.subParts[0]? | throw <| IO.userError "Missing model document"
    let some model := insertPersistExample model examplePart.content
      | throw <| IO.userError "Missing Formalized Specification passage after end:persist"
    let part := { part with
      content := part.content ++ model.content
      subParts := model.subParts ++ part.subParts.extract 1 part.subParts.size }
    manualMain part (options := args) (config := {
      destination := ".lake/build/book"
      emitHtmlSingle := .immediately
      emitHtmlMulti := .no
      rootTocDepth := none
    }) (extraSteps := [linkSinglePageContents])
