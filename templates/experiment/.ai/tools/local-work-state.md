# Local Work State Tool

Tool: local-work-state

Description:
- Save the current repository/workspace state as a resumption checkpoint
- Restore or report the last saved checkpoint for resuming work on another machine
- List saved checkpoints for easy resumption

Script:
- `.ai/tools/local-work-state`

Usage:
- `./.ai/tools/local-work-state save --name latest --description "WIP checkpoint"`
- `./.ai/tools/local-work-state resume --name latest --apply`
- `./.ai/tools/local-work-state list`

Inputs:
- `name`: optional checkpoint name; defaults to `latest`
- `description`: optional checkpoint description when saving
- `apply`: boolean flag to apply saved patch when resuming

Outputs:
- checkpoint metadata printed to stdout
- saved JSON checkpoint file under `.karya/state-checkpoints/`
- optional patch file containing uncommitted changes
