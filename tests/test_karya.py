#!/usr/bin/env python3
"""
Smoke tests for bin/karya.

Run:   python3 -m unittest discover -s tests -v
       python3 tests/test_karya.py

Standard library only, same as the CLI itself. No network, no `gh`, no `brew`.
Every test that touches the filesystem works inside a temporary directory.

## Reading the expected failures

Tests marked `@unittest.expectedFailure` document defects that are real and
reproduced, but not yet fixed — see docs/critical-review-2026-08.md for the
analysis behind each one. They keep the suite green so CI stays a usable gate,
while making the bug impossible to forget.

If you fix one of these, the test flips to "unexpected success", which unittest
counts as a FAILURE. That is intentional: the build turning red is your reminder
to delete the decorator. Do not add an expectedFailure for a bug you could just
fix.
"""
from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
KARYA_BIN = REPO_ROOT / "bin" / "karya"
TEMPLATES = REPO_ROOT / "templates"


def load_karya():
    """Import bin/karya as a module despite it having no .py extension."""
    loader = importlib.machinery.SourceFileLoader("karya", str(KARYA_BIN))
    spec = importlib.util.spec_from_loader("karya", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


karya = load_karya()

# Hooks git will actually execute. Source: `man githooks` / the sample hooks
# shipped in git's template directory. Anything karya installs outside this set
# is dead code by construction.
KNOWN_GIT_HOOKS = {
    "applypatch-msg", "pre-applypatch", "post-applypatch",
    "pre-commit", "pre-merge-commit", "prepare-commit-msg", "commit-msg",
    "post-commit", "pre-rebase", "post-checkout", "post-merge", "pre-push",
    "pre-receive", "update", "proc-receive", "post-receive", "post-update",
    "reference-transaction", "push-to-checkout", "pre-auto-gc", "post-rewrite",
    "sendemail-validate", "fsmonitor-watchman", "p4-changelist",
    "p4-prepare-changelist", "p4-post-changelist", "p4-pre-submit",
    "post-index-change",
}

GIT_IDENTITY_ENV = {
    "GIT_AUTHOR_NAME": "Karya Test",
    "GIT_AUTHOR_EMAIL": "test@localhost",
    "GIT_COMMITTER_NAME": "Karya Test",
    "GIT_COMMITTER_EMAIL": "test@localhost",
}


class TempWorkspaceCase(unittest.TestCase):
    """Base: a temp dir, a clean cwd, and a git identity that works on CI."""

    def setUp(self):
        # .resolve() matters: on macOS /var is a symlink to /private/var, and
        # karya resolves paths internally, so an unresolved tmp dir makes every
        # path comparison fail for the wrong reason.
        self.tmp = Path(tempfile.mkdtemp(prefix="karya-test-")).resolve()
        self._old_cwd = Path.cwd()
        self._old_env = dict(os.environ)
        os.environ.update(GIT_IDENTITY_ENV)
        os.chdir(self.tmp)
        # karya is a CLI and prints freely; keep the test output readable.
        self._stack = contextlib.ExitStack()
        self._stack.enter_context(contextlib.redirect_stdout(io.StringIO()))

    def tearDown(self):
        self._stack.close()
        os.chdir(self._old_cwd)
        os.environ.clear()
        os.environ.update(self._old_env)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def init_workspace(self) -> Path:
        karya.init_workspace()
        return self.tmp

    def create_project(self, uri: str):
        """Create a project with every network path disabled."""
        original = karya.gh_available
        karya.gh_available = lambda: False
        try:
            karya.create_project(uri, mode="new", publish=False)
        finally:
            karya.gh_available = original
        return karya.resolve_uri(uri, self.tmp)


# ── URI parsing ───────────────────────────────────────────────────────────────

class TestUriParsing(unittest.TestCase):

    def test_kosh_uri_splits_into_scheme_and_path(self):
        self.assertEqual(karya.parse_uri("kosh://learning/mit/6s081"),
                         ("kosh", "learning/mit/6s081"))

    def test_file_uri_keeps_absolute_path(self):
        self.assertEqual(karya.parse_uri("file:///tmp/x"), ("file", "/tmp/x"))

    def test_missing_scheme_is_rejected(self):
        with self.assertRaises(SystemExit):
            karya.parse_uri("learning/mit/6s081")

    def test_unknown_scheme_is_rejected(self):
        with self.assertRaises(SystemExit):
            karya.parse_uri("https://example.com/x")

    def test_single_segment_path_is_rejected(self):
        with self.assertRaises(SystemExit):
            karya.parse_kosh_path("learning")

    def test_segment_roles_follow_position(self):
        self.assertEqual(
            [karya.segment_level(i) for i in range(5)],
            ["domain", "collection", "project", "subproject", "subproject"],
        )
        self.assertEqual(karya.segment_marker(2), karya.MARKER_PROJECT)


class TestCheckpointNames(unittest.TestCase):

    def test_empty_name_falls_back_to_default(self):
        self.assertEqual(karya.sanitize_checkpoint_name(None),
                         karya.DEFAULT_CHECKPOINT_NAME)
        self.assertEqual(karya.sanitize_checkpoint_name("  "),
                         karya.DEFAULT_CHECKPOINT_NAME)

    def test_path_separators_cannot_escape_the_checkpoint_dir(self):
        for hostile in ["../../etc/passwd", "..", "a/b", "x\\y"]:
            name = karya.sanitize_checkpoint_name(hostile)
            self.assertNotIn("/", name)
            self.assertNotIn("\\", name)
            self.assertNotIn("..", name)


class TestProjectMetadataSubstitution(unittest.TestCase):

    def test_known_fields_are_replaced_and_others_left_alone(self):
        out = karya.subst_project_metadata(
            "# Project\n\nName:\nURI:\nCreated:\nStatus: Draft\n\n## Notes\nkeep me\n",
            name="6s081", uri="kosh://learning/mit/6s081", created="2026-08-16",
        )
        self.assertIn("Name: 6s081", out)
        self.assertIn("URI: kosh://learning/mit/6s081", out)
        self.assertIn("Created: 2026-08-16", out)
        self.assertIn("Status: Active", out)
        self.assertIn("keep me", out)


# ── Workspace and project creation ────────────────────────────────────────────

class TestWorkspace(TempWorkspaceCase):

    def test_init_writes_marker_and_domain_dirs(self):
        self.init_workspace()
        marker = self.tmp / karya.MARKER_WORKSPACE
        self.assertTrue(marker.exists())
        data = json.loads(marker.read_text())
        self.assertEqual(data["level"], "workspace")
        self.assertEqual(data["karya_version"], karya.KARYA_VERSION)

    def test_init_refuses_to_clobber_an_existing_workspace(self):
        self.init_workspace()
        with self.assertRaises(SystemExit):
            karya.init_workspace()

    def test_find_workspace_root_walks_up_from_a_nested_dir(self):
        self.init_workspace()
        nested = self.tmp / "learning" / "mit" / "deep"
        nested.mkdir(parents=True)
        self.assertEqual(karya.find_workspace_root(nested), self.tmp)

    def test_find_workspace_root_returns_none_outside_a_workspace(self):
        outside = self.tmp / "not-a-workspace"
        outside.mkdir()
        self.assertIsNone(karya.find_workspace_root(outside))

    # ── B4 ────────────────────────────────────────────────────────────────────
    # `init workspace` creates learning/ experiments/ projects/ archive/, but
    # the templates are named learning/ experiment/ project/ (singular). Two of
    # the three offered domains cannot be used. See critical review §B4.
    @unittest.expectedFailure
    def test_every_domain_dir_created_by_init_has_a_template(self):
        self.init_workspace()
        created = {p.name for p in self.tmp.iterdir()
                   if p.is_dir() and p.name != "archive"}
        available = {p.name for p in TEMPLATES.iterdir()
                     if p.is_dir() and p.name != karya.KARYA_DIR}
        self.assertEqual(created - available, set(),
                         "init_workspace creates domain directories that have no template")


class TestCreateProject(TempWorkspaceCase):

    def test_creates_tree_markers_and_git_repo(self):
        self.init_workspace()
        project = self.create_project("kosh://learning/mit/6s081x")

        self.assertTrue(project.is_dir())
        self.assertTrue((project / ".git").is_dir())
        self.assertTrue((self.tmp / "learning" / karya.MARKER_DOMAIN).exists())
        self.assertTrue((self.tmp / "learning" / "mit" / karya.MARKER_COLLECTION).exists())

        marker = json.loads((project / karya.MARKER_PROJECT).read_text())
        self.assertEqual(marker["setup_status"], "complete")
        self.assertEqual(marker["uri"], "kosh://learning/mit/6s081x")
        self.assertEqual(marker["level"], "project")

    def test_template_internals_are_not_copied_into_the_project(self):
        self.init_workspace()
        project = self.create_project("kosh://learning/mit/6s081x")
        # .karya/ is karya's own metadata …
        self.assertFalse((project / karya.KARYA_DIR).exists())
        # … and MPS nodes (template dirs carrying their own .karya/) are content
        # for *other* projects, not this one.
        self.assertFalse((project / "mit").exists())

    def test_placeholders_are_substituted(self):
        self.init_workspace()
        project = self.create_project("kosh://learning/mit/6s081x")
        readme = (project / "README.md").read_text()
        self.assertNotIn("{{PROJECT_NAME}}", readme)
        self.assertNotIn("PROJECT_NAME", readme)
        self.assertIn("6s081x", readme)

    def test_refuses_to_recreate_a_completed_project(self):
        self.init_workspace()
        self.create_project("kosh://learning/mit/6s081x")
        with self.assertRaises(SystemExit):
            self.create_project("kosh://learning/mit/6s081x")

    def test_unknown_domain_fails_with_a_useful_message(self):
        self.init_workspace()
        with self.assertRaises(SystemExit):
            self.create_project("kosh://nosuchdomain/a/b")

    # ── B3 ────────────────────────────────────────────────────────────────────
    # _install_post_push_hook() writes .git/hooks/post-push. Git has no such
    # hook, so the auto-checkpoint it advertises never runs. See review §B3.
    @unittest.expectedFailure
    def test_only_installs_git_hooks_that_git_actually_runs(self):
        self.init_workspace()
        project = self.create_project("kosh://learning/mit/6s081x")
        installed = {p.name for p in (project / ".git" / "hooks").iterdir()
                     if not p.name.endswith(".sample")}
        self.assertEqual(installed - KNOWN_GIT_HOOKS, set(),
                         "karya installed a hook name git will never execute")

    # ── B15 ───────────────────────────────────────────────────────────────────
    # The identity fallback runs `git config local user.name ...` instead of
    # `git config --local ...`, which git rejects with "key does not contain a
    # section". On a machine with no global git identity the initial commit is
    # then skipped, leaving a repo with no commits. See review §B15.
    @unittest.expectedFailure
    def test_initial_commit_exists_without_a_global_git_identity(self):
        self.init_workspace()
        for var in list(GIT_IDENTITY_ENV):
            os.environ.pop(var, None)
        os.environ["GIT_CONFIG_GLOBAL"] = str(self.tmp / "empty-gitconfig")
        os.environ["GIT_CONFIG_SYSTEM"] = str(self.tmp / "empty-gitconfig")
        project = self.create_project("kosh://learning/mit/6s081x")
        log = karya.run_git_command(["log", "--oneline"], cwd=project)
        self.assertEqual(log.returncode, 0, "no initial commit was created")
        self.assertTrue(log.stdout.strip())

    # ── B7 ────────────────────────────────────────────────────────────────────
    # kosh path segments are never validated, so `..` escapes the workspace and
    # karya scaffolds outside the tree it manages. See review §B7.
    @unittest.expectedFailure
    def test_uri_segments_cannot_escape_the_workspace(self):
        self.init_workspace()
        with self.assertRaises(SystemExit):
            karya.resolve_uri("kosh://learning/../../escaped", self.tmp)


class TestTwoSegmentUri(TempWorkspaceCase):
    """A 2-segment URI is explicitly allowed by parse_kosh_path, but the marker
    it produces is degenerate — see review §A1."""

    @unittest.expectedFailure
    def test_project_marker_is_complete_for_a_two_segment_uri(self):
        self.init_workspace()
        project = self.create_project("kosh://learning/solo")
        marker = json.loads((project / karya.MARKER_PROJECT).read_text())
        self.assertIn("uri", marker)
        self.assertIn("karya_version", marker)


# ── Work state ────────────────────────────────────────────────────────────────

class TestWorkstate(TempWorkspaceCase):

    def make_repo(self) -> Path:
        repo = self.tmp / "repo"
        repo.mkdir()
        karya.run_git_command(["init"], cwd=repo)
        (repo / "tracked.txt").write_text("v1\n")
        karya.run_git_command(["add", "."], cwd=repo)
        karya.run_git_command(["commit", "-m", "init"], cwd=repo)
        return repo

    def save(self, repo: Path, name: str | None = None):
        os.chdir(repo)
        karya.save_workstate(name)

    def test_save_records_branch_and_writes_a_checkpoint(self):
        repo = self.make_repo()
        self.save(repo)
        data = json.loads(
            karya.get_checkpoint_file(repo, karya.DEFAULT_CHECKPOINT_NAME).read_text())
        self.assertIn(data["branch"], {"master", "main"})
        self.assertEqual(data["checkpoint_name"], karya.DEFAULT_CHECKPOINT_NAME)
        self.assertIn("checkpoint_id", data)

    def test_named_checkpoints_are_listed_separately(self):
        repo = self.make_repo()
        self.save(repo, "lab1-done")
        self.assertTrue(
            karya.get_checkpoint_file(repo, "lab1-done").exists())

    def test_uncommitted_change_is_captured_in_the_patch(self):
        repo = self.make_repo()
        (repo / "tracked.txt").write_text("v2\n")
        self.save(repo)
        patch = karya.get_checkpoint_patch_file(repo, karya.DEFAULT_CHECKPOINT_NAME)
        self.assertTrue(patch.exists())
        self.assertIn("v2", patch.read_text())

    # ── B2 ────────────────────────────────────────────────────────────────────
    # Checkpoints are written untracked *inside* the repo they snapshot, so each
    # save sweeps the previous save's .json and .patch into the new patch.
    # Growth is quadratic and the patch can never apply. See review §B2.
    @unittest.expectedFailure
    def test_repeated_saves_do_not_grow_the_patch(self):
        repo = self.make_repo()
        (repo / "tracked.txt").write_text("v2\n")
        self.save(repo)
        first = karya.get_checkpoint_patch_file(repo, karya.DEFAULT_CHECKPOINT_NAME).read_bytes()
        self.save(repo)
        second = karya.get_checkpoint_patch_file(repo, karya.DEFAULT_CHECKPOINT_NAME).read_bytes()
        self.assertEqual(len(first), len(second),
                         "the checkpoint patch is capturing its own previous output")

    @unittest.expectedFailure
    def test_patch_does_not_contain_checkpoint_metadata(self):
        repo = self.make_repo()
        (repo / "tracked.txt").write_text("v2\n")
        self.save(repo)
        self.save(repo)
        patch = karya.get_checkpoint_patch_file(repo, karya.DEFAULT_CHECKPOINT_NAME).read_text()
        self.assertNotIn(karya.STATE_CHECKPOINT_DIR, patch)

    def test_resume_without_a_checkpoint_fails_cleanly(self):
        repo = self.make_repo()
        os.chdir(repo)
        with self.assertRaises(SystemExit):
            karya.resume_workstate("nope")


# ── End-to-end: degraded environments ─────────────────────────────────────────

class TestMissingOptionalTooling(TempWorkspaceCase):
    """README lists `gh` as optional. Run the real CLI with it absent."""

    def run_cli_without_gh(self, *args) -> subprocess.CompletedProcess:
        fake_bin = self.tmp / "fakebin"
        fake_bin.mkdir()
        for tool in ("git", "bash", "python3"):
            found = shutil.which(tool)
            if found:
                (fake_bin / tool).symlink_to(found)
        env = dict(os.environ)
        env["PATH"] = str(fake_bin)
        return subprocess.run(
            [sys.executable, str(KARYA_BIN), *args],
            cwd=str(self.tmp), env=env, capture_output=True, text=True,
        )

    # ── B1 ────────────────────────────────────────────────────────────────────
    # gh_available() calls subprocess.run(["gh", ...]) with no FileNotFoundError
    # guard, and _clone_from_remote() calls it before anything is created — so
    # `create project` dies with a traceback on any machine without gh, despite
    # the README calling gh optional. See review §B1.
    @unittest.expectedFailure
    def test_create_project_degrades_gracefully_without_gh(self):
        karya.init_workspace()
        result = self.run_cli_without_gh(
            "create", "project", "--uri", "kosh://learning/mit/nogh", "--no-publish")
        self.assertNotIn("Traceback", result.stderr)
        self.assertNotIn("FileNotFoundError", result.stderr)

    def test_help_works_without_gh(self):
        result = self.run_cli_without_gh("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("kosh://", result.stdout)


# ── Template tree invariants ──────────────────────────────────────────────────

class TestTemplateTree(unittest.TestCase):
    """Cheap structural checks over templates/ — the part of the repo that has
    no other form of verification."""

    def hook_scripts(self):
        return sorted(TEMPLATES.rglob("*.sh"))

    def test_every_hook_script_is_syntactically_valid_bash(self):
        bash = shutil.which("bash")
        if not bash:
            self.skipTest("bash not available")
        for script in self.hook_scripts():
            with self.subTest(script=str(script.relative_to(REPO_ROOT))):
                result = subprocess.run([bash, "-n", str(script)],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_customization_dirs_use_the_spelling_the_code_looks_for(self):
        """docs/design.md says 'customisations'; the code says 'customizations'.
        Any directory using the doc's spelling is silently ignored by karya."""
        stray = [p for p in TEMPLATES.rglob("customisations") if p.is_dir()]
        self.assertEqual(stray, [], "these directories will never be discovered")

    def test_hooks_are_discovered_in_general_to_specific_order(self):
        hooks = karya.discover_hooks(["learning", "mit", "6s081"])
        rels = [str(h.relative_to(TEMPLATES)) for h in hooks]
        self.assertEqual(rels, sorted(rels, key=len),
                         "hook order must run root -> domain -> collection -> project")
        self.assertTrue(rels[-1].startswith("learning/mit/6s081"))

    def test_every_customization_dir_holds_a_recognised_hook_or_assets(self):
        recognised = {"pre-create.sh", "post-create.sh", "files", "lib.sh"}
        for cust in TEMPLATES.rglob(f"{karya.KARYA_DIR}/{karya.CUSTOMIZATIONS_SUBDIR}"):
            for child in cust.iterdir():
                if child.name.endswith(".md"):
                    continue  # documentation of the level, per design.md
                with self.subTest(path=str(child.relative_to(TEMPLATES))):
                    self.assertIn(child.name, recognised,
                                  "unrecognised entry — karya will never invoke it")


if __name__ == "__main__":
    unittest.main(verbosity=2)
