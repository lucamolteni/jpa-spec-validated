"""Parse the saved specification fragments for the on-demand HTML review.

Uses only the Python standard library. Source prose is kept separate from
formalization additions by Verso specification boundary commands.
"""
from html.parser import HTMLParser
from pathlib import Path
import json
import re

URL = "https://jakarta.ee/specifications/persistence/4.0/jakarta-persistence-spec-4.0-M4.html"


class Node:
    def __init__(self, tag="root", attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []

    def text(self):
        return "".join(c if isinstance(c, str) else c.text() for c in self.children)


class Parser(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        n = Node(tag, attrs)
        self.stack[-1].children.append(n)
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input",
                       "link", "meta", "param", "source", "track", "wbr"}:
            self.stack.append(n)

    def handle_endtag(self, tag):
        assert self.stack[-1].tag == tag, (self.stack[-1].tag, tag)
        self.stack.pop()

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def normalize(s):
    return re.sub(r"\s+", " ", s).strip()


def inline(n):
    if isinstance(n, str):
        return n.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]")
    body = "".join(inline(c) for c in n.children)
    if n.tag == "code":
        return "{lit}`" + n.text() + "`"
    if n.tag in {"em", "strong"}:
        marker = "_" if n.tag == "em" else "*"
        return marker + body + marker
    if n.tag == "a" and n.attrs.get("href"):
        if not body:
            return ""
        link = n.attrs["href"]
        if link.startswith("#"):
            link = URL + link
        # The notice's template placeholder is deliberately retained as text.
        link = link.replace(" ", "%20")
        return f"[{body}]({link})"
    return body


def blocks(n, heading_base=2):
    if isinstance(n, str):
        return normalize(n) if n.strip() else ""
    if n.tag in {"h2", "h3", "h4", "h5"}:
        level = max(1, int(n.tag[1]) - heading_base)
        return "#" * level + " " + normalize(inline(n)) + "\n\n"
    if n.tag == "p":
        return normalize(inline(n)) + "\n\n"
    if n.tag == "pre":
        return "```\n" + n.text() + "\n```\n\n"
    if n.tag in {"ul", "ol"}:
        result = ""
        for i, li in enumerate(c for c in n.children if isinstance(c, Node) and c.tag == "li"):
            body = "".join(blocks(c, heading_base) for c in li.children).strip()
            marker = "- " if n.tag == "ul" else f"{i + 1}. "
            lines = body.splitlines()
            result += marker + lines[0] + "\n"
            result += "".join((" " * len(marker) + line if line else "") + "\n"
                              for line in lines[1:])
            result += "\n"
        return result
    if n.tag == "div" and "admonitionblock" in n.attrs.get("class", ""):
        def find_content(node):
            if isinstance(node, str):
                return None
            if node.tag == "td" and node.attrs.get("class") == "content":
                return node
            return next((v for c in node.children if (v := find_content(c)) is not None), None)
        content = find_content(n)
        body = ("".join(blocks(c, heading_base) for c in content.children)
                if any(isinstance(c, Node) and c.tag == "div" for c in content.children)
                else normalize(inline(content)))
        return "> *Note*\n\n" + "\n".join("  " + line for line in body.strip().splitlines()) + "\n\n"
    if n.tag == "div" and n.attrs.get("class") == "footnote":
        return normalize(inline(n)) + "\n\n"
    return "".join(blocks(c, heading_base) for c in n.children)


def sections(path="spec/lifecycle-4.0-M4.html", heading_base=1):
    """Return a fragment's sections and footnotes in source order.

    Heading levels retain the specification's chapter and section hierarchy.
    """
    root = Parser(Path(path).read_text()).root
    result = []

    def visit(node):
        if isinstance(node, str):
            return
        if node.tag in {"h2", "h3", "h4", "h5"}:
            result.append([node.attrs["id"], blocks(node, heading_base)])
        elif node.tag == "div" and node.attrs.get("class", "").startswith("sect"):
            for c in node.children:
                visit(c)
        elif node.tag == "root":
            for c in node.children:
                visit(c)
        elif node.tag == "div" and node.attrs.get("class") == "footnote":
            result.append([node.attrs["id"], blocks(node, heading_base)])
        elif result:
            result[-1][1] += blocks(node, heading_base)

    visit(root)
    return [(key, text.strip()) for key, text in result]


def prerequisites():
    """Describe the selected numbered sections, without implied descendants."""
    return json.loads(Path("spec/source.json").read_text())["prerequisites"]


def prerequisite_sections():
    return [section for fragment in prerequisites()
            for section in sections(fragment["path"], fragment["heading_base"])]


def context_headings():
    path = json.loads(Path("spec/source.json").read_text())["context_headings"]
    return sections(path)


def model_sections():
    """Selected text with its original parent headings in document order."""
    headings = dict(context_headings())
    result = [("entities", headings["entities"])]
    for fragment in prerequisites():
        if fragment["section"] == "2.2.2":
            result.append(("a19", headings["a19"]))
        result.extend(sections(fragment["path"], fragment["heading_base"]))
    return result + [("a1060", headings["a1060"])] + sections()


def marked(key, text):
    # The source already includes its section numbers. Disable Verso's automatic
    # numbering without changing any heading text or its relative level.
    text = re.sub(r"^(#+ .+)$", r"\1\n%%%\nnumber := false\n%%%", text, flags=re.M)
    return f'{{specBoundary "begin:{key}"}}\n\n{text}\n\n{{specBoundary "end:{key}"}}'


def notice():
    return blocks(Parser(Path("spec/notice.html").read_text()).root, heading_base=1).strip()
