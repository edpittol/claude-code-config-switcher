# Product Requirements Document: ccsw Phase 1

**Document Version:** 1.0
**Date:** 2026-02-22
**Status:** Done
**Phase:** Phase 1 - Core Profile CRUD

---

## 1. Executive Summary

### Problem Statement
Claude Code CLI and VSCode extension do not natively support profile management, preventing users from maintaining separate configurations for different accounts, projects, or providers (e.g., personal Anthropic account, work account, z.ai integration). Users must manually manage the `CLAUDE_CONFIG_DIR` environment variable or switch configuration files.

### Proposed Solution
Build `ccsw` (Claude Code Switcher), a lightweight Bash CLI tool that manages multiple Claude Code profiles by manipulating the `CLAUDE_CONFIG_DIR` environment variable. Phase 1 delivers core CRUD operations: list profiles, switch profiles, show current profile, and delete profiles.

**Key Design Decision: State-Free**
The tool does **not** persist state to disk. All profile detection relies on the current shell's `CLAUDE_CONFIG_DIR` environment variable. This simplifies the implementation, eliminates state synchronization issues, and ensures the tool always reflects the actual environment state.

### Success Criteria
- **Functional**: All 4 commands (`use`, `list`, `current`, `delete`) work correctly with exit code 0 on success
- **Quality**: 100% of code passes shellcheck with zero errors or warnings
- **Test Coverage**: 100% of functions have unit tests with ≥90% line coverage
- **Performance**: Commands execute within 100ms for ≤100 profiles
- **Usability**: Manual testing confirms Claude Code uses correct config after `eval "$(ccsw use <profile>)"`

---

## 2. User Experience & Functionality

### User Personas

#### Primary Persona: Developer Multi-Account User
- **Profile**: Software developer using Claude Code for both personal and work projects
- **Pain Points**:
  - Needs to switch between personal Anthropic account and work-provided account
  - Currently manually edits environment variables or config files
  - Risk of accidentally using wrong account for work code (data leakage) or personal code (billing issues)
- **Goals**: Fast, safe profile switching with clear confirmation of active profile

#### Secondary Persona: Multi-Provider User
- **Profile**: Developer experimenting with alternative Claude Code providers (z.ai, custom endpoints)
- **Pain Points**: Each provider requires different configuration in separate config directories
- **Goals**: Maintain isolated profiles for each provider without manual file management

### User Stories

#### US-1: List Available Profiles
**As a** developer,
**I want to** list all configured profiles,
**So that** I can see what profiles are available before switching.

**Acceptance Criteria:**
- [ ] Command: `ccsw list`
- [ ] Output: One profile name per line, sorted alphabetically
- [ ] Exit code 0 if ≥1 profiles exist
- [ ] Exit code 1 if no profiles exist
- [ ] No output to stderr on success
- [ ] Handles profile names with only a-zA-Z0-9_- characters

#### US-2: Switch to Profile
**As a** developer,
**I want to** switch to a specified profile,
**So that** Claude Code uses the correct configuration.

**Acceptance Criteria:**
- [ ] Command: `ccsw use <profile>`
- [ ] Outputs: `export CLAUDE_CONFIG_DIR=<full-path>` for eval
- [ ] Exit code 0 on successful switch
- [ ] Exit code 1 if profile doesn't exist
- [ ] Error message to stderr if profile invalid: `ERROR: Profile not found: <profile>`
- [ ] Idempotent: switching to same profile succeeds
- [ ] `eval "$(ccsw use <profile>)"` sets environment variable in current shell
- [ ] **No state file written** (state-free design)

#### US-3: Show Current Profile
**As a** developer,
**I want to** see which profile is currently active,
**So that** I can verify I'm using the correct configuration.

**Acceptance Criteria:**
- [ ] Command: `ccsw current`
- [ ] Output: Profile name if one is active
- [ ] Output: "No active profile" if none set
- [ ] Exit code 0 when profile is managed by ccsw
- [ ] Exit code 0 when no profile is set
- [ ] Exit code 3 when CLAUDE_CONFIG_DIR points to external (non-ccsw) directory
- [ ] Derives profile name from CLAUDE_CONFIG_DIR path in current environment
- [ ] **State-free**: Only checks `$CLAUDE_CONFIG_DIR` in current environment
- [ ] **No fallback**: Does not read state file (state-free design)
- [ ] **Validation**: If set path matches a known profile, shows profile name
- [ ] **Non-profile paths**: If CLAUDE_CONFIG_DIR points to non-ccsw directory:
  - Outputs warning to stderr: `WARNING: CLAUDE_CONFIG_DIR points to external directory: <path>`
  - Outputs to stdout: `External: <path>`
  - Returns exit code 3

#### US-4: Delete Profile
**As a** developer,
**I want to** delete an unused profile,
**So that** I can keep my profile list clean.

**Acceptance Criteria:**
- [ ] Command: `ccsw delete <profile>`
- [ ] Removes profile directory from `~/.config/ccsw/configs/<profile>/`
- [ ] Exit code 0 on successful deletion
- [ ] Exit code 1 if profile doesn't exist
- [ ] Exit code 2 if attempting to delete currently active profile
- [ ] Error to stderr if deleting active profile: `ERROR: Cannot delete active profile: <profile>`
- [ ] Error to stderr if profile not found: `ERROR: Profile not found: <profile>`
- [ ] Confirmation prompt NOT required (matches YAGNI principle)

### Non-Goals (Phase 1)
- Profile creation command (Phase 2)
- Network endpoint verification (Phase 3)
- Shell initialization snippet (bashrc/zshrc) (Phase 4)
- Tab completion for commands/profiles (Phase 5)
- Interactive profile switching (fuzzy matching, menus)
- Profile import/export functionality
- Profile backup/restore

---

## 3. Technical Specifications

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         User Shell                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        bin/ccsw                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Arg Parse  │──│ Command      │──│ Output       │       │
│  │              │  │ Dispatch     │  │ Generation   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
          │                             │
          ▼                             ▼
┌─────────────────┐     ┌─────────────────────────────────┐
│  lib/utils.sh   │     │         lib/core.sh             │
│  - Logging      │     │  - ccsw_list()                  │
│  - Validation   │     │  - ccsw_use()                   │
│  - Path utils   │     │  - ccsw_current()               │
└─────────────────┘     │  - ccsw_delete()                │
                        └─────────────────────────────────┘
                                        │
                                        ▼
                        ┌─────────────────────────────────┐
                        │        Filesystem Only          │
                        │  ~/.config/ccsw/configs/        │
                        │  (No state file - state-free)   │
                        └─────────────────────────────────┘
```

### Data Flow

#### Switching Profiles (`ccsw use`)
```
User executes: ccsw use work
    │
    ▼
Parse argument: profile="work"
    │
    ▼
Validate: ~/.config/ccsw/configs/work exists?
    │
    ├─ No → Error to stderr, exit 1
    │
    └─ Yes → Continue
        │
        ▼
Output to stdout: "export CLAUDE_CONFIG_DIR=/home/user/.config/ccsw/configs/work"
    │
    ▼
Exit 0
```

**Note**: No state file is written. The user must eval the output to set the environment variable:
```bash
eval "$(ccsw use work)"
```

#### Showing Current Profile (`ccsw current`)
```
User executes: ccsw current
    │
    ▼
Check CLAUDE_CONFIG_DIR in current environment
    │
    ├─ Not set?
    │   └─ Yes → Output "No active profile", exit 0
    │
    ├─ Is set and matches ccsw profile?
    │   └─ Yes → Output: "work" (profile name), exit 0
    │
    └─ Is set but external path?
        └─ Yes → Output: "External: <path>", WARNING to stderr, exit 3
```

**State-Free Design:**
- No state file is read or written
- `ccsw current` only reflects the current shell's environment
- In a new shell or shell without eval'd profile, shows "No active profile"
- Each shell maintains its own profile state via environment variable

**External Directory Handling:**
When `CLAUDE_CONFIG_DIR` is set to a non-ccsw directory (e.g., a project-specific config), the tool:
- Displays "External: <path>" to indicate it's outside ccsw management
- Emits a WARNING to stderr for visibility
- Returns exit code 3 to distinguish from normal operation
- This allows scripts to detect and handle external configurations appropriately

### Directory Structure

```
~/.config/ccsw/
└── configs/              # Profile directories (each = CLAUDE_CONFIG_DIR)
    ├── work/            # Profile: work
    │   └── settings.json # Claude Code config
    ├── personal/        # Profile: personal
    │   └── settings.json
    └── zai/             # Profile: zai
        └── settings.json
```

**Note**: No `state/` directory exists in the state-free design.

### State-Free Design Benefits

The decision to eliminate persistent state provides several advantages:

1. **Simplicity**: No state file management, cleanup, or migration logic
2. **Reliability**: Cannot get out of sync with actual environment; no stale state
3. **Isolation**: Each shell session maintains independent profile state
4. **Transparency**: `CLAUDE_CONFIG_DIR` is the single source of truth
5. **No Race Conditions**: Eliminates concurrent write issues between shells
6. **Easier Testing**: No need to mock or clean up state files in tests

**Trade-off**: `ccsw current` only shows the profile for the current shell session. In a new shell, it shows "No active profile" until a profile is loaded via `eval "$(ccsw use <profile>)"`.

### Project Directory Layout

```
claude-code-env-switcher/
├── bin/
│   └── ccsw              # Main CLI (executable)
├── lib/
│   ├── core.sh           # Core CRUD functions
│   └── utils.sh          # Utilities (logging, validation)
├── tests/
│   ├── test_core.bats    # Core function tests
│   └── test_utils.bats   # Utility tests
├── docs/
│   └── prds/
│       └── phase-01.md   # This document
├── .editorconfig         # Editor configuration
├── .shellcheckrc        # Shellcheck rules
├── .gitignore           # Git ignore patterns
├── LICENSE.md           # MIT License
├── README.md            # Project documentation
└── SPECIFICATION.md     # Full project spec
```

### Component Specifications

#### `bin/ccsw` - Main CLI
- **Responsibility**: Argument parsing, command dispatch, usage display
- **Dependencies**: lib/core.sh, lib/utils.sh
- **Strict Mode**: `set -Eeuo pipefail`
- **Shebang**: `#!/usr/bin/env bash`

#### `lib/core.sh` - Core Functions
- **Responsibility**: Profile CRUD operations
- **Functions**:
  - `ccsw_list()`: List profiles
  - `ccsw_use(profile)`: Switch profile
  - `ccsw_current()`: Show active profile
  - `ccsw_delete(profile)`: Delete profile

#### `lib/utils.sh` - Utilities
- **Responsibility**: Reusable helper functions
- **Functions**:
  - `log_info(msg)`, `log_warn(msg)`, `log_error(msg)`, `log_debug(msg)`
  - `validate_profile_name(name)`: Check a-zA-Z0-9_- only
  - `get_config_dir()`: Return `~/.config/ccsw`
  - `get_profile_dir(name)`: Return full profile path
  - `get_profile_name_from_path(path)`: Extract profile name from CLAUDE_CONFIG_DIR path
  - `ensure_config_dirs()`: Create directories if missing (state-free, only configs/)

### Integration Points

#### Claude Code CLI
- **Integration Method**: Environment variable `CLAUDE_CONFIG_DIR`
- **Expected Behavior**: Claude Code reads config from `$CLAUDE_CONFIG_DIR/settings.json`
- **Verification**: After `eval "$(ccsw use <profile>)`, running `claude --version` uses correct profile

#### Shell Environment (bash/zsh)
- **Integration Method**: eval of command output
- **Pattern**: `eval "$(ccsw use <profile>)"`
- **Persistence**: Not covered in Phase 1 (Phase 4)

### Security & Privacy

#### Data Handling
- **No Network Access**: Phase 1 is purely filesystem-based
- **No Credentials**: Tool manages config directories, not API keys directly
- **Permissions**: Config directories respect user umask (typically 0755)

#### Input Validation
- **Profile Names**: Must match regex `^[a-zA-Z0-9_-]+$`
  - Max length: 64 characters
  - Prevents path traversal: no `..`, `/`, `\`
- **Path Safety**: All paths quoted to prevent injection
- **No State File**: State-free design eliminates need for atomic writes

#### Error Handling
- **Fail Fast**: Validate inputs before filesystem operations
- **Clear Errors**: User-facing errors to stderr with `ERROR:` prefix
- **Exit Codes**:
  - 0: Success
  - 1: Generic error / profile not found
  - 2: Invalid operation (delete active profile)

---

## 4. Quality Assurance

### Testing Strategy

#### Unit Tests (bats-core)
- **Framework**: bats-core
- **Location**: `tests/`
- **Coverage Target**: ≥90% line coverage

**test_utils.bats:**
```bash
@test "log_info outputs to stderr" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INFO: test message" ]]
}

@test "validate_profile_name accepts valid names" {
    run validate_profile_name "work_profile-123"
    [ "$status" -eq 0 ]
}

@test "validate_profile_name rejects invalid names" {
    run validate_profile_name "invalid/name"
    [ "$status" -eq 1 ]
}
```

**test_core.bats:**
```bash
@test "ccsw_list lists profiles alphabetically" {
    mkdir -p "$CCSW_CONFIGS_DIR/zebra"
    mkdir -p "$CCSW_CONFIGS_DIR/apple"
    run ccsw_list
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "apple" ]
    [ "${lines[1]}" = "zebra" ]
}

@test "ccsw_use outputs export statement" {
    mkdir -p "$CCSW_CONFIGS_DIR/test_profile"
    run ccsw_use "test_profile"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "export CLAUDE_CONFIG_DIR=" ]]
}

@test "ccsw_delete prevents deleting active profile" {
    mkdir -p "$CCSW_CONFIGS_DIR/active"
    export CLAUDE_CONFIG_DIR="$CCSW_CONFIGS_DIR/active"
    run ccsw_delete "active"
    [ "$status" -eq 2 ]
    [[ "$output" =~ "Cannot delete active profile" ]]
}

@test "ccsw_current warns on external directory" {
    export CLAUDE_CONFIG_DIR="/some/external/path"
    run ccsw_current
    [ "$status" -eq 3 ]
    [[ "$output" =~ "External:" ]]
    [[ "$stderr" =~ "WARNING:" ]]
}

@test "ccsw_current shows no profile when not set" {
    unset CLAUDE_CONFIG_DIR
    run ccsw_current
    [ "$status" -eq 0 ]
    [ "$output" = "No active profile" ]
}
```

#### Integration Testing
- **Manual Test Plan**:
  1. Create 2 test profiles manually with `mkdir`
  2. Run `ccsw list` - verify both appear
  3. Run `eval "$(ccsw use profile1)"`
  4. Run `ccsw current` - verify shows "profile1"
  5. Run `echo $CLAUDE_CONFIG_DIR` - verify path correct
  6. Run `ccsw delete profile2` - verify directory removed
  7. Run `ccsw delete profile1` - verify error (active)
  8. Set `CLAUDE_CONFIG_DIR` to external path, run `ccsw current` - verify exit code 3 and warning
  9. Open new shell, run `ccsw current` - verify shows "No active profile" (state-free behavior)

#### Linting
- **Tool**: shellcheck
- **Configuration**: `.shellcheckrc`
- **Pass Criteria**: Zero errors, zero warnings

### Performance Requirements
- **List Command**: ≤100ms with 100 profiles
- **Use Command**: ≤50ms (filesystem write + path resolution)
- **Current Command**: ≤10ms (single file read)
- **Delete Command**: ≤50ms (directory removal)

---

## 5. Risks & Roadmap

### Technical Risks

#### Risk 1: Profile Directory Removal During Use
- **Description**: User deletes active profile directory externally
- **Impact**: Claude Code may fail to read config
- **Mitigation**: Prevent delete of active profile (already in spec)
- **Probability**: Low (user education)

#### Risk 2: Shell Incompatibility
- **Description**: Tool assumes bash-like shell
- **Impact**: Fails on fish, csh, etc.
- **Mitigation**: Document bash/zsh requirement clearly
- **Probability**: Medium (common for dev tools)

#### Risk 3: User Expectation Mismatch (State-Free)
- **Description**: Users may expect `ccsw current` to work across shells
- **Impact**: Confusion when new shell shows "No active profile"
- **Mitigation**: Clear documentation of state-free design; each shell has own state
- **Probability**: Medium (need good docs)

**Eliminated Risk**: No state file = no race conditions or state corruption issues

### Dependencies

#### Runtime Dependencies
- **Bash**: Version ≥4.0 (for associative arrays, though not used in Phase 1)
- **Coreutils**: `mkdir`, `rm`, `ls` (standard on Linux/macOS)

#### Development Dependencies
- **shellcheck**: ≥0.8.0
- **bats-core**: ≥1.9.0

### Phased Rollout

#### Phase 1 (Current Sprint) - Core CRUD
**Duration**: 1 week
**Deliverables**:
- [ ] Configuration files (.editorconfig, .shellcheckrc, .gitignore)
- [ ] lib/utils.sh with logging and validation
- [ ] lib/core.sh with CRUD operations
- [ ] bin/ccsw main CLI
- [ ] Unit tests (test_utils.bats, test_core.bats)
- [ ] All tests passing
- [ ] shellcheck passing

#### Phase 2 - Profile Creation
**Planned**: Following sprint
**Scope**: `ccsw create` command with interactive setup

#### Phase 3 - Endpoint Verification
**Planned**: Future sprint
**Scope**: `ccsw check` command with network inspection

#### Phase 4 - Shell Integration
**Planned**: Future sprint
**Scope**: bashrc/zshrc snippet for auto-load on shell start

#### Phase 5 - Tab Completion
**Planned**: Future sprint
**Scope**: Bash/Zsh completion scripts

### Definition of Done
A feature is complete when:
- [ ] Code follows bash-defensive-patterns skill guidelines
- [ ] shellcheck passes with zero issues
- [ ] Unit tests pass with ≥90% coverage
- [ ] Manual testing confirms functionality
- [ ] Documentation updated (README.md)
- [ ] **SPECIFICATION.md updated** with phase completion status and any deviations from this PRD
- [ ] Git commit message follows conventional commit format
- [ ] Code reviewed (if working in team)

---

## Appendix A: Command Reference

### ccsw list
```bash
ccsw list
```
**Description**: List all available profiles
**Output**: One profile per line, alphabetically sorted
**Exit Codes**: 0 (profiles exist), 1 (no profiles)

### ccsw use
```bash
ccsw use <profile>
eval "$(ccsw use <profile>)"
```
**Description**: Switch to specified profile
**Output**: `export CLAUDE_CONFIG_DIR=<path>`
**Exit Codes**: 0 (success), 1 (profile not found)

### ccsw current
```bash
ccsw current
```
**Description**: Show currently active profile
**Output**:
- Profile name (e.g., "work")
- "No active profile"
- "External: <path>" (if CLAUDE_CONFIG_DIR points to non-ccsw directory)
**Stderr**: WARNING message if external directory detected
**Exit Codes**:
- 0 (ccsw-managed profile or no profile)
- 3 (external/non-ccsw CLAUDE_CONFIG_DIR)

### ccsw delete
```bash
ccsw delete <profile>
```
**Description**: Delete specified profile
**Output**: None (success) or error message
**Exit Codes**: 0 (success), 1 (not found), 2 (active profile)

---

## Appendix B: Environment Variables

### CCSW_CONFIG_DIR
- **Default**: `~/.config/ccsw`
- **Purpose**: Base configuration directory
- **Override**: Optional, for testing

### CCSW_PROFILES_DIR
- **Default**: `$CCSW_CONFIG_DIR/configs`
- **Purpose**: Profile storage directory

### CCSW_STATE_DIR
- **Status**: **Not used** (state-free design)
- **Note**: State directory and files eliminated in favor of environment-only detection

### CLAUDE_CONFIG_DIR
- **Managed by**: User (via `eval "$(ccsw use <profile>)"`)
- **Purpose**: Points to active profile's config directory
- **Read by**: Claude Code CLI/VSCode extension
- **State Source**: This is the ONLY source of truth for current profile (state-free design)

---

## Appendix C: Exit Code Reference

| Code | Meaning                          | Command Context               |
|------|----------------------------------|-------------------------------|
| 0    | Success                          | All commands                  |
| 1    | Generic error / not found        | use, delete, list             |
| 2    | Invalid operation               | delete (active profile)       |
| 3    | External configuration          | current (non-ccsw CLAUDE_CONFIG_DIR) |
| 126  | Command not invoked              | Internal error                |
| 127  | Command not found               | ccsw not in PATH              |

---

**Document End**
