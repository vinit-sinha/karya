#!/usr/bin/env python3
"""
Local courseware server for 6.S081.
Serves static files and handles preference persistence so settings
survive across browsers and machines.

Usage:
    python3 docs/server.py          # default port 7681
    python3 docs/server.py 8080     # custom port
"""
import http.server
import json
import os
import sys
import urllib.parse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 7681
PREFS_FILE = os.path.join(os.path.dirname(__file__), ".schedule-prefs.json")


class Handler(http.server.SimpleHTTPRequestHandler):

    def __init__(self, *args, **kwargs):
        # Serve files relative to this script's directory
        super().__init__(*args, directory=os.path.dirname(__file__), **kwargs)

    # ── GET /prefs ────────────────────────────────────────────────────────────
    def _serve_prefs(self):
        if os.path.exists(PREFS_FILE):
            with open(PREFS_FILE) as f:
                data = f.read().encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"null")

    # ── POST /save-prefs ──────────────────────────────────────────────────────
    def _save_prefs(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            prefs = json.loads(body)
            with open(PREFS_FILE, "w") as f:
                json.dump(prefs, f, indent=2)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"ok": true}')
        except Exception as e:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    # ── Route dispatch ────────────────────────────────────────────────────────
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/prefs":
            self._serve_prefs()
        else:
            super().do_GET()

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/save-prefs":
            self._save_prefs()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        # Suppress noisy access logs; only print errors
        if args and str(args[1]) not in ("200", "304"):
            super().log_message(fmt, *args)


if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    with http.server.HTTPServer(("", PORT), Handler) as httpd:
        print(f"[6s081] Courseware running at http://localhost:{PORT}")
        print(f"[6s081] Preferences saved to: {PREFS_FILE}")
        print(f"[6s081] Stop with Ctrl-C")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[6s081] Server stopped.")
