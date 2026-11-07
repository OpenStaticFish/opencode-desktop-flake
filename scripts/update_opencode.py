#!/usr/bin/env python3
"""Update the flake from the latest stable OpenCode v2 desktop release."""

import base64
import json
import os
import re
import sys
from pathlib import Path
from urllib.request import Request, urlopen


FLAKE = Path(__file__).resolve().parents[1] / "flake.nix"
RELEASES_URL = "https://api.github.com/repos/anomalyco/opencode/releases?per_page=100&page={}"
ASSETS = (
    "opencode-desktop-linux-amd64.deb",
    "opencode-desktop-linux-arm64.deb",
    "opencode-desktop-mac-arm64.app.tar.gz",
    "opencode-desktop-mac-x64.app.tar.gz",
)
VERSION_PATTERN = re.compile(r"v(2)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\Z")


def release_version(release):
    if release.get("draft") or release.get("prerelease"):
        return None
    match = VERSION_PATTERN.fullmatch(release.get("tag_name", ""))
    return tuple(map(int, match.groups())) if match else None


def latest_v2(releases):
    candidates = [(version, release) for release in releases if (version := release_version(release))]
    return max(candidates, key=lambda candidate: candidate[0])[1] if candidates else None


def fetch_release():
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "opencode-desktop-flake"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    page = 1
    while True:
        request = Request(RELEASES_URL.format(page), headers=headers)
        with urlopen(request, timeout=30) as response:
            releases = json.load(response)
        if not isinstance(releases, list):
            raise ValueError("GitHub returned an invalid releases response")
        if not releases:
            raise ValueError("No stable OpenCode v2 release found")
        release = latest_v2(releases)
        if release is not None:
            return release
        page += 1


def asset_hashes(release):
    hashes = {}
    for name in ASSETS:
        matches = [asset for asset in release.get("assets", []) if asset.get("name") == name]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one release asset named {name}")
        digest = matches[0].get("digest") or ""
        if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
            raise ValueError(f"Missing or invalid SHA-256 digest for {name}")
        hashes[name] = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode("ascii")
    return hashes


def update_flake(text, release):
    version = release_version(release)
    if version is None:
        raise ValueError("Release is not a stable OpenCode v2 release")

    version_pattern = re.compile(r'(?m)^([ \t]*version = ")(\d+\.\d+\.\d+)(";)')
    versions = version_pattern.findall(text)
    if len(versions) != 1:
        raise ValueError("Expected exactly one flake version")
    current = tuple(map(int, versions[0][1].split(".")))
    if version < current:
        raise ValueError(f"Refusing to downgrade {versions[0][1]} to {release['tag_name']}")
    if version == current:
        return text

    hashes = asset_hashes(release)
    text, count = version_pattern.subn(lambda match: match[1] + release["tag_name"][1:] + match[3], text)
    if count != 1:
        raise ValueError("Could not update flake version")
    for name, digest in hashes.items():
        pattern = re.compile(
            rf'(?m)^([ \t]*asset = "{re.escape(name)}";\n[ \t]*hash = ")[^"]*(";)'
        )
        text, count = pattern.subn(lambda match: match[1] + digest + match[2], text)
        if count != 1:
            raise ValueError(f"Expected exactly one hash entry for {name}")
    return text


def main():
    release = fetch_release()
    before = FLAKE.read_text()
    after = update_flake(before, release)
    if before == after:
        print(f"OpenCode {release['tag_name']} is already up to date")
    else:
        FLAKE.write_text(after)
        print(f"Updated OpenCode Desktop to {release['tag_name']}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f"OpenCode update failed: {error}", file=sys.stderr)
        sys.exit(1)
