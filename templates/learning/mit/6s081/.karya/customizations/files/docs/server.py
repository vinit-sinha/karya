#!/usr/bin/env python3
"""
Local courseware server for 6.S081.
Serves static files and handles:
  - Schedule preference persistence (GET /prefs, POST /save-prefs)
  - Lab schedule dates (POST /save-schedule-dates)
  - Lab status tracking (GET /lab-status, POST /start-lab)
  - GitHub PR status via gh CLI for done/approved detection

Usage:
    python3 docs/server.py          # default port 7681
    python3 docs/server.py 8080     # custom port
"""
import http.server
import json
import os
import subprocess
import sys
import urllib.parse
from datetime import datetime, timezone

PORT       = int(sys.argv[1]) if len(sys.argv) > 1 else 7681
DOCS_DIR   = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(DOCS_DIR)
XV6_DIR    = os.path.join(PROJECT_DIR, "starter-code", "xv6-labs-2021")

PREFS_FILE      = os.path.join(DOCS_DIR, ".schedule-prefs.json")
LAB_STATUS_FILE = os.path.join(DOCS_DIR, ".lab-status.json")


# ── Helpers ───────────────────────────────────────────────────────────────────

def _read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default if default is not None else {}

def _write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

def _get_xv6_repo():
    """Return 'owner/repo' for the xv6 GitHub remote, or None."""
    try:
        r = subprocess.run(
            ["git", "-C", XV6_DIR, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5
        )
        url = r.stdout.strip().removesuffix(".git")
        if "github.com/" in url:
            return url.split("github.com/")[-1]
    except Exception:
        pass
    return None

def _get_github_prs(repo):
    """Fetch all PRs from GitHub via gh CLI. Returns list of PR dicts."""
    if not repo:
        return []
    try:
        r = subprocess.run(
            [
                "gh", "pr", "list",
                "--repo", repo,
                "--state", "all",
                "--json", "number,title,headRefName,state,mergedAt,reviews,author,url,statusCheckRollup",
                "--limit", "100",
            ],
            capture_output=True, text=True, timeout=20
        )
        if r.returncode == 0:
            return json.loads(r.stdout)
    except Exception:
        pass
    return []

def _is_approved_by_other(pr):
    """True if the PR has an APPROVED review from someone other than the PR author."""
    author = (pr.get("author") or {}).get("login", "")
    for review in pr.get("reviews") or []:
        reviewer = (review.get("author") or {}).get("login", "")
        if review.get("state") == "APPROVED" and reviewer and reviewer != author:
            return True
    return False

def _checks_passed(pr):
    """True if the PR ran status checks and all of them succeeded.

    A PR with no checks configured returns False — "nothing ran" is not a
    passing gate.
    """
    rollup = pr.get("statusCheckRollup") or []
    if not rollup:
        return False
    for check in rollup:
        # CheckRun entries carry `conclusion`; older StatusContext entries `state`.
        outcome = (check.get("conclusion") or check.get("state") or "").upper()
        if outcome not in ("SUCCESS", "NEUTRAL", "SKIPPED"):
            return False
    return True

def _gate_cleared(pr):
    """True if this PR passed *a* review gate before being merged.

    Originally this meant "approved by a co-learner". Studying solo, that is
    unreachable — GitHub does not let an author approve their own PR — so every
    merged lab would sit at 'merged_ungated' forever. Green CI counts as the
    gate too: it is the reviewer that is actually present.
    """
    return _is_approved_by_other(pr) or _checks_passed(pr)

def _lab_status_from_pr(pr):
    """Derive lab status fields from a GitHub PR dict."""
    state = pr.get("state", "")
    merged_at = pr.get("mergedAt")
    if state == "MERGED" and _gate_cleared(pr):
        return "done", merged_at
    if state == "MERGED":
        return "merged_ungated", merged_at
    if state == "OPEN":
        return "in_review", None
    return None, None


# ── Request handlers ───────────────────────────────────────────────────────────

def _send_json(handler, data, status=200):
    body = json.dumps(data).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.end_headers()
    handler.wfile.write(body)

def _read_body(handler):
    length = int(handler.headers.get("Content-Length", 0))
    return json.loads(handler.rfile.read(length))


class Handler(http.server.SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOCS_DIR, **kwargs)

    # ── GET /prefs ────────────────────────────────────────────────────────────
    def _serve_prefs(self):
        _send_json(self, _read_json(PREFS_FILE, None))

    # ── POST /save-prefs ──────────────────────────────────────────────────────
    def _save_prefs(self):
        try:
            _write_json(PREFS_FILE, _read_body(self))
            _send_json(self, {"ok": True})
        except Exception as e:
            _send_json(self, {"error": str(e)}, 400)

    # ── POST /save-schedule-dates ─────────────────────────────────────────────
    # Body: { util: { scheduledStart: "2026-06-22", scheduledDue: "2026-07-01" }, ... }
    def _save_schedule_dates(self):
        try:
            dates = _read_body(self)
            status = _read_json(LAB_STATUS_FILE, {})
            for lab, d in dates.items():
                status.setdefault(lab, {}).update({
                    "scheduledStart": d.get("scheduledStart"),
                    "scheduledDue":   d.get("scheduledDue"),
                })
            _write_json(LAB_STATUS_FILE, status)
            _send_json(self, {"ok": True})
        except Exception as e:
            _send_json(self, {"error": str(e)}, 400)

    # ── POST /start-lab ───────────────────────────────────────────────────────
    # Body: { lab: "util" }
    def _start_lab(self):
        try:
            body = _read_body(self)
            lab = body.get("lab", "").strip()
            if not lab:
                _send_json(self, {"error": "lab is required"}, 400)
                return
            status = _read_json(LAB_STATUS_FILE, {})
            status.setdefault(lab, {})["startedAt"] = datetime.now(timezone.utc).date().isoformat()
            _write_json(LAB_STATUS_FILE, status)
            _send_json(self, {"ok": True, "lab": lab, "startedAt": status[lab]["startedAt"]})
        except Exception as e:
            _send_json(self, {"error": str(e)}, 400)

    # ── GET /lab-status ───────────────────────────────────────────────────────
    def _serve_lab_status(self):
        status = _read_json(LAB_STATUS_FILE, {})
        repo   = _get_xv6_repo()
        prs    = _get_github_prs(repo)

        # Index PRs by branch name (the xv6 branch = lab slug)
        pr_by_branch = {}
        for pr in prs:
            branch = pr.get("headRefName", "")
            pr_by_branch[branch] = pr

        # Build enriched status per lab
        result = {}
        for lab, data in status.items():
            entry = dict(data)
            pr = pr_by_branch.get(lab)
            if pr:
                gh_status, merged_at = _lab_status_from_pr(pr)
                entry["pr"] = {
                    "number":    pr.get("number"),
                    "url":       pr.get("url"),
                    "state":     pr.get("state"),
                    "mergedAt":  merged_at,
                    "approved":  _is_approved_by_other(pr),
                    "checksPassed": _checks_passed(pr),
                    "ghStatus":  gh_status,
                    "author":    (pr.get("author") or {}).get("login"),
                    "approvers": [
                        r["author"]["login"]
                        for r in (pr.get("reviews") or [])
                        if r.get("state") == "APPROVED"
                        and r.get("author", {}).get("login") != (pr.get("author") or {}).get("login")
                    ],
                }
            result[lab] = entry

        _send_json(self, {"labs": result, "repo": repo, "ghAvailable": repo is not None})

    # ── Route dispatch ────────────────────────────────────────────────────────
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        routes = {
            "/prefs":      self._serve_prefs,
            "/lab-status": self._serve_lab_status,
        }
        if path in routes:
            routes[path]()
        else:
            super().do_GET()

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        routes = {
            "/save-prefs":          self._save_prefs,
            "/save-schedule-dates": self._save_schedule_dates,
            "/start-lab":           self._start_lab,
        }
        if path in routes:
            routes[path]()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        if args and str(args[1]) not in ("200", "304"):
            super().log_message(fmt, *args)


if __name__ == "__main__":
    os.chdir(DOCS_DIR)
    try:
        httpd = http.server.HTTPServer(("", PORT), Handler)
    except OSError as e:
        import errno
        if e.errno == errno.EADDRINUSE:
            print(f"[6s081] Courseware already running at http://localhost:{PORT} — nothing to do.")
            raise SystemExit(0)
        raise
    with httpd:
        print(f"[6s081] Courseware running at http://localhost:{PORT}")
        print(f"[6s081] Project:     {PROJECT_DIR}")
        print(f"[6s081] Prefs:       {PREFS_FILE}")
        print(f"[6s081] Lab status:  {LAB_STATUS_FILE}")
        print(f"[6s081] Stop with Ctrl-C")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[6s081] Server stopped.")
