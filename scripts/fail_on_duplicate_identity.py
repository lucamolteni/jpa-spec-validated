"""Run the finite Veil check with the one-line Merge diff from the chapter."""
from pathlib import Path
import re
import subprocess
import tempfile


def main():
    chapter = Path("Lifecycle/Model.lean").read_text(encoding="utf-8")
    blocks = re.findall(r"^```lean\n(.*?)\n```$", chapter, re.MULTILINE | re.DOTALL)
    # The finite checker uses the declarations and executable actions. The
    # intervening preservation proofs apply to the original Merge action.
    declarations = blocks[:blocks.index("#gen_spec") + 1]
    checker = blocks[blocks.index("#gen_executable"):]

    # Read the two lines readers see, including their indentation.
    book = Path("Lifecycle.lean").read_text(encoding="utf-8")
    _, _, note = book.partition("{lit}`lake run failOnDuplicateIdentity`")
    diff = re.search(r"^```\n-([^\n]+)\n\+([^\n]+)\n```$", note, re.MULTILINE)
    if not diff:
        raise SystemExit("Missing one-line diff in the detached-merge open question")
    before, after = diff.groups()
    lines = "\n".join(declarations).splitlines()
    if lines.count(before) != 1:
        raise SystemExit("The documented Merge guard must match exactly one model line")
    lines[lines.index(before)] = after

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "DuplicateIdentity.lean"
        header = ["import Veil", "set_option veil.violationIsError true"]
        path.write_text("\n".join([*header, *lines, *checker, ""]), encoding="utf-8")
        return subprocess.run(["lake", "lean", str(path)]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
