#!/usr/bin/env python3
"""Verify that every repository-local Markdown link resolves."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\((?P<target><[^>]+>|[^\s)]+)(?:\s+['\"][^)]*['\"])?\)")
FENCE_PATTERN = re.compile(r"^\s*(```|~~~)")


def local_target(markdown_file: Path, raw_target: str, repo_root: Path) -> Path | None:
    target = raw_target.removeprefix("<").removesuffix(">")
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None

    path = Path(unquote(parsed.path))
    if path.is_absolute():
        return repo_root / str(path).lstrip("/")
    return markdown_file.parent / path


def links_outside_fences(markdown_file: Path):
    in_fence = False
    fence = ""
    for line_number, line in enumerate(markdown_file.read_text(encoding="utf-8").splitlines(), 1):
        marker = FENCE_PATTERN.match(line)
        if marker:
            current = marker.group(1)
            if not in_fence:
                in_fence = True
                fence = current[0]
            elif current[0] == fence:
                in_fence = False
            continue
        if not in_fence:
            for match in LINK_PATTERN.finditer(line):
                yield line_number, match.group("target")


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    markdown_files = sorted(repo_root.rglob("*.md"))
    markdown_files = [path for path in markdown_files if ".git" not in path.parts and ".local" not in path.parts]
    errors: list[str] = []

    for markdown_file in markdown_files:
        for line_number, raw_target in links_outside_fences(markdown_file):
            target = local_target(markdown_file, raw_target, repo_root)
            if target is not None and not target.exists():
                relative_file = markdown_file.relative_to(repo_root)
                errors.append(f"{relative_file}:{line_number}: リンク先がありません: {raw_target}")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    print(f"Markdown links: OK ({len(markdown_files)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
