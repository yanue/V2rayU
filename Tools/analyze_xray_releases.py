from __future__ import annotations

import json
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Optional, Pattern, Tuple

API_BASE = "https://api.github.com/repos/XTLS/Xray-core/releases"
USER_AGENT = "V2rayU-XrayReleaseAnalyzer/1.0"
PER_PAGE = 100
MAX_PAGES = 5


@dataclass(frozen=True)
class KeywordSpec:
    key: str
    title: str
    note: str
    patterns: Tuple[Pattern[str], ...]


def compile_patterns(*patterns: str) -> Tuple[Pattern[str], ...]:
    return tuple(re.compile(pattern, re.IGNORECASE) for pattern in patterns)


KEYWORDS: Tuple[KeywordSpec, ...] = (
    KeywordSpec("xhttp", "XHTTP", "重点用于分析新 transport 的引入/演进。", compile_patterns(r"xhttp", r"split\s*http", r"splithttp")),
    KeywordSpec("reality", "REALITY", "用于观察 REALITY 相关 release 线索。", compile_patterns(r"\breality\b")),
    KeywordSpec("hysteria", "Hysteria", "用于观察 Hysteria inbound/outbound/transport 的 release 线索。", compile_patterns(r"\bhysteria(?:\s*2)?\b")),
    KeywordSpec("wireguard", "WireGuard", "用于观察 WireGuard inbound/outbound 的 release 线索。", compile_patterns(r"wire\s*guard")),
    KeywordSpec("grpc", "gRPC", "用于观察 gRPC transport 的 release 线索。", compile_patterns(r"\bgrpc\b")),
    KeywordSpec("websocket", "WebSocket", "用于观察 WebSocket transport 的 release 线索。", compile_patterns(r"web\s*socket", r"\bws\b", r"\bwss\b")),
    KeywordSpec("httpupgrade", "HTTPUpgrade", "用于观察 HTTPUpgrade transport 的 release 线索。", compile_patterns(r"http\s*upgrade")),
    KeywordSpec("finalmask", "FinalMask", "用于观察附加配置 FinalMask 的 release 线索。", compile_patterns(r"final\s*mask")),
    KeywordSpec("sockopt", "Sockopt", "用于观察 Sockopt 的 release 线索。", compile_patterns(r"\bsockopt\b")),
)


@dataclass
class ReleaseItem:
    tag_name: str
    name: str
    published_at: Optional[datetime]
    body: str
    html_url: str

    @property
    def text(self) -> str:
        return f"{self.name}\n{self.body}".lower()


@dataclass
class MatchItem:
    release: ReleaseItem
    matched_lines: List[str]


@dataclass
class KeywordReport:
    spec: KeywordSpec
    matches: List[MatchItem]


def fetch_json(url: str) -> List[dict]:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def fetch_releases(max_pages: int = MAX_PAGES) -> List[ReleaseItem]:
    releases: List[ReleaseItem] = []
    for page in range(1, max_pages + 1):
        params = urllib.parse.urlencode({"per_page": PER_PAGE, "page": page})
        data = fetch_json(f"{API_BASE}?{params}")
        if not data:
            break
        for item in data:
            published_at = None
            raw_published_at = item.get("published_at")
            if raw_published_at:
                published_at = datetime.fromisoformat(raw_published_at.replace("Z", "+00:00"))
            releases.append(
                ReleaseItem(
                    tag_name=item.get("tag_name") or "",
                    name=item.get("name") or item.get("tag_name") or "",
                    published_at=published_at,
                    body=item.get("body") or "",
                    html_url=item.get("html_url") or "",
                )
            )
        if len(data) < PER_PAGE:
            break
    return releases


def matches_any(text: str, spec: KeywordSpec) -> bool:
    return any(pattern.search(text) for pattern in spec.patterns)


def find_matches(releases: Iterable[ReleaseItem], spec: KeywordSpec) -> KeywordReport:
    matches: List[MatchItem] = []
    for release in releases:
        if not matches_any(release.text, spec):
            continue
        lines = []
        for line in release.body.splitlines():
            if matches_any(line, spec):
                clean = re.sub(r"\s+", " ", line).strip()
                if clean:
                    lines.append(clean)
            if len(lines) >= 5:
                break
        matches.append(MatchItem(release=release, matched_lines=lines))
    return KeywordReport(spec=spec, matches=matches)


def format_dt(dt: Optional[datetime]) -> str:
    if not dt:
        return "Unknown"
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%d")


def summarize_versions(matches: List[MatchItem]) -> Tuple[str, str]:
    if not matches:
        return "N/A", "N/A"
    by_time = sorted(matches, key=lambda m: (m.release.published_at or datetime.min.replace(tzinfo=timezone.utc)))
    return by_time[0].release.tag_name, by_time[-1].release.tag_name


def build_markdown(reports: List[KeywordReport], release_count: int) -> str:
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    lines: List[str] = [
        "# Xray Release Feature Analysis",
        "",
        f"- Generated at: `{generated_at}`",
        f"- Data source: `{API_BASE}`",
        f"- Pages fetched: up to `{MAX_PAGES}` pages × `{PER_PAGE}` items",
        f"- Releases analyzed: `{release_count}`",
        "",
        "> 说明：本报告只分析 GitHub Releases API 中的 release 标题与正文提及情况。",
        "> 它可以作为**版本线索**与**功能演进证据**，但不应单独视为“官方完整支持列表”或“精确首发版本”的唯一依据。",
        "> 更稳妥的做法是：**官方 docs 主列表确定当前支持面，releases API 辅助判断版本演进**。",
        "",
        "## Summary",
        "",
        "| Feature | Match count | First matched release | Last matched release | Note |",
        "|---|---:|---|---|---|",
    ]

    for report in reports:
        first_tag, last_tag = summarize_versions(report.matches)
        lines.append(
            f"| {report.spec.title} | {len(report.matches)} | `{first_tag}` | `{last_tag}` | {report.spec.note} |"
        )

    lines.extend(["", "## Details", ""])

    for report in reports:
        lines.append(f"### {report.spec.title}")
        lines.append("")
        lines.append(f"- Note: {report.spec.note}")
        lines.append(f"- Match count: `{len(report.matches)}`")
        first_tag, last_tag = summarize_versions(report.matches)
        lines.append(f"- First matched release in fetched dataset: `{first_tag}`")
        lines.append(f"- Last matched release in fetched dataset: `{last_tag}`")
        lines.append("")
        if not report.matches:
            lines.append("No matches found in fetched release notes.")
            lines.append("")
            continue

        lines.append("Sample matched releases:")
        lines.append("")
        for match in report.matches[:8]:
            lines.append(
                f"- `{match.release.tag_name}` · {format_dt(match.release.published_at)} · [{match.release.name}]({match.release.html_url})"
            )
            if match.matched_lines:
                for raw_line in match.matched_lines[:3]:
                    lines.append(f"  - {raw_line}")
        lines.append("")

    lines.extend(
        [
            "## Suggested usage in V2rayU",
            "",
            "1. 用官方 docs 主列表判断 **当前是否支持**。",
            "2. 用本报告判断 **某功能从哪些 release 开始频繁出现**。",
            "3. 只有当 release note 与 docs/源码/兼容经验三者都能互相印证时，才把规则提升为启动前的**硬版本门槛**。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    output_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "Docs" / "XrayReleaseFeatureAnalysis.md"
    releases = fetch_releases()
    reports = [find_matches(releases, spec) for spec in KEYWORDS]
    markdown = build_markdown(reports, len(releases))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")
    print(f"Wrote report: {output_path}")
    for report in reports:
        first_tag, last_tag = summarize_versions(report.matches)
        print(f"{report.spec.title}: matches={len(report.matches)}, first={first_tag}, last={last_tag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
