# AI Tool Definitions

Store tool configuration files that describe available actions.

## Structure

- Each tool can be represented by a separate file
- Include tool name, description, inputs, and outputs
- Keep the format simple and machine-readable

## Example

- `.ai/tools/git.md`
- `.ai/tools/file-system.md`
- `.ai/tools/shell.md`
- `.ai/tools/local-work-state.md`
- `.ai/tools/local-work-state`

## Notes

These files should describe what each tool does so an AI agent can choose the right tool.
