# Ralph Agent Instructions

You are an autonomous coding agent working on a software project.

## Files reference

The files `prd.json` and `progress.txt` cited in this document are present in the SAME directory as the `ralph.sh` script.

## Your Task

1. Run quality checks to ensure that you are starting in a green state
2. Read the PRD at `prd.json`
3. Read the progress log at `progress.txt` (check Codebase Patterns section first)
4. The worktree has been automatically created for the correct branch. Work in the current directory.
5. Pick the **highest priority** user story where `passes: false`
6. Implement that SINGLE user story
7. Run automatic quality checks present in the section `QA` of the project `README.md`.
8. Update `CLAUDE.md` files if you discover reusable patterns (see below)
9. If checks pass, commit ALL UNIQUE user story changes with message: `feat: [Story ID] - [Story Title]`
10. Update the PRD to set `passes: true` for the completed story
11. Append your progress to `progress.txt`

## Progress Report Format

APPEND to `progress.txt` (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the evaluation panel is in component X")
---
```

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand the codebase better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of `progress.txt` (create it if it doesn't exist). This section should consolidate the most important learnings:

```
## Codebase Patterns
- Example: Use `sql<number>` template for aggregations
- Example: Always use `IF NOT EXISTS` for migrations
- Example: Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update CLAUDE.md Files

Before committing, check if any edited files have learnings worth preserving in nearby CLAUDE.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing CLAUDE.md** - Look for CLAUDE.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
  - API patterns or conventions specific to that module
  - Gotchas or non-obvious requirements
  - Dependencies between files
  - Testing approaches for that area
  - Configuration or environment requirements

**Examples of good CLAUDE.md additions:**
- "When modifying X, also update Y to keep them in sync"
- "This module uses pattern Z for all API calls"
- "Tests require the dev server running on PORT 3000"
- "Field names must match the template exactly"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in `progress.txt`

Only update `CLAUDE.md` if you have **genuinely reusable knowledge** that would help future work in that directory.

## Quality Requirements

- Do NOT commit code failing the QA process
- Keep changes focused and minimal
- Follow existing code patterns

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## IMPORTANT

- Work on ONE story per iteration
- Commit every completed story
- Don't add the `progress.txt` and `prd.json` files to the repository
- Keep CI green
- Read the Codebase Patterns section in `progress.txt` before starting
