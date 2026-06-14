# Karya Tool Skill

Skill: karya workspace and project management

Description:
- Understand and use the karya CLI for workspace and project lifecycle operations.
- Identify the current workspace root (look for `.karya-workspace` marker file).
- Create, publish, and remove projects using `kosh://` URIs.
- Save and restore work state checkpoints.

When to use:
- When the user asks to create, publish, or remove a project.
- When saving or resuming work across machines or sessions.
- When the user references a `kosh://` URI.

Capabilities:
- Recognise the workspace hierarchy: workspace → domain → collection → project.
- Map `kosh://domain/collection/project` URIs to filesystem paths.
- Run `karya workstate save/resume/list` for checkpoint management.
- Run `karya create project --uri kosh://...` to scaffold new projects.
