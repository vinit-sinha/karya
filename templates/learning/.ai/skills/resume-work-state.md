# Resume Work State

Skill: local work state persistence

Description:
- Track the current project work-in-progress state
- Save the latest local state, including staged/committed work and metadata needed to resume later
- Resume from the last saved state on a different machine or session

When to use:
- Before switching machines or contexts
- When the user wants the agent to capture the current work snapshot for later resumption
- When the agent needs to recover a paused task from the last saved state

Capabilities:
- `save_state`: record the current working tree, index, and commit status
- `resume_state`: restore the saved state or provide instructions to continue from it
