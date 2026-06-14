# Karya — AI Assistant Guidelines

## Git Workflow (MANDATORY)

**Never work directly on `master`.** Every piece of work must follow this flow:

1. **Create a feature branch** before making any changes:
   ```bash
   git checkout master && git pull
   git checkout -b feature/<short-description>
   ```
2. **All commits go on the feature branch** — never commit directly to `master`
3. **When work is complete**, create a PR:
   ```bash
   gh pr create --title "..." --body "..."
   ```
4. **Review the PR**, then merge to `master` via GitHub (or `gh pr merge`)
5. **Delete the feature branch** after merge

This applies to all changes — bug fixes, features, documentation, configuration.
