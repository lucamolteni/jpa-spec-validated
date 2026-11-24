# Project conventions

This repository presents selected Jakarta Persistence specification text together
with an executable Lean/Veil formalization. Follow these conventions when
extending or reviewing it.

## Explain the concepts alongside the code

- Write for a reader who understands Java/JPA but may not know Lean or Veil.
  Use plain English and concrete examples.
- Interleave explanations with small, checked Lean blocks. Explain each concept
  immediately before its declaration. Keep complete actions and proofs together
  when splitting them would break the code.
- Explain unfamiliar keywords and logical symbols on first use, including
  `immutable individual`, `relation`, `ghost relation`, `action`, and `require`.
  Distinguish Veil syntax from ordinary Lean syntax.
- Introduce definitions in the specification section that establishes the
  concept. In the current document, `entity` belongs under §2.1 and `identity`
  under §2.4; lifecycle states and operations belong under §3.6.
- Introduce prerequisite concepts before using them. Explain the difference
  between an entity class, a Java object, and a persistent identity, and explain
  the root entity class before referring to it.
- Describe what the code actually represents. For example, the current abstract
  `identity` type does not store separate class and primary-key components.
  Copying a specification requirement does not mean it has been formalized.
- Avoid unexplained shorthand and migration commentary in the reader-facing
  explanation, such as “old typing invariant,” “pools,” or “refresh stutters.”
  Explain the behavior directly. Put allocation limits beside the affected
  operations and proof assumptions beside the proofs.

## Preserve the specification and its structure

- Use the pinned Jakarta Persistence 4.0-M4 edition unless an edition change is
  requested. Preserve original wording, numbering, lists, references, footnotes,
  attribution, and the specification license notice.
- Select only relevant numbered sections. Copy the complete text directly under
  a selected heading, stopping at the next numbered heading. Assess nested
  subsections separately; selecting §2.4 does not automatically include §2.4.1,
  §2.4.2, or their examples.
- Preserve JPA's heading hierarchy and numbering in both the document and its
  table of contents. Include parent headings needed for context without silently
  copying their unselected bodies. Show the full outline of included sections,
  and avoid an extra project-document wrapper above the specification chapters.
- Keep additions visibly labelled *Formalized Specification* and outside the
  original-text boundaries. Explain omissions and modeling choices in those
  additions, without rewriting the specification to match the model.
- Save newly included source fragments and record their provenance in
  `spec/source.json`. Checksums are not an editing requirement.

## Keep documentation executable

- Use the actual checked declarations in the document's `lean` fences. Do not
  create separate display-only copies of the model or hide it in comment blocks.
- Editorial changes should preserve model behavior, proof statements, and
  declaration order. Moving a declaration to its proper section is appropriate;
  changing the abstraction requires a separate, explicit explanation.
- Do not weaken proofs to make a documentation edit pass.
- For model or proof changes, run `sh scripts/check.sh` to build Lean and run the
  finite model checks. For prose-only changes, use the preview's checked build
  and inspect the affected rendered sections. For prose/code rearrangement,
  also verify that the checked code has not changed unintentionally.
- Run the [HTML review skill](.agents/skills/review-jpa-html/SKILL.md) only when explicitly
  requested. Specification wording, references, license, and full HTML structure
  comparisons are on-demand reviews, not checks to run after every edit.

## Preview and version control

- Use `./preview.sh` and `http://127.0.0.1:8000/` for review. Reuse an existing
  preview server when available. Saving watched Lean files automatically rebuilds
  and refreshes the page; the user should not need to rebuild manually.
- Verify the preview after document changes. A failed build leaves the previous
  successful page visible, so an accessible page alone does not prove it is current.
- Establish and verify `.gitignore` before staging. Exclude `.lake/`, local tool
  and output directories, Python bytecode, and OS metadata.
- Keep pinned source fragments, dependency manifests, and intentional verification
  fixtures and logs in version control. Inspect staged files before committing so
  generated artifacts and caches are not included.
