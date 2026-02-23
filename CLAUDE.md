## Product Requirements Document (PRD)
- Include note on PRD to update SPECIFICATION.md after finish the implementation
- After the implementation, the status of the document must be "Done"

## Codebase Patterns
- Use `set -Eeuo pipefail` at top of all bash scripts for error handling
- All profile validation uses strict regex: ^[a-zA-Z0-9_-]{1,64}$
- Profile functions quote all paths to prevent injection attacks
- Directories handled via environment variables: CCSW_CONFIG_DIR, CCSW_PROFILES_DIR
- CLI script must capture and propagate exit codes with `return $?`
- State-free design means no files written, only environment variables output
- External directory detection uses exact path comparison to avoid false positives
- Manual testing requires subshell for state-free verification
- Test scripts should use `|| true` to handle expected error conditions
- Profile deletion prevention via CLAUDE_CONFIG_DIR comparison
