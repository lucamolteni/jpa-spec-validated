import Lake
open Lake DSL

package «jpa-spec-validated» where
  leanOptions := #[⟨`veil.smt.trust, false⟩, ⟨`veil.solver, "grind"⟩]

require veil from git "https://github.com/verse-lab/veil.git" @ "5a525eeca8cee37b2da8c010552db9b1aae968c2"
require verso from git "https://github.com/leanprover/verso.git" @ "304b8561790c50222551c937ce02928df0d5b445"

@[default_target]
lean_lib Lifecycle

@[default_target]
lean_exe «generate-book» where
  root := `Main
  needs := #[Lifecycle]
  supportInterpreter := true
