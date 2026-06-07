# AI Workspace Directory

This repository uses `.ai` as the primary agent content directory.

## Purpose

- Store prompts, skills, tools, agents, and hooks in one place
- Enable IDEs and AI copilots to discover your agent data
- Support a `.github` symlink to `.ai` when needed by specific tools

## Usage

- Keep prompt files under `.ai/prompts`
- Keep skill definitions under `.ai/skills`
- Keep tool definitions under `.ai/tools`
- Keep agent configs under `.ai/agents`
- Keep hook scripts or metadata under `.ai/hooks`

## Softlink strategy

If an agent expects `.github` instead of `.ai`, create a softlink:

```bash
ln -s .ai .github
```

The `.vscode/settings.json` file in this repo also includes settings that should help IDEs discover `.ai` content without a symlink when possible.
