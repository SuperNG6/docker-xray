"""Offline release detection regression checks: python3 -m unittest discover -s tests."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '.github/workflows/update_release_tag.sh'


class ReleaseDetectionTests(unittest.TestCase):
    def run_detection(self, releases=None, stable='v2.0.0', local_stable='v1.0.0',
                      local_pre='', mode='auto', overrides=None, fail=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'ReleaseTag').write_text(local_stable)
            (root / 'PreReleaseTag').write_text(local_pre)
            (root / 'latest.json').write_text(json.dumps(
                dict(tag_name=stable, draft=False, prerelease=False)))
            releases = [] if releases is None else releases
            pages = [releases[i:i+100] for i in range(0, len(releases), 100)] + [[]]
            for index, page in enumerate(pages, 1):
                (root / f'page{index}.json').write_text(json.dumps(page))
            curl = root / 'curl'
            curl.write_text('''#!/usr/bin/env bash
if [[ "$FAIL_API" == 1 ]]; then exit 22; fi
for arg in "$@"; do url=$arg; done
if [[ "$url" == */latest ]]; then
    cat latest.json
else
    cat "page${url##*page=}.json"
fi
''')
            curl.chmod(0o755)
            env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'],
                       GITHUB_OUTPUT=str(root / 'output'), FAIL_API=str(int(fail)))
            env.pop('INPUT_STABLE', None)
            env.pop('INPUT_PRE', None)
            env.update(overrides or {})
            result = subprocess.run(['bash', str(SCRIPT), mode], cwd=root,
                                    env=env, text=True, capture_output=True)
            output = (root / 'output').read_text() if (root / 'output').exists() else ''
            self.assertEqual((root / 'ReleaseTag').read_text(), local_stable)
            self.assertEqual((root / 'PreReleaseTag').read_text(), local_pre)
            return result, dict(line.split('=', 1) for line in output.splitlines())

    @staticmethod
    def pre(tag='v3.0.0', draft=False):
        return dict(tag_name=tag, prerelease=True, draft=draft)

    def test_both_new(self):
        result, out = self.run_detection([self.pre()])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out, dict(stable_version='v2.0.0', pre_version='v3.0.0',
                                  should_build_stable='true', should_build_pre='true'))

    def test_unchanged(self):
        _, out = self.run_detection([self.pre()], local_stable='v2.0.0', local_pre='v3.0.0')
        self.assertEqual(out['should_build_stable'], 'false')
        self.assertEqual(out['should_build_pre'], 'false')

    def test_only_pre_changed(self):
        _, out = self.run_detection([self.pre()], local_stable='v2.0.0')
        self.assertEqual(out['should_build_stable'], 'false')
        self.assertEqual(out['should_build_pre'], 'true')

    def test_no_pre_keeps_record(self):
        _, out = self.run_detection(local_pre='v1.5.0')
        self.assertEqual(out['pre_version'], '')
        self.assertEqual(out['should_build_pre'], 'false')

    def test_drafts_excluded(self):
        _, out = self.run_detection([self.pre('v4.0.0', True), self.pre()])
        self.assertEqual(out['pre_version'], 'v3.0.0')

    def test_pagination(self):
        releases = [dict(tag_name=f'v2.0.{i}', draft=False, prerelease=False)
                    for i in range(100)] + [self.pre()]
        _, out = self.run_detection(releases)
        self.assertEqual(out['pre_version'], 'v3.0.0')

    def test_api_failure_has_no_outputs(self):
        result, out = self.run_detection(fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(out, {})

    def test_manual_empty_pre_skipped(self):
        result, out = self.run_detection(mode='manual')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out['stable_version'], 'v1.0.0')
        self.assertEqual(out['should_build_stable'], 'true')
        self.assertEqual(out['should_build_pre'], 'false')

    def test_manual_overrides(self):
        _, out = self.run_detection(mode='manual', overrides=dict(INPUT_PRE='v4.0.0-rc.1'))
        self.assertEqual(out['pre_version'], 'v4.0.0-rc.1')
        self.assertEqual(out['should_build_pre'], 'true')

    def test_invalid_input_rejected(self):
        result, out = self.run_detection(mode='manual', overrides=dict(INPUT_PRE='v1\nother=value'))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(out, {})


if __name__ == '__main__':
    unittest.main()
