#!/usr/bin/env python3
r"""
Generate the body of the Index page from the website sidebar.

===============================================================================
WHAT THIS SCRIPT IS FOR
===============================================================================

The site's navigation lives in one place: the `website.sidebar.contents` list
in `_quarto.yml`. The Index page is meant to show that same list in a flat,
readable form. Maintaining the list twice by hand would guarantee that the two
copies drift apart.

This script removes the duplication. It reads the sidebar and writes a
markdown file that the Index page includes at render time. The sidebar stays
the single source of truth, so the Index page is always a faithful copy of it.

===============================================================================
HOW THE PIECES FIT TOGETHER
===============================================================================

    _quarto.yml (sidebar = single source of truth)
            |
            v
    generate_index.py  --writes-->  _includes/index_body.md
            ^                                  |
            | runs automatically               | pasted into
            | because of "pre-render"          v
      quarto render  ------------------->  index.qmd  -->  _site/  -->  Pages


Each piece has exactly one job:

1. `_quarto.yml`
   Holds the sidebar. This is the only file a person edits when reorganizing
   the site. Everything else follows from it.

2. `_scripts/generate_index.py` (this file)
   The translator. It asks Quarto for the project's final configuration,
   walks the sidebar recursively, and writes the markdown list. It does not
   parse YAML itself and it uses no third-party libraries.

3. `_includes/index_body.md`
   The printout. Generated on every render; never edited by hand. It lives in
   a folder whose name starts with `_`, which Quarto ignores when looking for
   pages to publish, so this file never becomes a page of its own. It is
   committed because Quarto needs it to exist before the build starts; its
   content is still regenerated on every render.

4. `index.qmd`
   The page shell. It holds the title and the introductory text, then uses
   Quarto's `include` shortcode to paste in the generated printout. Because
   the page contains no executable code, Quarto renders it as plain markdown
   and does not need a programming language installed.

5. `.github/workflows/publish.yml`
   The factory. On every push it installs Quarto, runs `quarto render` (which
   triggers the translator through `pre-render`), and publishes the resulting
   `_site/` folder to GitHub Pages. A reference copy of that file is included
   at the bottom of this docstring.

6. `_site/`
   The built website. Produced by `quarto render` and ignored by git. GitHub
   Pages receives it as a build artifact, so it never has to live in the
   repository.

===============================================================================
WHAT THE SCRIPT DOES, STEP BY STEP
===============================================================================

1. Make sure `_includes/index_body.md` exists. Quarto expands includes while
   inspecting the project, so the file that `index.qmd` includes must exist
   before Quarto scans anything. The file is committed for that reason; if it
   is ever missing, an empty placeholder is created so inspection can go on.
2. Locate the `quarto` executable (on PATH, or via the location Quarto sets
   when it launches pre-render scripts).
3. Run `quarto inspect`, which returns the project's merged configuration as
   JSON. This is how the script sees exactly what Quarto sees, including any
   inherited or profile-based settings.
4. Walk `website.sidebar.contents`:
      - a top-level block becomes an `##` heading;
      - a normal item becomes a bullet with a link;
      - a nested `section` becomes a bold bullet, and its children are
        rendered one indentation level deeper, recursively, to any depth.
5. Write the result to `_includes/index_body.md` as UTF-8.

===============================================================================
WHEN IT RUNS
===============================================================================

Quarto runs this script automatically before every render because
`_quarto.yml` contains:

    project:
      pre-render: _scripts/generate_index.py

That means it behaves the same way on a personal computer, in an editor's
preview, and on GitHub Actions. There is no separate command to remember.

===============================================================================
WHAT A PERSON MAINTAINS
===============================================================================

- Edit `_quarto.yml` and the `.qmd` pages. Nothing else.
- Never edit `_includes/index_body.md`; it is overwritten on every render. It
  is committed only because Quarto needs the file to exist before the build
  starts, so treat it as output rather than as source.
- Change this script only if the shape of the sidebar changes (for example,
  if entries stop being `text`/`href` pairs).

===============================================================================
WHAT COULD GO WRONG
===============================================================================

- A YAML error in `_quarto.yml` makes `quarto inspect` fail, which fails the
  render. The error is visible in the build log.
- A page that is missing from the sidebar does not appear on the Index page.
- Hand edits to `_includes/index_body.md` are lost on the next render.

===============================================================================
REFERENCE COPY: DEPLOYMENT WORKFLOW
===============================================================================

The live file is `.github/workflows/publish.yml`. This copy exists so the
whole design can be understood from one place.

```yaml
name: Deploy Quarto site to Pages

on:
  push:
    branches: ["master"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Quarto is not preinstalled on the runner, so it is installed here.
      # Python 3 is preinstalled, so the pre-render script needs no setup.
      - name: Setup Quarto
        uses: quarto-dev/quarto-actions/setup@v2

      # This also runs _scripts/generate_index.py (configured via pre-render)
      # and writes the finished site to _site/.
      - name: Render Quarto Project
        run: quarto render

      - name: Setup Pages
        uses: actions/configure-pages@v4

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '_site'

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "_includes" / "index_body.md"


def find_quarto() -> str:
    """Return the path to the quarto executable."""
    bin_path = os.environ.get("QUARTO_BIN_PATH")
    if bin_path:
        name = "quarto.exe" if os.name == "nt" else "quarto"
        candidate = Path(bin_path) / name
        if candidate.exists():
            return str(candidate)

    found = shutil.which("quarto")
    if found:
        return found

    raise SystemExit("Could not find the `quarto` executable on PATH.")


def ensure_include_exists() -> None:
    """Create an empty include target if it is missing.

    Quarto expands include shortcodes while inspecting a project. Because
    `index.qmd` includes this file, the file must exist before `quarto
    inspect` runs, even if it has no content yet.
    """
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    if not OUTPUT.exists():
        OUTPUT.write_text("", encoding="utf-8")


def load_sidebar() -> list[dict]:
    """Return the sidebar's contents exactly as Quarto resolves them."""
    result = subprocess.run(
        [find_quarto(), "inspect", str(ROOT)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    config = json.loads(result.stdout)["config"]
    return config["website"]["sidebar"]["contents"]


def render_items(items: list[dict], level: int, lines: list[str]) -> None:
    """Append the markdown for a list of sidebar items."""
    indent = "    " * level
    for item in items:
        if item.get("text") and item.get("href"):
            lines.append(f"{indent}* [{item['text']}]({item['href']})")
        elif item.get("section"):
            lines.append(f"{indent}* **{item['section']}**")
            children = item.get("contents")
            if children:
                render_items(children, level + 1, lines)


def main() -> int:
    ensure_include_exists()

    lines: list[str] = []

    for block in load_sidebar():
        section = block.get("section")
        if not section:
            continue
        lines.append(f"## {section}")
        lines.append("")
        children = block.get("contents")
        if children:
            render_items(children, 0, lines)
        lines.append("")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"Generated {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
