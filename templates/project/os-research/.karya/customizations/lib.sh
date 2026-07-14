#!/usr/bin/env bash
# lib.sh — shared setup functions for all kosh://project/os-research/xv6-* variants.
# Source this from each variant's post-create.sh after setting required variables:
#
#   VARIANT          e.g. "c", "cpp", "rust"
#   GITHUB_REPO_SLUG e.g. "project-os-research-xv6-c-upstream" — must NOT
#                    collide with karya's own auto-publish name for the
#                    project itself (which is "project-os-research-xv6-c",
#                    no suffix) or the two repos get tangled together
#   KERNEL_DIR       absolute path where the read-only reference clone lives
#   STAGE0_BRANCH    e.g. "stage0/c-toolchain"
#   TOOLCHAIN_LABEL  e.g. "gcc-15"  (used as toolchain/current subdir name)
#
# After sourcing, call xv6_clone_kernel to mirror+clone the reference, then
# xv6_checkout_stage0_branch <dir> to create/checkout STAGE0_BRANCH in <dir> —
# pass KERNEL_DIR for the xv6-c track (which builds the clone directly) or
# PROJECT_ROOT for reimplementation tracks (xv6-cpp, xv6-rust), whose real
# work happens in the project's own repo, not in the read-only reference.
#
# The sourcing script must also set:
#   PROJECT_ROOT     (set before sourcing)
#   CUSTOMIZATION_DIR (set before sourcing)
#   FILES_DIR        (set before sourcing)

set -euo pipefail

UPSTREAM_URL="https://github.com/mit-pdos/xv6-riscv.git"

# ── helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[$VARIANT] $*"; }
warn() { echo "[$VARIANT] WARNING: $*" >&2; }

read_marker_field() {
    python3 -c "
import json, sys
try:
    d = json.load(open('$PROJECT_ROOT/.karya-project'))
    print(d.get('$1', ''))
except Exception:
    print('')
" 2>/dev/null || echo ""
}

write_marker_field() {
    local key="$1" value="$2"
    python3 -c "
import json
path = '$PROJECT_ROOT/.karya-project'
try:
    d = json.load(open(path))
except Exception:
    d = {}
d['$key'] = '$value'
json.dump(d, open(path, 'w'), indent=2)
" 2>/dev/null || true
}

# ── guard ─────────────────────────────────────────────────────────────────────

xv6_windows_guard() {
    local os
    os="$(uname -s 2>/dev/null || echo unknown)"
    if [[ "$os" == MINGW* || "$os" == MSYS* || "$os" == CYGWIN* ]]; then
        echo "This project requires Linux tools (QEMU, cross-compiler)."
        echo "Use WSL2 on Windows."
        exit 1
    fi
}

# ── homebrew ──────────────────────────────────────────────────────────────────

xv6_check_homebrew() {
    if ! command -v brew &>/dev/null; then
        log "ERROR: Homebrew not found. Install from https://brew.sh then re-run with --continue"
        exit 1
    fi
}

# ── QEMU ─────────────────────────────────────────────────────────────────────

xv6_install_qemu() {
    if ! command -v qemu-system-riscv64 &>/dev/null; then
        log "Installing QEMU ..."
        brew install qemu
    else
        log "QEMU: $(command -v qemu-system-riscv64)"
    fi
}

# ── riscv bintools (shared by c, cpp, and as linker/debugger for rust) ───────

xv6_install_riscv_toolchain() {
    if ! command -v riscv64-unknown-elf-gcc &>/dev/null; then
        log "Installing RISC-V toolchain ..."
        brew tap riscv-software-src/riscv 2>/dev/null || true
        brew trust riscv-software-src/riscv 2>/dev/null || true
        brew install riscv-gnu-toolchain
    else
        log "RISC-V toolchain: $(command -v riscv64-unknown-elf-gcc) ($(riscv64-unknown-elf-gcc --version | head -1))"
    fi
}

# ── LLVM/Clang (only for tracks that benchmark GCC vs LLVM, e.g. xv6-c-cmake) ─
# A modern Homebrew `clang` is a single multi-target binary — no separate
# "riscv64-unknown-elf-clang" package exists or is needed. Cross-compiling is
# `clang --target=riscv64-unknown-elf ...` plus `ld.lld` for linking.
# `lld` is a SEPARATE Homebrew formula from `llvm` (split out some time
# ago) and — unlike `llvm`, which is keg-only — installs linked directly
# onto PATH, so it lives at a different prefix than the rest of LLVM. Don't
# assume `ld.lld` is at `$LLVM_BIN/ld.lld`; it isn't.
# Sets LLVM_BIN and LLD_BIN (predeclare both before calling, same
# convention as GITHUB_REPO_URL).

xv6_install_llvm_toolchain() {
    if ! brew list llvm &>/dev/null; then
        log "Installing LLVM (clang, llvm-* tools) ..."
        brew install llvm
    else
        log "LLVM: already installed"
    fi
    LLVM_BIN="$(brew --prefix llvm)/bin"
    if [[ ! -x "$LLVM_BIN/clang" ]]; then
        warn "clang not found at $LLVM_BIN — Homebrew llvm formula layout may have changed"
    else
        log "LLVM clang: $LLVM_BIN/clang ($("$LLVM_BIN/clang" --version | head -1))"
    fi

    if ! command -v ld.lld &>/dev/null; then
        log "Installing lld ..."
        brew install lld
    else
        log "lld: $(command -v ld.lld)"
    fi
    LLD_BIN="$(brew --prefix lld)/bin"
    if [[ ! -x "$LLD_BIN/ld.lld" ]]; then
        warn "ld.lld not found at $LLD_BIN — Homebrew lld formula layout may have changed"
    fi
}

# ── toolchain/current symlink farm ────────────────────────────────────────────
# Creates toolchain/<label>/ with symlinks to the given binary directory,
# then points toolchain/current → toolchain/<label>.
# Extra symlinks (wrappers) can be passed as "name:target" pairs.

xv6_setup_toolchain_dir() {
    local label="$1"        # e.g. gcc-15
    local bin_dir="$2"      # e.g. /opt/homebrew/bin
    local prefix="$3"       # e.g. riscv64-unknown-elf-  (empty string = no prefix)
    shift 3
    local extras=("$@")     # additional "symlink_name:target_path" pairs

    local tc_dir="$PROJECT_ROOT/toolchain/$label"
    mkdir -p "$tc_dir"

    # Standard bintools — only symlink what actually exists
    local tools=(gcc g++ as ld ar ranlib nm strip objcopy objdump gdb)
    for tool in "${tools[@]}"; do
        local binary="${bin_dir}/${prefix}${tool}"
        if [[ -f "$binary" || -L "$binary" ]]; then
            ln -sf "$binary" "$tc_dir/${prefix}${tool}"
        fi
    done

    # Extra symlinks (e.g. cargo, rustc)
    # ${extras[@]+"${extras[@]}"} (not plain "${extras[@]}") because macOS
    # ships bash 3.2, which treats a zero-element array as unset under `set -u`.
    for extra in "${extras[@]+"${extras[@]}"}"; do
        local name="${extra%%:*}"
        local target="${extra##*:}"
        if [[ -f "$target" || -L "$target" ]]; then
            ln -sf "$target" "$tc_dir/$name"
        fi
    done

    # Point current → this label (create or update). Relative target, not
    # $tc_dir (absolute) — this symlink gets committed to git, and an
    # absolute path would break the moment the repo is checked out anywhere
    # other than this exact machine at this exact path.
    local current="$PROJECT_ROOT/toolchain/current"
    ln -sfn "$label" "$current"
    log "toolchain/current → toolchain/$label"

    # .gitignore: track the symlink structure but not binaries
    cat > "$PROJECT_ROOT/toolchain/.gitignore" <<'GITIGNORE'
# Toolchain directories contain symlinks to host binaries — track structure, not targets.
# Add toolchain/<label>/ dirs to git so the layout is visible, but gitignore the binaries
# themselves if you copy rather than symlink (we always symlink, so this is a no-op).
GITIGNORE
}

# ── GitHub: mirror + clone ────────────────────────────────────────────────────

xv6_github_setup() {
    if ! command -v gh &>/dev/null; then
        warn "gh CLI not found — skipping GitHub setup. Install: brew install gh && gh auth login"
        return 0
    fi
    if [[ -z "$(gh api user --jq '.login' 2>/dev/null)" ]]; then
        warn "Not authenticated with gh. Run: gh auth login, then re-run with --continue"
        return 0
    fi

    local github_user
    github_user=$(gh api user --jq '.login')
    gh auth setup-git 2>/dev/null || true

    local github_repo="$github_user/$GITHUB_REPO_SLUG"
    local github_url="https://github.com/$github_repo.git"

    local stored
    stored=$(read_marker_field "github_mirror")
    if [[ -n "$stored" ]]; then
        log "Using stored GitHub repo: $stored"
        GITHUB_REPO_URL="$stored"
        return 0
    fi

    if gh repo view "$github_repo" &>/dev/null 2>&1; then
        log "Found existing GitHub repo: https://github.com/$github_repo"
    else
        log "Creating private GitHub repo: https://github.com/$github_repo ..."
        gh repo create "$github_repo" --private \
            --description "Read-only mirror of mit-pdos/xv6-riscv — reference for the $VARIANT track, not a working copy" || {
            log "ERROR: failed to create GitHub repo. Re-run with --continue."
            exit 1
        }
        log "Mirroring mit-pdos/xv6-riscv → $github_repo ..."
        local tmp
        tmp=$(mktemp -d)
        # --bare (not --mirror): a GitHub-hosted source exposes refs/pull/*
        # as fetchable refs, and --mirror would try to push those on to the
        # new repo too — GitHub always rejects them ("hidden ref"), which
        # makes `git push --mirror` exit nonzero even though every ref that
        # actually matters (branches, tags) transferred fine. --bare only
        # fetches refs/heads/* and tags, so refs/pull/* never enters the
        # picture and there's nothing spurious to reject.
        git clone --bare "$UPSTREAM_URL" "$tmp/xv6.git" || {
            log "ERROR: mirror clone from upstream failed."
            rm -rf "$tmp"; exit 1
        }
        git -C "$tmp/xv6.git" push "$github_url" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*' || {
            log "ERROR: mirror push failed."
            rm -rf "$tmp"; exit 1
        }
        rm -rf "$tmp"
        log "Mirror complete."
    fi

    GITHUB_REPO_URL="$github_url"
    write_marker_field "github_mirror" "$GITHUB_REPO_URL"
}

xv6_clone_kernel() {
    if [[ ! -d "$KERNEL_DIR/.git" ]]; then
        mkdir -p "$(dirname "$KERNEL_DIR")"
        log "Cloning xv6-riscv from your GitHub ..."
        git clone "$GITHUB_REPO_URL" "$KERNEL_DIR" || {
            log "ERROR: clone failed. Re-run with --continue."
            exit 1
        }
    else
        log "Kernel already present at $KERNEL_DIR"
        local current_origin
        current_origin=$(git -C "$KERNEL_DIR" remote get-url origin 2>/dev/null || echo "")
        if [[ "$current_origin" != "$GITHUB_REPO_URL" ]]; then
            git -C "$KERNEL_DIR" remote set-url origin "$GITHUB_REPO_URL" 2>/dev/null || \
            git -C "$KERNEL_DIR" remote add origin "$GITHUB_REPO_URL"
            log "Updated origin → $GITHUB_REPO_URL"
        fi
    fi

    # Fetch-only upstream pointing to the real mit-pdos/xv6-riscv
    cd "$KERNEL_DIR"
    if ! git remote get-url upstream &>/dev/null; then
        git remote add upstream "$UPSTREAM_URL"
        git remote set-url --push upstream no_push
        log "Added upstream (fetch-only, push blocked)"
    fi
    cd "$PROJECT_ROOT"
}

# Create/checkout STAGE0_BRANCH in the given git repo. Call with $KERNEL_DIR
# for xv6-c (builds the reference clone directly); call with $PROJECT_ROOT
# for reimplementation tracks (xv6-cpp, xv6-rust), whose own repo is where
# real work happens — kernel/xv6-riscv there stays untouched as reference.
xv6_checkout_stage0_branch() {
    local dir="$1"
    if [[ ! -d "$dir/.git" ]]; then
        return 0
    fi
    if ! git -C "$dir" show-ref --quiet "refs/heads/$STAGE0_BRANCH"; then
        git -C "$dir" checkout -b "$STAGE0_BRANCH"
        log "Created branch $STAGE0_BRANCH in $(basename "$dir")"
    else
        git -C "$dir" checkout "$STAGE0_BRANCH"
    fi
}

# ── VS Code + project files ───────────────────────────────────────────────────

xv6_install_files() {
    mkdir -p "$PROJECT_ROOT/.vscode" "$PROJECT_ROOT/scripts" \
             "$PROJECT_ROOT/docs/adr" "$PROJECT_ROOT/work" \
             "$PROJECT_ROOT/toolchain"

    for f in tasks.json settings.json extensions.json; do
        [[ -f "$FILES_DIR/.vscode/$f" ]] && \
            cp "$FILES_DIR/.vscode/$f" "$PROJECT_ROOT/.vscode/$f" && \
            log "Installed .vscode/$f"
    done

    for f in README.md CLAUDE.md STAGES.md; do
        [[ -f "$FILES_DIR/$f" ]] && \
            cp "$FILES_DIR/$f" "$PROJECT_ROOT/$f" && \
            log "Installed $f"
    done

    # Glob against $FILES_DIR, not cwd — "docs/adr/*.md" alone expands
    # relative to $PROJECT_ROOT (the script's cwd), which at this point only
    # has the generic 0000-template.md from karya's base template, not the
    # variant-specific ADRs this customization actually ships.
    for f in "$FILES_DIR"/docs/adr/*.md; do
        [[ -f "$f" ]] && \
            cp "$f" "$PROJECT_ROOT/docs/adr/$(basename "$f")" && \
            log "Installed docs/adr/$(basename "$f")"
    done

    # Copy whatever scripts this variant ships — not a fixed build/run/debug
    # list, since some variants (xv6-c-cmake) ship extras like bench.sh.
    for script in "$FILES_DIR"/scripts/*; do
        if [[ -f "$script" ]]; then
            cp "$script" "$PROJECT_ROOT/scripts/$(basename "$script")"
            chmod +x "$PROJECT_ROOT/scripts/$(basename "$script")"
            log "Installed scripts/$(basename "$script")"
        fi
    done
}

# ── SETUP.md ──────────────────────────────────────────────────────────────────

# $2: "build" (xv6-c builds kernel/xv6-riscv directly) or "reference" (xv6-cpp,
#     xv6-rust — kernel/xv6-riscv is read-only, real work is in src/)
# $3: quick-start command block override (defaults per mode if omitted)
xv6_write_setup_md() {
    local extra_status="${1:-}"   # optional extra rows for the status table
    local kernel_mode="${2:-build}"
    local quick_start="${3:-}"
    local kernel_branch
    kernel_branch=$(git -C "$KERNEL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    local kernel_source_desc quick_start_default
    if [[ "$kernel_mode" == "reference" ]]; then
        kernel_source_desc="\`kernel/xv6-riscv/\` — your private mirror of mit-pdos/xv6-riscv, read for reimplementation reference. Not built directly.

## $VARIANT kernel

\`src/\` — not yet populated. Stage 0 (see STAGES.md) is the first real implementation work."
        quick_start_default=$'./scripts/build.sh\n./scripts/run.sh       # Ctrl-a x to exit'
    else
        kernel_source_desc="\`kernel/xv6-riscv/\` — your private fork of mit-pdos/xv6-riscv.
Current branch: \`$kernel_branch\`"
        quick_start_default=$'cd kernel/xv6-riscv && make qemu    # Ctrl-a x to exit'
    fi
    [[ -z "$quick_start" ]] && quick_start="$quick_start_default"

    cat > "$PROJECT_ROOT/SETUP.md" <<SETUP
# xv6-$VARIANT — Setup Status

**Last updated:** $(date +%Y-%m-%d)
**URI:** kosh://project/os-research/xv6-$VARIANT

## Environment

| Component | Status |
|-----------|--------|
| qemu-system-riscv64 | $(command -v qemu-system-riscv64 &>/dev/null && echo '✓' || echo '✗ missing') |
| GitHub repo (origin) | ${GITHUB_REPO_URL:-(not configured)} |
| Upstream (fetch-only) | $UPSTREAM_URL |
${extra_status}

## Kernel source

$kernel_source_desc

## Quick start

\`\`\`bash
$quick_start
\`\`\`

Or use VS Code tasks: **Cmd+Shift+P → Tasks: Run Task**.

## Re-run setup

\`\`\`bash
karya create project --uri kosh://project/os-research/xv6-$VARIANT --continue
\`\`\`
SETUP
    log "Wrote SETUP.md"
}
