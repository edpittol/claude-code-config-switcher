# Product Requirements Document: ccsw Phase 2

**Document Version:** 1.0
**Date:** 2026-03-01
**Status:** Done
**Phase:** Phase 2 - Interactive Creator

---

## 1. Executive Summary

### Problem Statement
Users cannot create new profiles through the CLI - they must manually create directories using `mkdir -p ~/.config/ccsw/configs/<profile>/`. This is error-prone and requires remembering the exact directory structure.

### Proposed Solution
Implement the **`ccsw create`** command that creates profile directories under `~/.config/ccsw/configs/<profile>/` and outputs the path for programmatic use.

**Key Design Decisions:**
- **State-Free Maintained**: The create command does not switch to the new profile automatically
- **Output Path**: Returns the full path on stdout for scripting use
- **Parent Creation**: Automatically creates parent directories if needed

### Success Criteria
- **Functional**: Command creates directory and outputs path with exit code 0
- **Quality**: 100% of code passes shellcheck with zero errors
- **Test Coverage**: Unit tests cover success, duplicate, invalid name, and parent creation scenarios
- **Performance**: Create command executes within 100ms

---

## 2. User Experience & Functionality

### User Personas

#### Primary Persona: Developer Creating New Profiles
- **Profile**: Developer setting up a new Claude Code configuration
- **Pain Points**:
  - Must remember the exact directory structure
  - Manual `mkdir -p` commands are error-prone
  - No feedback on successful creation
- **Goals**: Quick profile creation with clear confirmation

### User Stories

#### US-013: Create Profile Directory
**As a** developer,
**I want to** create a new profile with a single command,
**So that** I can quickly set up new configurations without manual directory creation.

**Acceptance Criteria:**
- [ ] Command: `ccsw create <profile>`
- [ ] Creates directory at `~/.config/ccsw/configs/<profile>/`
- [ ] Outputs the full path on success
- [ ] Exit code 0 on successful creation
- [ ] Exit code 1 if profile already exists
- [ ] Exit code 1 if profile name is invalid
- [ ] Creates parent directories if they don't exist
- [ ] Validates profile name with regex `^[a-zA-Z0-9_-]{1,64}$`
- [ ] Error message to stderr: `ERROR: Profile already exists: <profile>`
- [ ] Error message to stderr: `ERROR: Invalid profile name: <profile>`
- [ ] **State-free**: Does not switch to the new profile automatically

### Non-Goals (Phase 2)
- Profile switching (Phase 1)
- Network endpoint verification (Phase 3)
- Shell initialization snippet (Phase 4)
- Tab completion (Phase 5)
- Interactive profile creation wizard
- Profile templates

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
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Arg Parse  │──│ Command      │──│ Output       │      │
│  │              │  │ Dispatch     │  │ Generation   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
          │                        │
          ▼                        ▼
┌─────────────────┐    ┌─────────────────────────────────┐
│  lib/utils.sh   │    │         lib/core.sh              │
│  - Logging      │    │  - ccsw_list()                   │
│  - Validation   │    │  - ccsw_use()                    │
│  - Path utils   │    │  - ccsw_current()                │
└─────────────────┘    │  - ccsw_delete()                 │
                        │  - ccsw_create() ← NEW           │
                        └─────────────────────────────────┘
                                      │
                                      ▼
                        ┌─────────────────────────────────┐
                        │        Filesystem               │
                        │  ~/.config/ccsw/configs/        │
                        └─────────────────────────────────┘
```

### Data Flow

#### Creating a Profile (`ccsw create`)
```
User executes: ccsw create new-profile
    │
    ▼
Parse argument: profile="new-profile"
    │
    ▼
Validate: Name matches ^[a-zA-Z0-9_-]{1,64}$?
    │
    ├─ No → Error to stderr, exit 1
    │
    └─ Yes → Continue
        │
        ▼
Check: Profile already exists?
    │
    ├─ Yes → Error to stderr, exit 1
    │
    └─ No → Continue
        │
        ▼
Create: ensure_config_dirs() if needed
        │
        ▼
Create: mkdir -p ~/.config/ccsw/configs/new-profile
        │
        ▼
Output to stdout: "/home/user/.config/ccsw/configs/new-profile"
        │
        ▼
Exit 0
```

### Component Specifications

#### `lib/core.sh` - ccsw_create(profile)

```bash
ccsw_create() {
    local profile="$1"
    local profile_dir
    local profiles_dir

    # Validate profile name
    if ! validate_profile_name "$profile"; then
        log_error "Invalid profile name: $profile"
        return 1
    fi

    # Get directories
    profiles_dir=$(get_profiles_dir)
    profile_dir=$(get_profile_dir "$profile")

    # Check if profile already exists
    if [[ -d "$profile_dir" ]]; then
        log_error "Profile already exists: $profile"
        return 1
    fi

    # Create profiles directory if it doesn't exist
    if ! ensure_config_dirs; then
        log_error "Failed to create profiles directory"
        return 1
    fi

    # Create profile directory with proper permissions
    if ! mkdir -p "$profile_dir"; then
        log_error "Failed to create profile directory: $profile"
        return 1
    fi

    # Output the path for eval usage
    echo "$profile_dir"
    return 0
}
```

- **Responsibility**: Create new profile directory
- **Input**: Profile name (string)
- **Output**: Full path to created directory (stdout)
- **Exit Codes**: 0 (success), 1 (invalid name/already exists)
- **Side Effects**: Creates directory on filesystem

### Security & Privacy

#### Input Validation
- **Profile Names**: Same strict regex as Phase 1: `^[a-zA-Z0-9_-]{1,64}$`
- **Path Safety**: All paths quoted to prevent injection

#### Error Handling
- **Fail Fast**: Validate inputs before filesystem operations
- **Clear Errors**: User-facing errors to stderr with `ERROR:` prefix
- **Exit Codes**:
  - 0: Success
  - 1: Invalid name or profile already exists

---

## 4. Quality Assurance

### Testing Strategy

#### Unit Tests (bats-core)

**test_core.bats (Create tests):**
```bash
@test "ccsw_create creates profile directory and outputs path" {
    local new_profile="test-new-profile"
    local expected_path="$CCSW_PROFILES_DIR/$new_profile"

    # Verify profile doesn't exist before creation
    [ ! -d "$expected_path" ]

    run ccsw_create "$new_profile"
    [ "$status" -eq 0 ]
    [ "$output" == "$expected_path" ]
    [ -d "$expected_path" ]
}

@test "ccsw_create returns exit code 1 for invalid profile name" {
    run ccsw_create "@invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Invalid profile name: @invalid" ]]
}

@test "ccsw_create returns exit code 1 for existing profile" {
    run ccsw_create "profile1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Profile already exists: profile1" ]]
}

@test "ccsw_create creates profiles directory if it doesn't exist" {
    # Remove profiles directory
    rm -rf "$CCSW_PROFILES_DIR"

    # Verify profiles directory doesn't exist
    [ ! -d "$CCSW_PROFILES_DIR" ]

    local new_profile="test-new-profile"
    local expected_path="$CCSW_PROFILES_DIR/$new_profile"

    run ccsw_create "$new_profile"
    [ "$status" -eq 0 ]
    [ "$output" == "$expected_path" ]
    [ -d "$expected_path" ]
    [ -d "$CCSW_PROFILES_DIR" ]
}
```

#### Integration Testing

**Manual Test Plan:**
1. Run `ccsw create test-profile` - verify directory created and path output
2. Run `ccsw create test-profile` again - verify error (already exists)
3. Run `ccsw create @invalid` - verify error (invalid name)
4. Remove profiles directory, run `ccsw create new` - verify parent creation
5. Verify created directory is empty (no files inside)

#### Linting
- **Tool**: shellcheck
- **Configuration**: `.shellcheckrc`
- **Pass Criteria**: Zero errors, zero warnings

### Performance Requirements
- **Create Command**: ≤100ms (directory creation only)

---

## 5. Risks & Roadmap

### Technical Risks

#### Risk 1: Directory Permission Issues
- **Description**: User may not have write permissions to ~/.config/ccsw/
- **Impact**: Cannot create profiles
- **Mitigation**: Clear error message from mkdir failure
- **Probability**: Low (standard user permissions)

#### Risk 2: Existing Directory Conflicts
- **Description**: Directory exists but isn't a valid profile
- **Impact**: Cannot create profile with that name
- **Mitigation**: Check for directory existence before creation
- **Probability**: Low

### Dependencies

#### Runtime Dependencies
- **Bash**: Version ≥4.0
- **Coreutils**: `mkdir` (standard)

#### Development Dependencies
- **shellcheck**: ≥0.8.0
- **bats-core**: ≥1.9.0

### Phased Rollout

#### Phase 2 (This PRD) - Create Command
**Duration**: 1-2 days
**Deliverables**:
- [x] lib/core.sh with ccsw_create() function
- [x] bin/ccsw updated with create command
- [x] Unit tests for create functionality
- [x] shellcheck passing
- [x] Update README.md with create command

#### Phase 3 - Endpoint Check
**Planned**: Following sprint
**Scope**: `ccsw check` command with network inspection

#### Phase 4 - Shell Integration
**Planned**: Future sprint
**Scope**: bashrc/zshrc snippet for auto-load on shell start

#### Phase 5 - Tab Completion
**Planned**: Future sprint
**Scope**: Bash/Zsh completion scripts

### Definition of Done
A feature is complete when:
- [x] Code follows bash-defensive-patterns skill guidelines
- [x] shellcheck passes with zero issues
- [x] Unit tests pass
- [x] Manual testing confirms functionality
- [x] Documentation updated (README.md)
- [x] **SPECIFICATION.md updated** with phase completion status
- [x] Git commit message follows conventional commit format

---

## Appendix A: Command Reference

### ccsw create
```bash
ccsw create <profile>
```
**Description**: Create a new profile directory
**Output**: Full path to created directory
**Exit Codes**: 0 (success), 1 (invalid name/already exists)
**Examples**:
```bash
$ ccsw create my-new-profile
/home/user/.config/ccsw/configs/my-new-profile

$ ccsw create my-new-profile
ERROR: Profile already exists: my-new-profile

$ ccsw create "@invalid"
ERROR: Invalid profile name: @invalid
```

---

## Appendix B: Exit Code Reference

| Code | Meaning                          | Command Context               |
|------|----------------------------------|-------------------------------|
| 0    | Success                          | create                        |
| 1    | Invalid name / already exists    | create                        |

---

**Note**: After completing this phase, update SPECIFICATION.md to mark Phase 2 as COMPLETED.

**Document End**
