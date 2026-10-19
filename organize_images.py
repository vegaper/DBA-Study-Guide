#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
organize_images.py
==================

WHAT THIS SCRIPT DOES (in plain words)
-------------------------------------
You paste screenshots into the Quarto visual editor. Quarto saves them as files
with ugly names (like "paste-0-oZ5CjlvAB4DKDRKQi6X") and without any extension,
and it drops them in the main project folder instead of the "images" folder.

This script cleans that up. When you run it, it will:

  1. Read every page of the website: .qmd, .md, .ipynb or .Rmd files that live
     in the main folder (only the main folder - it does NOT go into _site,
     images, assets, .git, etc.). Pages listed in _quarto.yml are included too,
     even though there they are written with the ".html" extension (for example
     "href: intro.html" means the file "intro.qmd").

  2. Find every image link in those files, for example:  ![](paste-abc123)

  3. Rename each image so it has a meaningful name:
         <page-name>_fig<number>.<extension>
     Example: an image inside "dml.qmd" becomes "dml_fig1.png".
     The number counts images in the order they appear on the page.

  4. Move the image into the "images" folder (if it was in the main folder),
     and give it the right extension by *sniffing* the file contents
     (PNG? JPEG? ...). If we cannot tell, we use ".png".

  5. Update the link in the page so it points at the new name/location.

  6. Report links that point nowhere ("broken links"), showing file and line.

  7. List images that no page uses ("orphan images") and move them into a new
     folder called "orphan_images", so you can look at them and delete them
     yourself if you want.

HOW TO RUN IT
-------------
Open a terminal in the project folder and run:

    python organize_images.py --dry-run     <-- safest: shows what WOULD change
    python organize_images.py               <-- really does the changes

Useful extras:

    python organize_images.py --report my_report.txt
    python organize_images.py --manifest my_manifest.csv
    python organize_images.py --root "C:\\path\\to\\project"

IMPORTANT SAFETY NOTES
----------------------
* Always run --dry-run first and read the report. A dry run changes NONE of
  your pages and moves NO image; it only writes the report and the manifest.
* Before a real run, make a git commit (or a branch) so you can undo easily:
        git checkout -b chore/organize-images
        git commit -am "backup before organizing images"
* Running the script twice is harmless: the second run finds everything already
  in place and changes nothing.
* Only three files are ever created by the script: the report, the manifest and
  the "orphan_images" folder. Everything else is a rename/move you can undo with
  the manifest or with git.

Author's note for future maintainers
------------------------------------
Every step below has comments written for a beginner. The three ideas that
matter most:

  * We build a "plan" first (read-only) and only change files afterwards.
  * We remember images by their *real path on disk*, not by their name, so the
    same image used on two pages is renamed only once.
  * Figure numbers are given in the order images appear in the page.
"""

# ---------------------------------------------------------------------------
# Imports: the standard library boxes we pull tools out of.
# ---------------------------------------------------------------------------
from __future__ import annotations

import argparse
import codecs
import csv
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote


# ---------------------------------------------------------------------------
# Configuration: the knobs of the script. Change these if your project differs.
# ---------------------------------------------------------------------------

# File extensions we consider "an image".
IMAGE_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp",
    ".tif", ".tiff", ".svg", ".avif", ".ico",
}

# File extensions we consider "a page" (something Quarto can render).
PAGE_EXTENSIONS = {".qmd", ".md", ".ipynb", ".rmd"}

# When a link has no extension (or the file has none), we try these in order.
EXTENSIONS_TO_TRY = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".tif", ".tiff"]

# Fallback extension when sniffing fails.
DEFAULT_EXTENSION = ".png"

# The folder where images should live.
IMAGES_DIR_NAME = "images"

# The folder where unused images are parked.
ORPHAN_DIR_NAME = "orphan_images"

# A tiny blacklist of files that must never be treated as pages or as images.
PROTECTED_NAMES = {"_quarto.yml", "styles.css"}


# ---------------------------------------------------------------------------
# Magic numbers ("signatures"): the first bytes of a file tell us its type.
# Each entry is: (list of byte-prefixes that mean "this type", extension)
# A "prefix" can also be ("offset", bytes) to check bytes at a given position.
# ---------------------------------------------------------------------------
SNIFF_SIGNATURES = [
    ([(0, b"\x89PNG\r\n\x1a\n")], ".png"),
    ([(0, b"\xff\xd8\xff")], ".jpg"),
    ([(0, b"GIF87a"), (0, b"GIF89a")], ".gif"),
    ([(0, b"RIFF"), (8, b"WEBP")], ".webp"),
    ([(0, b"II\x2a\x00"), (0, b"MM\x00\x2a")], ".tiff"),
    ([(0, b"\x00\x00\x01\x00")], ".ico"),
    ([(0, b"<svg"), (0, b"<?xml")], ".svg"),
]
# NOTE: BMP ("BM") is checked separately below, because "BM" is only 2 bytes and
# could appear by accident at the start of some other file.


# ---------------------------------------------------------------------------
# The regular expression that finds a Markdown image link.
#
#   ![alt text](the/path.png){width="466"}
#    ^^^^^^^^^  ^^^^^^^^^^^^  ^^^^^^^^^^^
#    alt text   the path      extra options (NOT touched by us)
#
# The "(...)" part allows an optional title, as in  ![alt](path "my title").
# ---------------------------------------------------------------------------
IMAGE_REF_RE = re.compile(
    r"!\[(?P<alt>[^\]]*)\]"                            # ![ alt text ]
    r"\(\s*(?P<path><[^>]*>|[^()\s]+?)"                # ( path      (or <path with spaces>)
    r"(?:\s+(?P<title>\"[^\"]*\"|'[^']*'))?\s*\)"      #   "title" )
    r"(?P<attrs>\{[^}]*\})?"                           # {width="466"} (optional)
)

# Finds HTML image tags:  <img src="images/x.png" ...>
HTML_IMG_SRC_RE = re.compile(
    r"<img\b[^>]*?\bsrc\s*=\s*(?P<quote>[\"'])(?P<path>[^\"']+)(?P=quote)",
    re.IGNORECASE,
)

# Opens and closes a fenced code block (``` or ~~~).
FENCE_OPEN_RE = re.compile(r"^\s*(`{3,}|~{3,})")

# Finds inline code, like  `cat /etc/os-release`
INLINE_CODE_RE = re.compile(r"(?<!`)(`+)(?!`)(.+?)(?<!`)\1(?!`)")

# Links that are not local files and must be ignored.
EXTERNAL_PREFIXES = ("http://", "https://", "data:", "mailto:", "ftp://", "//", "#")


# ===========================================================================
# Small helpers
# ===========================================================================

def eprint(message: str = "") -> None:
    """Print a line to the terminal (and make sure accented letters survive)."""
    try:
        print(message)
    except UnicodeEncodeError:
        # Very old terminals: replace impossible characters instead of crashing.
        print(message.encode("ascii", "replace").decode("ascii"))


def relative_to_root(path: Path, root: Path) -> str:
    """Turn an absolute path into a nice short one (images/paste-1.png) for reports."""
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def inside_any_span(position: int, spans: list[tuple[int, int]]) -> bool:
    """Is this position inside one of the (start, end) ranges?"""
    for start, end in spans:
        if start <= position < end:
            return True
    return False


def image_name_stem(page: Path) -> str:
    """
    Turn a page name into the first half of the image name.

    Example: "Manejando un servidor.qmd" -> "Manejando_un_servidor"
    We replace spaces with underscores and remove characters that Windows does
    not allow in file names.
    """
    stem = re.sub(r"\s+", "_", page.stem)          # spaces -> underscores
    stem = re.sub(r'[<>:"/\\|?*]', "", stem)       # characters Windows forbids
    stem = stem.strip("._")
    return stem or "page"


def find_pages(root: Path, yaml_path: Path, warnings: list[str]) -> list[Path]:
    """
    Find every "page" of the website.

    A page is a file Quarto can render: .qmd, .md, .ipynb or .Rmd.
    We find them in two ways and join the results:
      1. any such file sitting in the main folder;
      2. any file mentioned in _quarto.yml, where links look like
         "href: intro.html" while the real file is "intro.qmd".
    """
    pages: dict[str, Path] = {}

    for path in sorted(root.iterdir(), key=lambda item: item.name.lower()):
        if (path.is_file()
                and path.suffix.lower() in PAGE_EXTENSIONS
                and path.name not in PROTECTED_NAMES):
            pages[path.name.lower()] = path

    if not yaml_path.is_file():
        return list(pages.values())

    yaml_text, _ = read_text_file(yaml_path)
    for match in re.finditer(r"href:\s*[\"']?([^\"'\s#]+)", yaml_text):
        href = match.group(1)
        if href.lower().startswith(("http", "mailto", "#", "//")):
            continue
        wanted_stem = Path(href).stem          # "intro.html" -> "intro"
        found = None
        for extension in sorted(PAGE_EXTENSIONS):
            candidate = root / f"{wanted_stem}{extension}"
            if candidate.is_file():
                found = candidate
                break
        if found is None:
            warnings.append(f"_quarto.yml mentions '{href}' but no page file with that name was found")
            continue
        pages.setdefault(found.name.lower(), found)

    return list(pages.values())


# ===========================================================================
# Step 1: find the parts of a page that we must NOT touch (code blocks / inline code)
# ===========================================================================

def find_fenced_code_spans(text: str) -> list[tuple[int, int]]:
    """
    Return the character ranges of fenced code blocks (``` ... ```).

    We do not want to rename anything that is inside a code block, because it is
    probably an example, not a real image.
    """
    spans: list[tuple[int, int]] = []
    lines = text.splitlines(keepends=True)

    position = 0            # where the current line starts, in characters
    block_start: int | None = None
    fence_char = ""

    for line in lines:
        if block_start is None:
            # We are OUTSIDE a block: a fence line opens one.
            match = FENCE_OPEN_RE.match(line)
            if match:
                block_start = position
                fence_char = match.group(1)[0]
        else:
            # We are INSIDE a block: the closing fence is the same character
            # repeated 3 or more times, and nothing else on the line (except
            # spaces and the line ending).
            stripped = line.strip()
            if stripped and stripped[0] == fence_char and set(stripped) <= {fence_char} and len(stripped) >= 3:
                spans.append((block_start, position + len(line)))
                block_start = None
        position += len(line)

    # An unclosed block at the end of the file: treat the rest as code.
    if block_start is not None:
        spans.append((block_start, len(text)))

    return spans


def find_inline_code_spans(text: str) -> list[tuple[int, int]]:
    """Return the character ranges of inline code spans (`like this`)."""
    return [match.span() for match in INLINE_CODE_RE.finditer(text)]


def find_code_spans(text: str) -> list[tuple[int, int]]:
    """All code ranges (fenced blocks + inline code), ready to be asked about."""
    spans = find_fenced_code_spans(text) + find_inline_code_spans(text)
    spans.sort()
    return spans


# ===========================================================================
# Step 2: find image links inside a page
# ===========================================================================

def collect_image_refs(text: str, code_spans: list[tuple[int, int]]) -> list[dict]:
    """
    Find all image links in a piece of text.

    For each one we keep the exact character positions of the *path*, because
    later on we will surgically replace only those characters.
    """
    found: list[dict] = []

    # --- Markdown images:  ![alt](path)  ---
    for match in IMAGE_REF_RE.finditer(text):
        if inside_any_span(match.start(), code_spans):
            continue  # it is inside a code block, leave it alone

        start, end = match.span("path")
        found.append({"start": start, "end": end, "raw": text[start:end]})

    # --- HTML images:  <img src="...">  ---
    for match in HTML_IMG_SRC_RE.finditer(text):
        if inside_any_span(match.start(), code_spans):
            continue
        start, end = match.span("path")
        found.append({"start": start, "end": end, "raw": text[start:end], "html": True})

    # Put them in the order they appear in the file (important for _fig1, _fig2...).
    found.sort(key=lambda item: item["start"])

    # Remove accidental duplicates (same characters found twice).
    unique: list[dict] = []
    seen: set[tuple[int, int]] = set()
    for item in found:
        key = (item["start"], item["end"])
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique


# ===========================================================================
# Step 3: file-type sniffing, reading and writing text files
# ===========================================================================

def sniff_image_extension(path: Path) -> tuple[str | None, str | None]:
    """
    Guess an image extension by looking at the first bytes of the file.

    Returns (extension, explanation). If we cannot tell, extension is None.
    """
    try:
        with path.open("rb") as handle:
            head = handle.read(32)
    except OSError as error:
        return None, f"could not read file ({error})"

    for signatures, extension in SNIFF_SIGNATURES:
        if all(head[offset:offset + len(needle)] == needle for offset, needle in signatures):
            return extension, "extension detected from file contents"

    # BMP is special: exactly "BM" at the start.
    if head[:2] == b"BM":
        return ".bmp", "extension detected from file contents"

    # JPEG sometimes starts with FFD8 but not FFD8FF.
    if head[:2] == b"\xff\xd8":
        return ".jpg", "extension detected from file contents"

    return None, "could not detect the file type"


def read_text_file(path: Path) -> tuple[str, str]:
    """
    Read a page as text, remembering which encoding was used so we can write it
    back the same way. CRLF line endings are preserved automatically.
    """
    data = path.read_bytes()

    if data.startswith(codecs.BOM_UTF8):
        return data.decode("utf-8-sig"), "utf-8-sig"

    try:
        return data.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        # Some Spanish files are saved in Windows-1252.
        return data.decode("cp1252"), "cp1252"


def write_text_file(path: Path, text: str, encoding: str) -> None:
    """Write a page back, using the same encoding. Atomic: temp file then swap."""
    temporary = path.with_name(path.name + ".organize_images_tmp")
    temporary.write_bytes(text.encode(encoding))
    os.replace(temporary, path)  # os.replace is atomic-ish: no half-written page


def real_path_case_insensitive(candidate: Path) -> Path | None:
    """
    Return the file that exists at this path.

    Windows ignores letter case, so "Paste.PNG" and "paste.png" are the same
    file. This helper also tells us the *real* spelling used on disk.
    """
    if candidate.exists():
        return candidate

    parent = candidate.parent
    if not parent.is_dir():
        return None

    wanted = candidate.name.lower()
    for entry in parent.iterdir():
        if entry.name.lower() == wanted:
            return entry
    return None


# ===========================================================================
# Step 4: find where an image link actually points
# ===========================================================================

def resolve_reference(raw_path: str, root: Path, images_dir: Path) -> tuple[Path | None, str | None, str | None]:
    """
    Work out which real file a link points at.

    Returns (real_path, reason_if_missing, note).
    * real_path is None when the link is broken.
    * note explains clever rescues, e.g. "the file exists but has no extension".
    """
    cleaned = raw_path.strip()

    # Ignore links that are not local files.
    if cleaned.lower().startswith(EXTERNAL_PREFIXES):
        return None, "external link", "skipped"

    # Links may be written inside angle brackets: <images/my file.png>
    if cleaned.startswith("<") and cleaned.endswith(">"):
        cleaned = cleaned[1:-1]

    # %20 means a space, %5B means "[" ... decode those.
    cleaned = unquote(cleaned)

    # "/images/x.png" means "start from the project root".
    cleaned = cleaned.replace("\\", "/").lstrip("/")

    parts = [piece for piece in cleaned.split("/") if piece not in ("", ".")]
    if not parts:
        return None, "empty link", None
    if ".." in parts:
        return None, "link points outside the project", None

    # Quarto looks for the image next to the page first, then we also try the
    # images folder: that is why both candidates are listed.
    candidates: list[Path] = []
    for base in (root, images_dir):
        candidate = base.joinpath(*parts)
        if candidate not in candidates:
            candidates.append(candidate)

    # --- Attempt 1: the exact path ---
    for candidate in candidates:
        real = real_path_case_insensitive(candidate)
        if real is not None and real.is_file():
            return real, None, None

    # --- Attempt 2: the link has an extension, but the file does not ---
    # (happens when Quarto names the file without an extension)
    filename = parts[-1]
    stem, extension = os.path.splitext(filename)
    if extension:
        for base in (root, images_dir):
            candidate = base.joinpath(*parts[:-1], stem)
            real = real_path_case_insensitive(candidate)
            if real is not None and real.is_file():
                return real, None, f"link says '{extension}' but the file has no extension"

    # --- Attempt 3: the link has no extension, but the file does ---
    else:
        for base in (root, images_dir):
            for guess in EXTENSIONS_TO_TRY:
                candidate = base.joinpath(*parts[:-1], filename + guess)
                real = real_path_case_insensitive(candidate)
                if real is not None and real.is_file():
                    return real, None, f"link has no extension but the file is '{guess}'"

    # --- Attempt 4: the same name but written with different separators ---
    # Example: the link says "images/Host_Only.png" while the real file is
    # "images/Host Only.png". Spaces, underscores and dashes are ignored when
    # comparing, and we point the link at the real file (that is the auto-fix).
    wanted_squashed = normalize_image_name(filename)
    if wanted_squashed:
        same_extension: list[Path] = []
        other_extension: list[Path] = []
        for base in (root, images_dir):
            if not base.is_dir():
                continue
            for entry in sorted(base.iterdir(), key=lambda item: item.name.lower()):
                if not entry.is_file() or entry.name.startswith("."):
                    continue
                if normalize_image_name(entry.name) != wanted_squashed:
                    continue
                if entry.suffix.lower() == extension.lower():
                    same_extension.append(entry)
                else:
                    other_extension.append(entry)

        for match in same_extension:
            return match, None, f"link name differs only by spaces/underscores; using '{match.name}'"
        for match in other_extension:
            return match, None, (f"link name differs only by spaces/underscores and the extension "
                                 f"is '{match.suffix}'; using '{match.name}'")

    return None, "no file found", None


def normalize_image_name(name: str) -> str:
    """
    Turn a file name into a "squashed" form used for fuzzy comparison.

    Example:  "Host Only.png"  ->  "hostonly"
              "Host_Only.png"  ->  "hostonly"   (they match!)
    """
    stem = os.path.splitext(name)[0]
    return re.sub(r"[^0-9a-z]+", "", stem.lower())


def suggest_similar_images(raw_path: str, root: Path, images_dir: Path,
                           limit: int = 3) -> list[tuple[Path, str]]:
    """
    When a link points at a missing file, look for files with a similar name.

    Returns a list of (file, kind) where kind is:
      "same-name"   - identical after ignoring spaces/underscores/dashes  (very likely the one)
      "part-of"     - the wanted name appears inside the found name       (probably the one)
    """
    wanted = unquote(raw_path.strip().replace("\\", "/").lstrip("/").split("/")[-1])
    wanted_squashed = normalize_image_name(wanted)
    if not wanted_squashed:
        return []

    strong: list[Path] = []
    weak: list[Path] = []

    for folder in (root, images_dir):
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if not path.is_file() or path.name.startswith("."):
                continue
            squashed = normalize_image_name(path.name)
            if not squashed:
                continue
            if squashed == wanted_squashed:
                strong.append(path)
            elif (len(wanted_squashed) >= 8 and len(squashed) >= 8
                  and (wanted_squashed in squashed or squashed in wanted_squashed)):
                # "Host_Only" vs "HostOnly", "abovepaste-x" vs "paste-x", ...
                weak.append(path)

    suggestions = [(path, "same-name") for path in strong]
    suggestions += [(path, "part-of") for path in weak]
    return suggestions[:limit]


# ===========================================================================
# Step 5: the plan (the "to-do list" the script builds before changing anything)
# ===========================================================================

class Reporter:
    """Collects report lines and also prints them to the terminal."""

    def __init__(self, echo: bool = True) -> None:
        self.lines: list[str] = []
        self.echo = echo

    def line(self, text: str = "") -> None:
        self.lines.append(text)
        if self.echo:
            eprint(text)

    def section(self, title: str) -> None:
        self.line("")
        self.line(title)
        self.line("-" * len(title))

    def text(self) -> str:
        return "\n".join(self.lines) + "\n"


def build_plan(root: Path, images_dir: Path, reporter: Reporter) -> dict:
    """
    The heart of the script. It reads everything, decides what should change,
    and returns a plan. It NEVER modifies anything.
    """
    warnings: list[str] = []
    pages = find_pages(root, root / "_quarto.yml", warnings)

    # registry: real file on disk  ->  information about its new name.
    # We use the file path (not its name) as the key, so that the same image
    # referenced on two pages is renamed exactly once.
    registry: dict[str, dict] = {}

    figure_counters: dict[str, int] = {}     # page name -> how many figures so far
    used_target_names: set[str] = set()      # new names already taken (case-insensitive)
    edits_by_page: dict[Path, list[dict]] = {}
    broken_links: list[dict] = []
    protected_keys: dict[str, Path] = {}   # files we must not treat as orphans
    page_meta: dict[Path, dict] = {}
    references_found = 0

    for page in pages:
        text, encoding = read_text_file(page)
        code_spans = find_code_spans(text)
        refs = collect_image_refs(text, code_spans)

        page_meta[page] = {"text": text, "encoding": encoding, "refs": len(refs)}
        edits: list[dict] = []

        for ref in refs:
            references_found += 1
            raw = ref["raw"]

            real, reason, note = resolve_reference(raw, root, images_dir)

            if real is None:
                if reason == "external link" or reason == "skipped":
                    continue  # normal and intentional: not a broken link
                line_number = text.count("\n", 0, ref["start"]) + 1

                # Try to guess which file the author probably meant.
                suggestions = suggest_similar_images(raw, root, images_dir)
                for suggested_path, kind in suggestions:
                    # Keep such files safe from the orphan sweep: they are
                    # probably the missing image, just with a different name.
                    canonical = os.path.normcase(os.path.realpath(suggested_path))
                    protected_keys[canonical] = suggested_path

                broken_links.append({
                    "page": page.name,
                    "line": line_number,
                    "raw": raw,
                    "reason": reason,
                    "suggestions": suggestions,
                })
                continue

            key = os.path.normcase(os.path.realpath(real))

            if key not in registry:
                # First time we see this image: invent a new name for it.
                stem = image_name_stem(page)
                counter = figure_counters.get(stem, 0)

                extension = os.path.splitext(real.name)[1].lower()
                extension_notes = []
                if not extension:
                    guessed, explanation = sniff_image_extension(real)
                    if guessed:
                        extension = guessed
                        extension_notes.append(explanation)
                    else:
                        extension = DEFAULT_EXTENSION
                        extension_notes.append(f"could not detect the type, using {DEFAULT_EXTENSION}")
                        warnings.append(f"{relative_to_root(real, root)}: {explanation}")
                else:
                    if extension not in IMAGE_EXTENSIONS:
                        warnings.append(f"{relative_to_root(real, root)}: unusual extension '{extension}'")
                    else:
                        # The file already has an image extension. We trust it, but
                        # if the contents say something different we report it so
                        # you can fix the name yourself.
                        detected, _ = sniff_image_extension(real)
                        jpeg_family = {detected, extension} <= {".jpg", ".jpeg"}
                        if detected and detected != extension and not jpeg_family:
                            warnings.append(
                                f"{relative_to_root(real, root)}: the name says '{extension}' "
                                f"but the contents look like '{detected}' (name kept as it is)"
                            )

                # Find a free name: <page>_fig1.png, <page>_fig2.png, ...
                while True:
                    counter += 1
                    new_name = f"{stem}_fig{counter}{extension}"
                    if new_name.lower() not in used_target_names:
                        break
                    # Extremely rare: two pages with the same name (a.qmd + a.md).
                    warnings.append(f"two pages share the name '{stem}'; using '{new_name}' for one of them")

                used_target_names.add(new_name.lower())
                figure_counters[stem] = counter

                # A note when we move a file from the main folder into images/.
                if real.parent.name.lower() != IMAGES_DIR_NAME.lower():
                    extension_notes.append("moved from the main folder into 'images'")

                registry[key] = {
                    "source": real,
                    "new_name": new_name,
                    "target": images_dir / new_name,
                    "page": page.name,
                    "notes": extension_notes,
                    "resolution_note": note,
                }

            info = registry[key]
            new_link = f"{'/' if raw.strip().startswith('/') else ''}{IMAGES_DIR_NAME}/{info['new_name']}"

            # Only record an edit when the text actually changes.
            if new_link != text[ref["start"]:ref["end"]]:
                edits.append({"start": ref["start"], "end": ref["end"], "replacement": new_link})

        if edits:
            edits_by_page[page] = edits

    return {
        "pages": pages,
        "registry": registry,
        "edits_by_page": edits_by_page,
        "broken_links": broken_links,
        "protected_keys": protected_keys,
        "page_meta": page_meta,
        "warnings": warnings,
        "references_found": references_found,
    }


# ===========================================================================
# Step 6: find orphan images (files nobody uses)
# ===========================================================================

def looks_like_an_image(path: Path) -> bool:
    """A file counts as a candidate image if it has no extension or an image one."""
    extension = path.suffix.lower()
    return extension == "" or extension in IMAGE_EXTENSIONS


def find_orphans(root: Path, images_dir: Path, referenced_keys: set[str],
                 protected_keys: set[str]) -> tuple[list[Path], list[tuple[Path, str]], list[Path]]:
    """
    Return (orphan_files, ignored_files_with_reason, kept_because_of_broken_links).

    An "orphan" is a file that looks like an image but is not used by any page.
    We only look at the main folder and at the images folder (no subfolders),
    exactly as requested.
    """
    candidates: list[Path] = []
    ignored: list[tuple[Path, str]] = []

    for folder in (root, images_dir):
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if not path.is_file():
                continue
            if path.name.startswith("."):
                continue                      # hidden files, e.g. .gitignore
            if path.name in PROTECTED_NAMES:
                continue
            if path.suffix.lower() in {".qmd", ".md", ".py", ".txt", ".csv", ".yml", ".json", ".ps1", ".pdf", ".css"}:
                continue                      # clearly documents, not images
            if not looks_like_an_image(path):
                if folder == images_dir:
                    ignored.append((path, "not an image file; untouched"))
                continue
            if path.suffix == "":
                # No extension: open the file and make sure it really is an image,
                # so that files like LICENSE or Makefile are never moved away.
                detected, _ = sniff_image_extension(path)
                if detected is None:
                    ignored.append((path, "no extension and not a recognisable image; untouched"))
                    continue
            candidates.append(path)

    orphans: list[Path] = []
    kept: list[Path] = []
    for path in candidates:
        key = os.path.normcase(os.path.realpath(path))
        if key in referenced_keys:
            continue                          # a page uses it: keep it
        if key in protected_keys:
            kept.append(path)                 # a broken link probably meant this file
            continue
        orphans.append(path)

    return orphans, ignored, kept


# ===========================================================================
# Step 7: do the work
# ===========================================================================

def apply_renames(plan: dict, images_dir: Path, dry_run: bool, reporter: Reporter) -> list[dict]:
    """
    Move/rename every image in the plan.

    We do it in two steps (source -> temporary name -> final name) so that two
    images can never overwrite each other, even if they swap names.
    """
    registry = plan["registry"]
    results: list[dict] = []
    todo = [info for info in registry.values() if info["source"] != info["target"]]

    if dry_run:
        for info in todo:
            results.append({
                "source": info["source"],
                "target": info["target"],
                "page": info["page"],
                "notes": info["notes"],
                "resolution_note": info["resolution_note"],
            })
        return results

    # Two-step move, part 1: park every file under a temporary name.
    parked: list[tuple[Path, Path]] = []  # (temporary file, final file)
    for index, info in enumerate(todo):
        temporary = images_dir / f".organize_images_tmp_{index}"
        try:
            os.replace(info["source"], temporary)
            parked.append((temporary, info["target"]))
        except OSError as error:
            reporter.line(f"ERROR: could not move {info['source']} ({error})")

    # Two-step move, part 2: give every file its final name.
    for temporary, target in parked:
        try:
            os.replace(temporary, target)
        except OSError as error:
            reporter.line(f"ERROR: could not rename {temporary} -> {target} ({error})")

    for info in todo:
        results.append({
            "source": info["source"],
            "target": info["target"],
            "page": info["page"],
            "notes": info["notes"],
            "resolution_note": info["resolution_note"],
        })
    return results


def apply_link_updates(plan: dict, dry_run: bool) -> int:
    """Rewrite the links inside the pages. Returns how many pages changed."""
    changed = 0
    for page, edits in plan["edits_by_page"].items():
        meta = plan["page_meta"][page]
        text = meta["text"]
        encoding = meta["encoding"]

        # Replace from the END of the file towards the START, so that the
        # character positions of the earlier edits stay correct.
        new_text = text
        for edit in sorted(edits, key=lambda item: item["start"], reverse=True):
            new_text = new_text[:edit["start"]] + edit["replacement"] + new_text[edit["end"]:]

        if new_text != text:
            changed += 1
            if not dry_run:
                write_text_file(page, new_text, encoding)
    return changed


def move_orphans(orphans: list[Path], orphan_dir: Path, dry_run: bool) -> list[Path]:
    """Move unused images into the orphan folder. Returns what was moved."""
    moved: list[Path] = []
    if not orphans:
        return moved
    if not dry_run:
        orphan_dir.mkdir(exist_ok=True)
    for path in orphans:
        if not dry_run:
            os.replace(path, orphan_dir / path.name)
        moved.append(path)
    return moved


# ===========================================================================
# Step 8: the report and the manifest (undo list)
# ===========================================================================

def write_manifest(manifest_path: Path, renames: list[dict], roundtrip: bool) -> None:
    """Write a CSV with old name -> new name, useful to undo the changes."""
    with manifest_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(["old_path", "new_path", "used_on_page", "notes", "mode"])
        for item in renames:
            writer.writerow([
                item["source"].name,
                f"{IMAGES_DIR_NAME}/{item['target'].name}",
                item["page"],
                "; ".join(item["notes"] + ([item["resolution_note"]] if item["resolution_note"] else [])),
                "simulated" if roundtrip else "done",
            ])


def build_report(plan: dict, renames: list[dict], orphans_moved: list[Path], ignored: list[tuple[Path, str]],
                 kept: list[Path], root: Path, images_dir: Path, orphan_dir: Path, dry_run: bool) -> str:
    """Create the text report (shown on screen and saved to a file)."""
    reporter = Reporter(echo=False)
    mode = "DRY RUN - nothing was changed" if dry_run else "CHANGES APPLIED"

    reporter.line("IMAGE ORGANIZER REPORT")
    reporter.line("=" * 60)
    reporter.line(f"Date        : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    reporter.line(f"Project     : {root}")
    reporter.line(f"Mode        : {mode}")

    reporter.section("SUMMARY")
    reporter.line(f"Pages scanned                             : {len(plan['pages'])}")
    reporter.line(f"Image references found                    : {plan['references_found']}")
    reporter.line(f"Images renamed/moved                      : {len(renames)}")
    reporter.line(f"Broken links                              : {len(plan['broken_links'])}")
    reporter.line(f"Orphan images moved to '{orphan_dir.name}' : {len(orphans_moved)}")
    reporter.line(f"Files kept (linked by a broken link)      : {len(kept)}")
    reporter.line(f"Files left alone (not moved)              : {len(ignored)}")
    reporter.line(f"Warnings                                  : {len(plan['warnings'])}")

    reporter.section(f"RENAMED AND MOVED IMAGES ({len(renames)})")
    if not renames:
        reporter.line("(none)")
    for item in sorted(renames, key=lambda entry: entry["target"].name):
        source = relative_to_root(item["source"], root)
        target = relative_to_root(item["target"], root)
        notes = item["notes"] + ([item["resolution_note"]] if item["resolution_note"] else [])
        suffix = f"   [{'; '.join(notes)}]" if notes else ""
        reporter.line(f"{source}")
        reporter.line(f"    -> {target}   (used on {item['page']}){suffix}")

    reporter.section(f"BROKEN LINKS ({len(plan['broken_links'])})")
    if not plan["broken_links"]:
        reporter.line("(none)")
    for item in plan["broken_links"]:
        reporter.line(f"{item['page']}:{item['line']}  ->  {item['raw']}   ({item['reason']})")
        for suggested_path, kind in item.get("suggestions", []):
            label = "did you mean" if kind == "same-name" else "maybe"
            reporter.line(f"      {label}: {relative_to_root(suggested_path, root)}")

    reporter.section(f"ORPHAN IMAGES MOVED TO '{orphan_dir.name}' ({len(orphans_moved)})")
    if not orphans_moved:
        reporter.line("(none)")
    for path in orphans_moved:
        reporter.line(relative_to_root(path, root))

    if kept:
        reporter.section(f"KEPT AND NOT MOVED - LIKELY REFERENCED BY A BROKEN LINK ({len(kept)})")
        reporter.line("(Their links above are broken. Fix the link or the file name,")
        reporter.line(" then run the script again. They were NOT moved to the orphan folder.)")
        for path in kept:
            reporter.line(relative_to_root(path, root))

    if ignored:
        reporter.section(f"FILES LEFT ALONE - NOT MOVED ({len(ignored)})")
        for path, reason in ignored:
            reporter.line(f"{relative_to_root(path, root)}   ({reason})")

    reporter.section(f"WARNINGS ({len(plan['warnings'])})")
    if not plan["warnings"]:
        reporter.line("(none)")
    for message in sorted(set(plan["warnings"])):
        reporter.line(f"- {message}")

    reporter.line("")
    reporter.line("Done." if not dry_run else "This was a simulation. Run again without --dry-run to apply the changes.")
    return reporter.text()


# ===========================================================================
# Step 9: the command-line entry point
# ===========================================================================

def parse_arguments(argv: list[str]) -> argparse.Namespace:
    """Read the options the user typed after the script name."""
    parser = argparse.ArgumentParser(
        description="Rename pasted images to <page>_fig<number>.<extension> and keep links in sync.",
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="show what would happen, change nothing")
    parser.add_argument("--root", default=None,
                        help="project folder (default: the folder containing this script)")
    parser.add_argument("--report", default="image_report.txt",
                        help="text report file (default: image_report.txt)")
    parser.add_argument("--manifest", default="image_renames.csv",
                        help="CSV undo list (default: image_renames.csv)")
    parser.add_argument("--orphan-dir", default=ORPHAN_DIR_NAME,
                        help="folder for unused images (default: orphan_images)")
    parser.add_argument("--quiet", action="store_true",
                        help="do not print the report, only the summary line")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(sys.argv[1:] if argv is None else argv)

    root = Path(arguments.root).resolve() if arguments.root else Path(__file__).resolve().parent
    images_dir = root / IMAGES_DIR_NAME
    orphan_dir = root / arguments.orphan_dir

    if not root.is_dir():
        eprint(f"ERROR: the project folder does not exist: {root}")
        return 2

    if not arguments.dry_run:
        images_dir.mkdir(exist_ok=True)  # make sure 'images' exists before we move things into it

    eprint(f"Project : {root}")
    eprint(f"Mode    : {'DRY RUN (no changes)' if arguments.dry_run else 'APPLYING CHANGES'}")
    eprint("")

    # --- 1. plan (read-only) ---
    reporter = Reporter(echo=not arguments.quiet)
    plan = build_plan(root, images_dir, reporter)

    # --- 2. find orphans using the plan's list of used files ---
    referenced_keys = set(plan["registry"].keys())
    protected_keys = set(plan["protected_keys"].keys())
    orphans, ignored, kept = find_orphans(root, images_dir, referenced_keys, protected_keys)

    # --- 3. do it (or pretend to) ---
    # Orphans are moved FIRST, so they cannot block the new image names.
    orphans_moved = move_orphans(orphans, orphan_dir, arguments.dry_run)
    renames = apply_renames(plan, images_dir, arguments.dry_run, reporter)
    pages_changed = apply_link_updates(plan, arguments.dry_run)

    # --- 4. write the report and the undo list ---
    report_text = build_report(plan, renames, orphans_moved, ignored, kept, root, images_dir,
                               orphan_dir, arguments.dry_run)

    if not arguments.quiet:
        eprint(report_text)

    report_path = root / arguments.report
    report_path.write_text(report_text, encoding="utf-8-sig")

    manifest_path = root / arguments.manifest
    write_manifest(manifest_path, renames, arguments.dry_run)

    # --- 5. a short summary on screen ---
    eprint("")
    eprint("=" * 60)
    eprint(f"Pages changed        : {pages_changed}")
    eprint(f"Images renamed/moved : {len(renames)}")
    eprint(f"Broken links         : {len(plan['broken_links'])}")
    eprint(f"Orphans moved        : {len(orphans_moved)}")
    eprint(f"Report written to    : {report_path.name}")
    eprint(f"Undo list written to : {manifest_path.name}")
    if arguments.dry_run:
        eprint("")
        eprint("This was a DRY RUN. Nothing in your project was modified.")
        eprint("Run the same command without --dry-run to apply the changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
