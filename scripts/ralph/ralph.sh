#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude] [max_iterations]

set -Eeuo pipefail

# Parse arguments
TOOL="amp"  # Default to amp for backwards compatibility
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp' or 'claude'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
WORKTREES_DIR="$SCRIPT_DIR/.worktrees"
WORKTREE_NAME=""
WORKTREE_PATH=""

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME="${LAST_BRANCH#ralph/}"
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Worktree setup
if [ -f "$PRD_FILE" ]; then
  BRANCH_NAME=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")

  if [ -n "$BRANCH_NAME" ]; then
    WORKTREE_NAME="ralph-${BRANCH_NAME#ralph/}"
    WORKTREE_PATH="$WORKTREES_DIR/$WORKTREE_NAME"

    # Create worktrees directory
    mkdir -p "$WORKTREES_DIR"

    # Check if worktree already exists
    if [ -d "$WORKTREE_PATH" ]; then
      echo "Reusing existing worktree: $WORKTREE_PATH"
    else
      # Create new worktree from main branch
      echo "Creating worktree at: $WORKTREE_PATH"
      if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>/dev/null; then
        # Branch may already exist remotely, try checkout
        echo "Branch already exists, checking out..."
        git fetch origin "$BRANCH_NAME" 2>/dev/null || true
        git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
      fi
      echo "Worktree created successfully"
    fi

    # Change to worktree directory
    cd "$WORKTREE_PATH" || exit 1
    echo "Working in worktree: $WORKTREE_PATH (branch: $(git branch --show-current))"
  else
    echo "Warning: No branchName found in prd.json, working in current directory"
  fi
else
  echo "Warning: prd.json not found, working in current directory"
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(amp --dangerously-allow-all < "$SCRIPT_DIR/prompt.md" 2>&1 | tee /dev/stderr) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1



