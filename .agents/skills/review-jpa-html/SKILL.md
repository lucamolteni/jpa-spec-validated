---
name: review-jpa-html
description: Review the jpa-spec-validated rendered book against its saved Jakarta Persistence fragments when explicitly requested. Check section and table-of-contents nesting and displayed Lean code. Do not invoke for routine edits or builds.
---

# Review the JPA book HTML

Use this skill for an explicitly requested HTML review in the
`jpa-spec-validated` repository. Run commands from that repository's root.

Build the current book with `lake exe generate-book`, or reuse a successful
preview build known to include the current sources. An accessible preview alone
does not establish freshness: failed builds leave the previous page visible.

Run the bundled comparison helper:

```sh
python3 .agents/skills/review-jpa-html/scripts/check_html.py
```

The helper compares `.lake/build/book/html-single/index.html` with the saved HTML
fragments in `spec/`, not a live upstream specification. It checks text, lists,
references, footnotes, notices, heading and table-of-contents nesting, labelled
formalization additions, and displayed Lean blocks. It does not check checksums
or prove the Lean model.

For visual review, reuse `http://127.0.0.1:8000/` or start `./preview.sh`. Inspect
the relevant section layout, declaration placement, and table-of-contents nesting.

Report build failures, comparison differences, and visual findings separately.
Treat comparison failures as differences to investigate; an intentional change to
this specification fork is not automatically a defect. Do not revert intentional
edits or change saved fragments merely to obtain a passing comparison.

Keep this review on demand. Do not add it to routine checks, preview rebuilds, or
the workflow for each edit.
