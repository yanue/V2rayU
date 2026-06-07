#!/usr/bin/env python3
"""
download-cores.py — Download core binaries for compatibility testing.

Downloads xray-core (v1.8.0 ~ v26.5.6) and sing-box (v1.12.0 ~ v1.13.12)
from GitHub Releases into Build/tests/bin/.

Respects http_proxy / https_proxy / ALL_PROXY / all_proxy environment variables.
"""

import json
import os
import platform
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

# ── Configuration ──────────────────────────────────────────────────────

BASE_DIR = Path(__file__).resolve().parent.parent.parent
TEST_BIN_DIR = BASE_DIR / "Build" / "tests" / "bin"

ARCH = platform.machine()
if ARCH == "arm64":
    XRAY_BIN_NAME = "xray-arm64"
    SINGBOX_BIN_NAME = "sing-box-arm64"
elif ARCH == "x86_64":
    XRAY_BIN_NAME = "xray-64"
    SINGBOX_BIN_NAME = "sing-box-64"
else:
    print(f"Unsupported arch: {ARCH}")
    sys.exit(1)

XRAY_MIN = "v1.8.0"
XRAY_MAX = "v26.5.6"
SINGBOX_MIN = "v1.12.0"
SINGBOX_MAX = "v1.13.13"

GITHUB_API = "https://api.github.com"
REQUESTS_PER_PAGE = 30   # smaller page size to avoid 504 on large repos
SLEEP_BETWEEN_PAGES = 1.0
SLEEP_BETWEEN_DOWNLOADS = 1.0


# ── Version helpers ────────────────────────────────────────────────────

def parse_version(tag: str):
    """Parse semver-like version, returns (major, minor, patch). Handles non-numeric suffixes."""
    v = tag.lstrip("v")
    parts = v.split(".")
    major = int(parts[0]) if len(parts) > 0 and parts[0].isdigit() else 0
    minor = 0
    patch = 0
    if len(parts) > 1:
        # Strip non-numeric suffix (e.g. "0-rc1" -> "0")
        p = parts[1].split("-")[0].split("+")[0]
        minor = int(p) if p.isdigit() else 0
    if len(parts) > 2:
        p = parts[2].split("-")[0].split("+")[0]
        patch = int(p) if p.isdigit() else 0
    return (major, minor, patch)


def version_in_range(tag: str, min_tag: str, max_tag: str) -> bool:
    v = parse_version(tag)
    v_min = parse_version(min_tag)
    v_max = parse_version(max_tag)
    return v_min <= v <= v_max


# ── curl-based HTTP helpers ────────────────────────────────────────────

def _curl_args(method: str = "GET") -> List[str]:
    """Build base curl args with proxy from environment."""
    args = ["curl", "-sfL", "--max-time", "30"]
    args.extend(["-H", "User-Agent: V2rayU-test-downloader"])

    # Detect proxy from env (supports http_proxy, https_proxy, ALL_PROXY, all_proxy)
    proxy = (
        os.environ.get("all_proxy")
        or os.environ.get("ALL_PROXY")
        or os.environ.get("https_proxy")
        or os.environ.get("http_proxy")
    )
    if proxy:
        args.extend(["-x", proxy])

    # Add retry flag for transient failures
    args.extend(["--retry", "3", "--retry-delay", "2"])

    if method == "GET" and "Accept" not in str(args):
        args.extend(["-H", "Accept: application/vnd.github.v3+json"])

    return args


def curl_get(url: str) -> Optional[bytes]:
    args = _curl_args("GET") + [url]
    try:
        result = subprocess.run(args, capture_output=True, timeout=60)
        if result.returncode == 0:
            return result.stdout
        return None
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT: {url[:60]}...")
        return None


def curl_download(url: str, dest: Path) -> bool:
    args = _curl_args("GET") + ["--max-time", "120", "-o", str(dest), url]
    try:
        result = subprocess.run(args, capture_output=True, timeout=180)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"  TIMEOUT downloading: {url[:60]}...")
        return False


# ── GitHub API ─────────────────────────────────────────────────────────

def fetch_json(url: str) -> Optional[dict]:
    data = curl_get(url)
    if not data:
        return None
    try:
        return json.loads(data)
    except json.JSONDecodeError:
        return None


def fetch_json_list(url: str) -> list:
    """Fetch URL and return as list, handling both list and dict responses."""
    data = curl_get(url)
    if not data:
        return []
    try:
        result = json.loads(data)
        if isinstance(result, list):
            return result
        return [result] if isinstance(result, dict) else []
    except json.JSONDecodeError:
        return []


def fetch_releases(repo: str, page: int = 1) -> list:
    url = f"{GITHUB_API}/repos/{repo}/releases?page={page}&per_page={REQUESTS_PER_PAGE}"
    return fetch_json_list(url)


def fetch_release_by_tag(repo: str, tag: str) -> Optional[dict]:
    url = f"{GITHUB_API}/repos/{repo}/releases/tags/{tag}"
    return fetch_json(url)


def fetch_tags(repo: str, page: int = 1) -> list:
    """Use Tags API instead of Releases API — much smaller response payload."""
    url = f"{GITHUB_API}/repos/{repo}/tags?page={page}&per_page={REQUESTS_PER_PAGE}"
    return fetch_json_list(url)


# ── Core downloaders ───────────────────────────────────────────────────

@dataclass
class AssetPattern:
    name_template: str
    extract_cmd: str
    binary_name: str


XRAY_PATTERN = AssetPattern(
    name_template="Xray-macos-arm64-v8a.zip" if ARCH == "arm64" else "Xray-macos-64.zip",
    extract_cmd="zip",
    binary_name="xray",
)

SINGBOX_PATTERN = AssetPattern(
    name_template="sing-box-{version}-darwin-arm64.tar.gz" if ARCH == "arm64" else "sing-box-{version}-darwin-amd64.tar.gz",
    extract_cmd="tar",
    binary_name="sing-box",
)


def download_core(repo: str, tag: str, version_dir: Path, pattern: AssetPattern, dest_bin_name: str) -> bool:
    dest_bin = version_dir / dest_bin_name
    if dest_bin.exists():
        print(f"  SKIP {tag} (already downloaded)")
        return True

    print(f"  [{tag}] Fetching release info via direct URL...")

    # Construct download URL directly (avoids GitHub API rate limits)
    asset_name = pattern.name_template.format(version=tag.lstrip("v"))
    download_url = f"https://github.com/{repo}/releases/download/{tag}/{asset_name}"
    asset_url = download_url

    print(f"  Downloading {asset_name}...")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        archive_file = tmp_path / asset_name

        if not curl_download(asset_url, archive_file):
            return False

        try:
            if pattern.extract_cmd == "zip":
                with zipfile.ZipFile(archive_file) as zf:
                    zf.extractall(tmp_path)
            else:
                with tarfile.open(archive_file) as tf:
                    tf.extractall(tmp_path)
        except Exception as e:
            print(f"  FAIL: extraction failed: {e}")
            return False

        binary = None
        for f in tmp_path.rglob(pattern.binary_name):
            if f.is_file():
                binary = f
                break

        if not binary:
            print(f"  FAIL: {pattern.binary_name} binary not found in archive")
            return False

        version_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(binary, dest_bin)
        dest_bin.chmod(dest_bin.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

        subprocess.run(["xattr", "-rd", "com.apple.quarantine", str(dest_bin)], capture_output=True)

    print(f"  OK: saved to {dest_bin}")
    return True


def list_tags_in_range(repo: str, min_tag: str, max_tag: str, use_releases_api: bool = True) -> List[str]:
    tags = []
    page = 1

    if use_releases_api:
        # Releases API: can filter by draft/prerelease
        while True:
            print(f"  Fetching releases page {page}...")
            releases = fetch_releases(repo, page)
            if not releases:
                break
            for rel in releases:
                if rel.get("draft") or rel.get("prerelease"):
                    continue
                tag = rel.get("tag_name", "")
                if version_in_range(tag, min_tag, max_tag):
                    tags.append(tag)
            if len(releases) < REQUESTS_PER_PAGE:
                break
            page += 1
            time.sleep(SLEEP_BETWEEN_PAGES)
    else:
        # Tags API: lighter payload, but cannot filter by draft/prerelease.
        while True:
            print(f"  Fetching tags page {page}...")
            tag_list = fetch_tags(repo, page)
            if not tag_list:
                # If API is rate-limited, fall back to known tags
                print("  API rate limited, falling back to known tags")
                return _known_singbox_tags(min_tag, max_tag)
            for entry in tag_list:
                tag = entry.get("name", "")
                # Skip alpha/beta/rc/prerelease tags
                if "-alpha" in tag or "-beta" in tag or "-rc" in tag or "-dev" in tag:
                    continue
                if version_in_range(tag, min_tag, max_tag):
                    tags.append(tag)
            if len(tag_list) < REQUESTS_PER_PAGE:
                break
            page += 1
            time.sleep(SLEEP_BETWEEN_PAGES)

    return sorted(set(tags), key=parse_version)


def _known_singbox_tags(min_tag: str, max_tag: str) -> List[str]:
    """Fallback known tags for sing-box when API is unavailable."""
    known = [
        "v1.12.0", "v1.12.1", "v1.12.2", "v1.12.3", "v1.12.4", "v1.12.5",
        "v1.12.7", "v1.12.8", "v1.12.9", "v1.12.10", "v1.12.11", "v1.12.12",
        "v1.12.13", "v1.12.14", "v1.12.15", "v1.12.16", "v1.12.17", "v1.12.18",
        "v1.12.19", "v1.12.20", "v1.12.21", "v1.12.22", "v1.12.23", "v1.12.24",
        "v1.12.25",
        "v1.13.0", "v1.13.1", "v1.13.2", "v1.13.3", "v1.13.4", "v1.13.5",
        "v1.13.6", "v1.13.7", "v1.13.8", "v1.13.9", "v1.13.10", "v1.13.11",
        "v1.13.12", "v1.13.13",
    ]
    return [t for t in known if version_in_range(t, min_tag, max_tag)]


# ── Argument parsing ───────────────────────────────────────────────────

def parse_args():
    import argparse
    parser = argparse.ArgumentParser(description="Download core binaries for compatibility testing")
    parser.add_argument("--core", choices=["xray", "sing-box", "all"], default="all",
                        help="Which core to download (default: all)")
    return parser.parse_args()


# ── Tag cache ──────────────────────────────────────────────────────────

TAG_CACHE_FILE = TEST_BIN_DIR / ".tag_cache.json"


def load_tag_cache() -> dict:
    if TAG_CACHE_FILE.exists():
        try:
            return json.loads(TAG_CACHE_FILE.read_text())
        except Exception:
            return {}
    return {}


def save_tag_cache(cache: dict):
    TAG_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    TAG_CACHE_FILE.write_text(json.dumps(cache, indent=2))


def get_cached_or_fetch_tags(repo: str, min_tag: str, max_tag: str, use_releases_api: bool,
                              cache_key: str) -> List[str]:
    cache = load_tag_cache()
    cached = cache.get(cache_key)
    if cached and isinstance(cached, list) and len(cached) > 0:
        print(f"  Using cached {len(cached)} tags for {cache_key}")
        return cached

    tags = list_tags_in_range(repo, min_tag, max_tag, use_releases_api)
    if tags:
        cache[cache_key] = tags
        save_tag_cache(cache)
        print(f"  Cached {len(tags)} tags for {cache_key}")
    return tags


# ── Main ───────────────────────────────────────────────────────────────

def main():
    args = parse_args()
    download_xray = args.core in ("xray", "all")
    download_singbox = args.core in ("sing-box", "all")

    TEST_BIN_DIR.mkdir(parents=True, exist_ok=True)
    (TEST_BIN_DIR / "xray-core").mkdir(exist_ok=True)
    (TEST_BIN_DIR / "sing-box").mkdir(exist_ok=True)

    if download_xray:
        print("=== Fetching Xray-core releases ===")
        xray_tags = get_cached_or_fetch_tags(
            "XTLS/Xray-core", XRAY_MIN, XRAY_MAX,
            use_releases_api=True, cache_key="xray"
        )
        print(f"Found {len(xray_tags)} Xray-core versions in range")
        for tag in xray_tags:
            version_dir = TEST_BIN_DIR / "xray-core" / tag
            download_core("XTLS/Xray-core", tag, version_dir, XRAY_PATTERN, XRAY_BIN_NAME)
            time.sleep(SLEEP_BETWEEN_DOWNLOADS)

    if download_singbox:
        print("=== Fetching sing-box tags ===")
        singbox_tags = get_cached_or_fetch_tags(
            "SagerNet/sing-box", SINGBOX_MIN, SINGBOX_MAX,
            use_releases_api=False, cache_key="sing-box"
        )
        print(f"Found {len(singbox_tags)} sing-box versions in range")
        for tag in singbox_tags:
            version_dir = TEST_BIN_DIR / "sing-box" / tag
            download_core("SagerNet/sing-box", tag, version_dir, SINGBOX_PATTERN, SINGBOX_BIN_NAME)
            time.sleep(SLEEP_BETWEEN_DOWNLOADS)

    print("\n=== Download Summary ===")
    xray_count = len(list((TEST_BIN_DIR / "xray-core").glob(f"*/{XRAY_BIN_NAME}")))
    singbox_count = len(list((TEST_BIN_DIR / "sing-box").glob(f"*/{SINGBOX_BIN_NAME}")))
    print(f"Xray-core:  {xray_count} versions downloaded")
    print(f"Sing-Box:   {singbox_count} versions downloaded")
    print(f"Location:   {TEST_BIN_DIR}")
    print("Done.")


if __name__ == "__main__":
    main()
