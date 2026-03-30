## Product Requirements Document (PRD)
- Include note on PRD to update SPECIFICATION.md after finish the implementation
- After the implementation, the status of the document must be "Done"

## Codebase Patterns
- Use `set -Eeuo pipefail` at top of all bash scripts for error handling
- .shellcheckrc format: use `disable=SC2148` (no spaces around equals sign)
- SC1134 errors occur when .shellcheckrc has invalid syntax - always test with `shellcheck file.sh` after changes
- SC1091 warnings are informational when sourcing files - use `shellcheck -x` to include sourced files in analysis
- Add missing utilities files when shellcheck reports SC1091 for sourcing
- All profile validation uses strict regex: ^[a-zA-Z0-9_-]{1,64}$
- Profile functions quote all paths to prevent injection attacks
- Directories handled via environment variables: CCSW_CONFIG_DIR, CCSW_PROFILES_DIR
- CLI script must capture and propagate exit codes with `return $?`
- State-free design means no files written, only environment variables output
- External directory detection uses exact path comparison to avoid false positives
- Manual testing requires subshell for state-free verification
- Test scripts should use `|| true` to handle expected error conditions
- Profile deletion prevention via CLAUDE_CONFIG_DIR comparison

## Test Isolation Patterns
- Integration tests use `mktemp -d` to create temporary test directories
- Test scripts set `CCSW_CONFIG_DIR` and `CCSW_PROFILES_DIR` to temporary paths
- Error handling requires `set +e`/`set -e` around commands that exit with non-zero codes
- Test cleanup uses `rm -rf` on temporary directories
- Binary detection should have fallback logic for worktree vs project root execution
- Use explicit paths from script location when referencing parent directories
- Integration tests should work correctly even with empty home directories
- Environment variable-based configuration provides natural isolation
