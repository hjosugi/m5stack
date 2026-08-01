#!/usr/bin/env python3
"""Validate the dependency-free GitHub Pages site."""

from __future__ import annotations

<<<<<<< HEAD
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.lang = ""
        self.description = ""
        self.in_title = False
        self.title_parts: list[str] = []

    @property
    def title(self) -> str:
        return "".join(self.title_parts).strip()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if identifier := values.get("id"):
            self.ids.add(identifier)
        if tag == "html":
            self.lang = values.get("lang", "") or ""
        elif tag == "title":
            self.in_title = True
        elif tag == "meta" and values.get("name") == "description":
            self.description = values.get("content", "") or ""
        elif tag in {"a", "link", "script"}:
            attribute = "src" if tag == "script" else "href"
            if target := values.get(attribute):
                self.links.append(target)

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)


def parse_pages(site_root: Path) -> tuple[dict[Path, PageParser], list[str]]:
    pages: dict[Path, PageParser] = {}
    errors: list[str] = []
    for path in sorted(site_root.rglob("*.html")):
        parser = PageParser()
        try:
            parser.feed(path.read_text(encoding="utf-8"))
            parser.close()
        except Exception as error:  # HTMLParser errors are useful with the file name attached.
            errors.append(f"{path}: HTMLを解析できません: {error}")
            continue
        pages[path.resolve()] = parser
        if parser.lang != "ja":
            errors.append(f"{path}: html lang=ja がありません")
        if not parser.title:
            errors.append(f"{path}: titleがありません")
        if not parser.description:
            errors.append(f"{path}: meta descriptionがありません")
    return pages, errors


def resolve_local_target(site_root: Path, source: Path, raw_link: str) -> tuple[Path, str] | None:
    parsed = urlsplit(raw_link)
    if parsed.scheme or parsed.netloc:
        return None
    link_path = unquote(parsed.path)
    if not link_path:
        return source.resolve(), unquote(parsed.fragment)
    if link_path.startswith("/m5stack/"):
        target = site_root / link_path.removeprefix("/m5stack/")
    elif link_path == "/m5stack":
        target = site_root
    elif link_path.startswith("/"):
        return None
    else:
        target = source.parent / link_path
    if link_path.endswith("/") or target.is_dir():
        target /= "index.html"
    return target.resolve(), unquote(parsed.fragment)


def validate_links(site_root: Path, pages: dict[Path, PageParser]) -> list[str]:
    errors: list[str] = []
    root = site_root.resolve()
    for source, parser in pages.items():
        for raw_link in parser.links:
            resolved = resolve_local_target(root, source, raw_link)
            if resolved is None:
                continue
            target, fragment = resolved
            if not target.is_relative_to(root):
                errors.append(f"{source}: site外への相対リンクです: {raw_link}")
                continue
            if not target.is_file():
                errors.append(f"{source}: リンク先がありません: {raw_link}")
                continue
            if fragment and target.suffix == ".html":
                target_parser = pages.get(target)
                if target_parser is None or fragment not in target_parser.ids:
                    errors.append(f"{source}: anchorがありません: {raw_link}")
    return errors


def main() -> int:
    site_root = Path(sys.argv[1] if len(sys.argv) > 1 else "site")
    if not site_root.is_dir():
        print(f"site directoryがありません: {site_root}", file=sys.stderr)
        return 1
    pages, errors = parse_pages(site_root)
    errors.extend(validate_links(site_root, pages))
    if not pages:
        errors.append(f"{site_root}: HTMLがありません")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"GitHub Pages: {len(pages)}ページのmetadataと内部リンクを確認しました。")
||||||| 25f29cd
=======
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


REQUIRED_DESIGN_TOKENS = {
    "color-background",
    "color-surface",
    "color-text",
    "color-text-muted",
    "color-border",
    "color-accent",
    "font-family-sans",
    "font-family-mono",
    "font-size-xs",
    "font-size-sm",
    "font-size-md",
    "font-size-lg",
    "font-size-xl",
    "font-size-2xl",
    "font-size-3xl",
    "font-size-4xl",
    "line-height-tight",
    "line-height-code",
    "line-height-body",
    "font-weight-bold",
    "font-weight-extra-bold",
    "space-1",
    "space-2",
    "space-3",
    "space-4",
    "space-5",
    "space-6",
    "space-7",
    "space-8",
    "space-9",
    "space-10",
    "space-11",
    "radius-xs",
    "radius-sm",
    "radius-md",
    "radius-lg",
    "radius-pill",
    "radius-circle",
}
TYPOGRAPHY_PROPERTIES = (
    "font-family",
    "font-size",
    "font-weight",
    "line-height",
    "letter-spacing",
)


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.lang = ""
        self.description = ""
        self.in_title = False
        self.title_parts: list[str] = []

    @property
    def title(self) -> str:
        return "".join(self.title_parts).strip()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if identifier := values.get("id"):
            self.ids.add(identifier)
        if tag == "html":
            self.lang = values.get("lang", "") or ""
        elif tag == "title":
            self.in_title = True
        elif tag == "meta" and values.get("name") == "description":
            self.description = values.get("content", "") or ""
        elif tag in {"a", "link", "script"}:
            attribute = "src" if tag == "script" else "href"
            if target := values.get(attribute):
                self.links.append(target)

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self.in_title = False

    def handle_data(self, data: str) -> None:
        if self.in_title:
            self.title_parts.append(data)


def parse_pages(site_root: Path) -> tuple[dict[Path, PageParser], list[str]]:
    pages: dict[Path, PageParser] = {}
    errors: list[str] = []
    for path in sorted(site_root.rglob("*.html")):
        parser = PageParser()
        try:
            parser.feed(path.read_text(encoding="utf-8"))
            parser.close()
        except Exception as error:  # HTMLParser errors are useful with the file name attached.
            errors.append(f"{path}: HTMLを解析できません: {error}")
            continue
        pages[path.resolve()] = parser
        if parser.lang != "ja":
            errors.append(f"{path}: html lang=ja がありません")
        if not parser.title:
            errors.append(f"{path}: titleがありません")
        if not parser.description:
            errors.append(f"{path}: meta descriptionがありません")
    return pages, errors


def resolve_local_target(site_root: Path, source: Path, raw_link: str) -> tuple[Path, str] | None:
    parsed = urlsplit(raw_link)
    if parsed.scheme or parsed.netloc:
        return None
    link_path = unquote(parsed.path)
    if not link_path:
        return source.resolve(), unquote(parsed.fragment)
    if link_path.startswith("/m5stack/"):
        target = site_root / link_path.removeprefix("/m5stack/")
    elif link_path == "/m5stack":
        target = site_root
    elif link_path.startswith("/"):
        return None
    else:
        target = source.parent / link_path
    if link_path.endswith("/") or target.is_dir():
        target /= "index.html"
    return target.resolve(), unquote(parsed.fragment)


def validate_links(site_root: Path, pages: dict[Path, PageParser]) -> list[str]:
    errors: list[str] = []
    root = site_root.resolve()
    for source, parser in pages.items():
        for raw_link in parser.links:
            resolved = resolve_local_target(root, source, raw_link)
            if resolved is None:
                continue
            target, fragment = resolved
            if not target.is_relative_to(root):
                errors.append(f"{source}: site外への相対リンクです: {raw_link}")
                continue
            if not target.is_file():
                errors.append(f"{source}: リンク先がありません: {raw_link}")
                continue
            if fragment and target.suffix == ".html":
                target_parser = pages.get(target)
                if target_parser is None or fragment not in target_parser.ids:
                    errors.append(f"{source}: anchorがありません: {raw_link}")
    return errors


def validate_styles(site_root: Path) -> list[str]:
    css_path = site_root / "assets" / "site.css"
    if not css_path.is_file():
        return [f"{css_path}: 共通CSSがありません"]

    css = css_path.read_text(encoding="utf-8")
    errors: list[str] = []
    defined_tokens = set(re.findall(r"--([a-z0-9-]+)\s*:", css))
    referenced_tokens = set(re.findall(r"var\(--([a-z0-9-]+)", css))

    for token in sorted(REQUIRED_DESIGN_TOKENS - defined_tokens):
        errors.append(f"{css_path}: 必須design token --{token} がありません")
    for token in sorted(referenced_tokens - defined_tokens):
        errors.append(f"{css_path}: 未定義のdesign token --{token} を参照しています")

    root_rule = re.search(r":root\s*\{.*?\n\}", css, flags=re.DOTALL)
    if root_rule is None:
        errors.append(f"{css_path}: :root のdesign token定義がありません")
    else:
        outside_root = css[: root_rule.start()] + css[root_rule.end() :]
        raw_color = re.search(r"#[0-9a-fA-F]{3,8}\b|(?:rgb|hsl)a?\(", outside_root)
        if raw_color:
            line = outside_root.count("\n", 0, raw_color.start()) + 1
            errors.append(f"{css_path}:{line}: 色は--color-* token経由で指定してください")

    for property_name in TYPOGRAPHY_PROPERTIES:
        declaration = re.compile(
            rf"^\s*{re.escape(property_name)}\s*:\s*([^;]+);", flags=re.MULTILINE
        )
        for match in declaration.finditer(css):
            value = match.group(1).strip()
            if "var(" in value or value == "inherit":
                continue
            line = css.count("\n", 0, match.start()) + 1
            errors.append(
                f"{css_path}:{line}: {property_name}はtypography token経由で指定してください"
            )

    shorthand = re.search(r"^\s*font\s*:", css, flags=re.MULTILINE)
    if shorthand:
        line = css.count("\n", 0, shorthand.start()) + 1
        errors.append(f"{css_path}:{line}: font shorthandは使わずtokenを個別指定してください")
    return errors


def main() -> int:
    site_root = Path(sys.argv[1] if len(sys.argv) > 1 else "site")
    if not site_root.is_dir():
        print(f"site directoryがありません: {site_root}", file=sys.stderr)
        return 1
    pages, errors = parse_pages(site_root)
    errors.extend(validate_links(site_root, pages))
    errors.extend(validate_styles(site_root))
    if not pages:
        errors.append(f"{site_root}: HTMLがありません")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(
        f"GitHub Pages: {len(pages)}ページのmetadata、内部リンク、design tokenを確認しました。"
    )
>>>>>>> agent/go-task-migration
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
