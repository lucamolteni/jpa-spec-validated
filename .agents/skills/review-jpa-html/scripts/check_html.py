"""On-demand comparison of rendered HTML with the saved specification fragments.

Run from the repository root after generating the book. No checksums are checked.
"""
from pathlib import Path
import json
import re
from urllib.parse import urljoin
from spec_text import Node, Parser, URL, context_headings, model_sections, normalize, prerequisites, sections


def descendants(node):
    if isinstance(node, Node):
        yield node
        for child in node.children:
            yield from descendants(child)


def canonical(node, source=False, heading_base=0):
    """Retain paragraphs, heading levels, list nesting, notes, code, and inline semantics."""
    if isinstance(node, str):
        assert not node.strip(), f"Text outside a block: {node!r}"
        return []

    def leaf(kind, text=None):
        annotations = []
        for child in descendants(node):
            if child.tag in {"em", "strong", "code"} and node.tag != "pre":
                annotations.append((child.tag, normalize(child.text())))
            elif child.tag == "a" and child.text().strip():
                annotations.append(("a", normalize(child.text()),
                                    urljoin(URL, child.attrs["href"]).replace(" ", "%20")))
        return [(kind, normalize(node.text() if text is None else text), annotations)]

    if node.tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
        return leaf("h" + str(int(node.tag[1]) - heading_base))
    if node.tag in {"p", "pre"}:
        return leaf(node.tag)
    if source and node.attrs.get("class") == "footnote":
        return leaf("p")
    if source and "admonitionblock" in node.attrs.get("class", "").split():
        content = next(n for n in descendants(node) if n.tag == "td" and n.attrs.get("class") == "content")
        body = (canonical(content, source, heading_base)
                if any(isinstance(c, Node) and c.tag == "div" for c in content.children)
                else canonical(NodeWithChildren("p", content.children), source, heading_base))
        return [("blockquote",), ("p", "Note", [("strong", "Note")])] + body + [("/blockquote",)]
    children = [token for child in node.children for token in canonical(child, source, heading_base)]
    if node.tag in {"ul", "ol", "li", "blockquote"}:
        return [(node.tag,)] + children + [("/" + node.tag,)]
    return children


def NodeWithChildren(tag, children):
    node = Node(tag)
    node.children = children
    return node


def check_equal(expected, actual, label):
    for index, (a, b) in enumerate(zip(expected, actual)):
        assert a == b, f"{label} block {index}:\nsource: {a}\nrender: {b}"
    assert len(expected) == len(actual), f"{label}: {len(expected)} source blocks, {len(actual)} rendered blocks"


directory = Path(".lake/build/book/html-single")
book = Parser((directory / "index.html").read_text()).root
toc = next(n for n in descendants(book) if n.tag == "ol"
           and "section-toc" in n.attrs.get("class", "").split())


def strip_navigation(node):
    """Permalinks and the generated TOC are renderer UI, not source passages."""
    if isinstance(node, Node):
        node.children = [child for child in node.children
                         if not (isinstance(child, Node) and
                                 ("permalink-widget" in child.attrs.get("class", "").split()
                                  or (child.tag == "section" and toc in child.children)))]
        for child in node.children:
            strip_navigation(child)


strip_navigation(book)
original = {}
active = None


def collect(node):
    """Read specification ranges in document order, across section containers."""
    global active
    if isinstance(node, str):
        assert active is None or not node.strip(), f"Unstructured specification text: {node!r}"
        return
    if boundary := node.attrs.get("data-spec"):
        side, key = boundary.split(":", 1)
        if side == "begin":
            assert active is None and key not in original, f"Duplicate/nested passage: {key}"
            original[key] = []
            active = key
        else:
            assert side == "end" and active == key, f"Unmatched boundary: {boundary}"
            active = None
    elif active and node.tag in {"h1", "h2", "h3", "h4", "h5", "h6", "p", "pre", "ul", "ol", "blockquote"}:
        assert not any("formalization" in n.attrs.get("class", "").split()
                       for n in descendants(node)), "Addition inside specification"
        original[active].extend(canonical(node))
    else:
        for child in node.children:
            collect(child)


collect(book)
assert active is None, f"Unclosed specification passage: {active}"
assert list(original) == [key for key, _ in model_sections()] + ["notice"], (
    "Missing or reordered passages")
additions = [n for n in descendants(book) if "formalization" in n.attrs.get("class", "").split()]
assert additions and all(normalize(n.text()).startswith("Formalization addition") for n in additions), (
    "Formalization additions must be separately labelled")
for fragment in prerequisites():
    source = Parser(Path(fragment["path"]).read_text()).root
    keys = [key for key, _ in sections(fragment["path"], fragment["heading_base"])]
    check_equal(canonical(source, source=True),
                [token for key in keys for token in original[key]],
                f"Prerequisite {fragment['section']}")
heading_path = json.loads(Path("spec/source.json").read_text())["context_headings"]
source = Parser(Path(heading_path).read_text()).root
check_equal(canonical(source, source=True),
            [token for key, _ in context_headings() for token in original[key]], "Parent headings")
source = Parser(Path("spec/lifecycle-4.0-M4.html").read_text()).root
check_equal(canonical(source, source=True),
            [token for key, _ in sections() for token in original[key]], "Lifecycle chapter")
notice = Parser(Path("spec/notice.html").read_text()).root
check_equal(canonical(notice, source=True), original["notice"], "Full notice")

headings = {n.attrs.get("id"): n for n in descendants(book) if n.tag in {"h1", "h2"}}
for module in ["proofs", "checks", "audit"]:
    assert f"lifecycle-{module}" in headings, f"Missing {module} chapter"


def check_section_tree(node, ancestors=()):
    if not isinstance(node, Node):
        return
    if node.tag == "section":
        heading = next((c for c in node.children if isinstance(c, Node)
                        and re.fullmatch(r"h[1-6]", c.tag)), None)
        if heading and (match := re.match(r"(\d+(?:\.\d+)*)\. ", normalize(heading.text()))):
            number = match[1]
            parts = number.split(".")
            expected = tuple(".".join(parts[:i]) for i in range(1, len(parts)))
            assert ancestors == expected, (
                f"Incorrect section ancestry for {number}: {ancestors}")
            assert heading.tag == f"h{number.count('.') + 2}", number
            ancestors = (*ancestors, number)
    for child in node.children:
        check_section_tree(child, ancestors)


check_section_tree(book)

# The generated table of contents must expose the same numbered hierarchy.
toc_paths = {}
def check_toc(node, ancestors=()):
    if not isinstance(node, Node):
        return
    if node.tag == "li":
        link = next(c for c in node.children if isinstance(c, Node) and c.tag == "a")
        if match := re.match(r"(\d+(?:\.\d+)*)\. ", normalize(link.text())):
            number = match[1]
            parts = number.split(".")
            assert ancestors == tuple(".".join(parts[:i]) for i in range(1, len(parts))), number
            toc_paths[number] = normalize(link.text())
            ancestors = (*ancestors, number)
    for child in node.children:
        check_toc(child, ancestors)

check_toc(toc)
expected_titles = {match[1]: normalize(n.text()) for n in descendants(book)
                   if re.fullmatch(r"h[1-6]", n.tag)
                   and (match := re.match(r"(\d+(?:\.\d+)*)\. ", normalize(n.text())))}
assert toc_paths == expected_titles, "TOC must include every numbered heading, in its original hierarchy"


def code_text(node):
    """Read the displayed code, excluding interactive goals and message popups."""
    if isinstance(node, str):
        return node
    if {"tactic-state", "hover-container"} & set(node.attrs.get("class", "").split()):
        return ""
    return "".join(code_text(child) for child in node.children)


rendered_code = [normalize(code_text(n)) for n in descendants(book)
                 if n.tag == "code" and n.attrs.get("class") == "hl lean block"]
source_code = [normalize(code) for module in ("Model", "Proofs", "Checks", "Audit")
               for code in re.findall(r'^```lean\n(.*?)\n```$',
                                      Path(f"Lifecycle/{module}.lean").read_text(), re.M | re.S)]
check_equal(source_code, rendered_code, "Checked Lean code")
print("Rendered HTML preserves all original wording, heading levels, nested lists, emphasis, code, references, footnotes, and notices.")
print(f"All four Manual documents and {len(source_code)} checked Lean blocks rendered in one book; formalization additions are separately labelled.")
