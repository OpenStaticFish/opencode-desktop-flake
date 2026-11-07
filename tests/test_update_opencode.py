import base64
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import update_opencode as updater


def release(tag, *, draft=False, prerelease=False, digest="sha256:" + "ab" * 32):
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "assets": [{"name": name, "digest": digest} for name in updater.ASSETS],
    }


def flake(version="2.2.6"):
    assets = "\n".join(f'  asset = "{name}";\n  hash = "sha256-old";' for name in updater.ASSETS)
    return f'version = "{version}";\n{assets}\n'


class UpdateOpenCodeTests(unittest.TestCase):
    def test_selects_highest_stable_v2_version(self):
        releases = [
            release("v1.99.0"),
            release("process-daemon-v2.99.0"),
            release("v2.9.0", prerelease=True),
            release("v2.10.0", draft=True),
            release("v3.0.0"),
            release("v2.2.9"),
            release("v2.2.10"),
            release("v2.2.11-rc.1"),
        ]
        self.assertEqual(updater.latest_v2(releases)["tag_name"], "v2.2.10")

    def test_searches_later_pages_when_first_has_no_v2(self):
        class Response:
            def __init__(self, payload):
                self.payload = payload

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def read(self):
                import json
                return json.dumps(self.payload).encode()

        pages = [Response([release("v1.19.5")]), Response([release("v2.2.6")])]
        with patch.object(updater, "urlopen", side_effect=pages) as urlopen:
            self.assertEqual(updater.fetch_release()["tag_name"], "v2.2.6")
        self.assertEqual(urlopen.call_count, 2)

    def test_updates_every_hash_and_the_version(self):
        result = updater.update_flake(flake(), release("v2.3.0"))
        digest = "sha256-" + base64.b64encode(bytes.fromhex("ab" * 32)).decode()
        self.assertIn('version = "2.3.0";', result)
        self.assertEqual(result.count(digest), len(updater.ASSETS))
        self.assertNotIn("sha256-old", result)

    def test_updates_the_actual_flake_layout(self):
        result = updater.update_flake(updater.FLAKE.read_text(), release("v2.99999.0"))
        digest = "sha256-" + base64.b64encode(bytes.fromhex("ab" * 32)).decode()
        self.assertIn('version = "2.99999.0";', result)
        self.assertEqual(result.count(digest), len(updater.ASSETS))

    def test_rejects_downgrades(self):
        with self.assertRaisesRegex(ValueError, "Refusing to downgrade"):
            updater.update_flake(flake(), release("v2.2.5"))

    def test_same_version_is_unchanged(self):
        self.assertEqual(updater.update_flake(flake(), release("v2.2.6")), flake())

    def test_rejects_missing_asset(self):
        candidate = release("v2.3.0")
        candidate["assets"].pop()
        with self.assertRaisesRegex(ValueError, "Expected exactly one release asset"):
            updater.update_flake(flake(), candidate)

    def test_rejects_missing_or_malformed_digest(self):
        for digest in (None, "", "sha256:", "sha256:" + "zz" * 32):
            with self.subTest(digest=digest), self.assertRaisesRegex(ValueError, "invalid SHA-256"):
                updater.update_flake(flake(), release("v2.3.0", digest=digest))

    def test_rejects_missing_or_duplicated_flake_entries(self):
        with self.assertRaisesRegex(ValueError, "exactly one hash entry"):
            updater.update_flake(flake().replace(updater.ASSETS[0], "missing"), release("v2.3.0"))
        with self.assertRaisesRegex(ValueError, "exactly one flake version"):
            updater.update_flake(flake() + 'version = "2.2.6";\n', release("v2.3.0"))


if __name__ == "__main__":
    unittest.main()
