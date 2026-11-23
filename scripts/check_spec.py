"""Fail if pinned wording, order, headings, lists, links, or notices drift."""
import hashlib
import json
from pathlib import Path
import re
from spec_text import marked, model_sections, notice, prerequisites, sections

source = json.loads(Path("spec/source.json").read_text())
for path, expected in source["fragments"].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == expected, path
chapter = Path("Lifecycle/Model.lean").read_text()
for fragment in prerequisites():
    selected = sections(fragment["path"], fragment["heading_base"])
    assert [key for key, _ in selected] == [fragment["anchor"]] + [
        f"_footnotedef_{number}" for number in fragment["footnotes"]
    ], f"Unexpected section or footnote in {fragment['path']}"
    level = fragment["section"].count(".") + 1
    assert selected[0][1].startswith("#" * level + f" {fragment['section']}. "), fragment["path"]
expected = model_sections() + [("notice", notice())]
boundaries = re.findall(r'^\{specBoundary "(begin|end):([^"]+)"\}$', chapter, re.M)
assert boundaries == [(side, key) for key, _ in expected for side in ("begin", "end")]
for key, text in expected:
    assert marked(key, text) in chapter, f"Specification markup changed: {key}"

# After removing the original passages, every prose block must be explicitly
# labelled. Only ordinary, retained Lean fences implement the formalization.
additions = chapter.split('%%%\n', 2)[2]
for key, text in expected:
    additions = additions.replace(marked(key, text), "")
additions, code_blocks = re.subn(r'^```lean\n.*?\n```$', '', additions, flags=re.M | re.S)
assert code_blocks > 1, "The chapter must contain sequential checked Lean blocks"
def labelled(match):
    assert match[1].startswith('*Formalization addition'), "Unlabelled project commentary"
    return ''
additions = re.sub(r'^:::formalization\n(.*?)\n:::$', labelled, additions, flags=re.M | re.S)
assert not additions.strip(), f"Unmarked text outside specification passages: {additions}"

# Fundamental types belong beside their Chapter 2 explanations.
for declaration, number in (("type entity", "2.1"), ("type identity", "2.4")):
    prefix = chapter[:chapter.index("\n" + declaration + "\n")]
    heading = re.findall(r"^#+ (.+)$", prefix, re.M)[-1]
    assert heading.startswith(number + ". "), f"{declaration} is under {heading}"

for module in ("Model", "Proofs", "Checks", "Audit"):
    document = Path(f"Lifecycle/{module}.lean").read_text()
    assert '#doc (Manual) ' in document, f"Missing Manual document: {module}"
    assert '/-!' not in document, f"Comment-wrapped prose in {module}"
    fences = re.findall(r'^```lean[^\n]*$', document, re.M)
    assert fences and all(fence == '```lean' for fence in fences), (
        f"Code must be retained, checked, and shown in {module}")
print(f"Specification preserved: {len(expected) - 1} passages, all headings/lists/references, full notice.")
