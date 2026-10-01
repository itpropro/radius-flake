import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
HEAD = "a" * 40
TESTED_COMMIT = "b" * 40
MERGED_COMMIT = "c" * 40
SYSTEMS = ["x86_64-linux", "aarch64-linux", "aarch64-darwin"]


class ArtifactSelectionTests(unittest.TestCase):
    def setUp(self):
        self.scratch = Path(subprocess.check_output(
            ["mktemp", "-d", "-p", "/tmp", "radius-flake-artifact-tests.XXXXXX"],
            text=True,
        ).strip())
        self.addCleanup(shutil.rmtree, self.scratch)
        tree = subprocess.check_output(
            ["git", "rev-parse", "HEAD^{tree}"], cwd=REPOSITORY, text=True,
        ).strip()
        self.responses = {
            f"commits/{MERGED_COMMIT}/pulls": [{
                "merged_at": "2026-10-01T19:29:18Z",
                "merge_commit_sha": MERGED_COMMIT,
                "head": {"sha": HEAD},
            }],
            "actions/workflows/check.yml/runs": {"workflow_runs": [{
                "id": 123,
                "run_attempt": 2,
                "head_sha": HEAD,
                "event": "pull_request",
                "conclusion": "success",
                "path": ".github/workflows/check.yml",
            }]},
            "actions/runs/123/artifacts": {"artifacts": [{
                "name": f"nix-{system}-{TESTED_COMMIT}-2",
                "expired": False,
            } for system in SYSTEMS]},
            f"git/commits/{TESTED_COMMIT}": {
                "tree": {"sha": tree},
                "parents": [{"sha": "d" * 40}, {"sha": HEAD}],
            },
        }
        gh = self.scratch / "gh"
        gh.write_text("""#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

args = sys.argv[1:]
endpoint = next(arg for arg in args if arg.startswith('repos/'))
endpoint = endpoint.split('/', 3)[3].split('?')[0]
responses = json.loads(Path(os.environ['RESPONSES']).read_text())
if endpoint not in responses:
    print('API request failed', file=sys.stderr)
    sys.exit(1)
response = json.dumps(responses[endpoint])
if '--jq' in args:
    result = subprocess.run(['jq', '-r', args[args.index('--jq') + 1]], input=response, text=True)
    sys.exit(result.returncode)
print(response)
""")
        gh.chmod(0o755)

    def resolve(self, responses):
        fixture = self.scratch / "responses.json"
        fixture.write_text(json.dumps(responses))
        output = self.scratch / "output"
        output.write_text("")
        environment = {
            **os.environ,
            "PATH": f"{self.scratch}:{os.environ['PATH']}",
            "RESPONSES": str(fixture),
            "GITHUB_REPOSITORY": "itpropro/radius-flake",
            "GITHUB_SHA": MERGED_COMMIT,
            "GITHUB_OUTPUT": str(output),
        }
        result = subprocess.run(
            ["bash", ".github/nix-artifacts.sh", "resolve"],
            cwd=REPOSITORY, env=environment, capture_output=True, text=True,
        )
        return result, output.read_text()

    def test_promotes_all_platforms_from_the_matching_successful_attempt(self):
        result, output = self.resolve(self.responses)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, f"run-id=123\nartifact-suffix={TESTED_COMMIT}-2\n")

    def test_rebuilds_when_artifacts_cannot_prove_the_tested_merged_source(self):
        for scenario in ["wrong_tree", "wrong_parent", "missing_platform", "expired", "old_attempt", "wrong_run_head", "failed_run"]:
            with self.subTest(scenario=scenario):
                responses = copy.deepcopy(self.responses)
                commit = responses[f"git/commits/{TESTED_COMMIT}"]
                artifacts = responses["actions/runs/123/artifacts"]["artifacts"]
                run = responses["actions/workflows/check.yml/runs"]["workflow_runs"][0]
                if scenario == "wrong_tree":
                    commit["tree"]["sha"] = "e" * 40
                elif scenario == "wrong_parent":
                    commit["parents"][1]["sha"] = "e" * 40
                elif scenario == "missing_platform":
                    artifacts.pop()
                elif scenario == "expired":
                    artifacts[0]["expired"] = True
                elif scenario == "old_attempt":
                    artifacts[0]["name"] = artifacts[0]["name"][:-1] + "1"
                elif scenario == "wrong_run_head":
                    run["head_sha"] = "e" * 40
                else:
                    run["conclusion"] = "failure"
                result, output = self.resolve(responses)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, "")

    def test_rebuilds_for_a_commit_without_a_merged_pr(self):
        self.responses[f"commits/{MERGED_COMMIT}/pulls"] = []
        result, output = self.resolve(self.responses)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "")

    def test_api_failure_stops_promotion(self):
        del self.responses["actions/runs/123/artifacts"]
        result, output = self.resolve(self.responses)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main()
