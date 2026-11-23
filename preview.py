#!/usr/bin/env python3
"""Build the Verso page, watch its source, and refresh the browser on saves."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parent
HTML = ROOT / ".lake/build/book/html-single"
CONFIGS = ("lake-manifest.json", "lean-toolchain")
revision = 0


def snapshot():
    sources = sorted({
        *ROOT.glob("*.lean"),
        *(ROOT / "Lifecycle").rglob("*.lean"),
        *(ROOT / name for name in CONFIGS),
    })
    return tuple(
        (str(path.relative_to(ROOT)), path.read_bytes() if path.exists() else None)
        for path in sources
    )


def build():
    return subprocess.run(["lake", "exe", "generate-book"], cwd=ROOT).returncode == 0


def watch(previous, stopped):
    global revision
    while not stopped.wait(0.3):
        current = snapshot()
        if current == previous:
            continue
        # Wait for a burst of editor saves to settle before building.
        time.sleep(0.2)
        previous = snapshot()
        if build():
            revision += 1
        else:
            print("Build failed; waiting for the next edit.", flush=True)


class Preview(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        file = Path(self.translate_path(path))
        if file.is_dir():
            file = file / "index.html"
        if path == "/__revision":
            content = str(revision).encode()
            content_type = "text/plain"
        elif file.suffix == ".html":
            try:
                content = file.read_bytes()
            except FileNotFoundError:
                self.send_error(503, "Waiting for the first successful build")
                return
            reload = f"""<script>
const revision = {revision};
setInterval(async () => {{
  try {{
    const response = await fetch('/__revision', {{cache: 'no-store'}});
    if (response.ok && Number(await response.text()) !== revision) location.reload();
  }} catch (_) {{}}
}}, 600);
</script>""".encode()
            content = content.replace(b"</body>", reload + b"</body>")
            content_type = "text/html; charset=utf-8"
        else:
            return super().do_GET()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, format, *args):
        pass


def main():
    previous = snapshot()
    if not build():
        return 1
    stopped = threading.Event()
    with ThreadingHTTPServer(
        ("127.0.0.1", 8000), partial(Preview, directory=str(HTML))
    ) as server:
        threading.Thread(target=watch, args=(previous, stopped), daemon=True).start()
        print("Preview: http://127.0.0.1:8000/ — watching for saves. Ctrl+C to stop.", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            stopped.set()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
