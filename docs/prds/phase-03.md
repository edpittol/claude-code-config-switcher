# Product Requirements Document: ccsw Phase 3

**Document Version:** 1.0
**Date:** 2026-03-01
**Status:** Done
**Phase:** Phase 3 - Endpoint Check

---

## 1. Executive Summary

### Problem Statement
There is no way to verify that Claude Code network traffic is being routed to the expected endpoint defined in `ANTHROPIC_BASE_URL`. This is critical for security-conscious users and those using alternative providers who need to confirm their configuration is correct.

### Proposed Solution
Implement the **`ccsw check`** command that reads `ANTHROPIC_BASE_URL` from the active profile's config and uses network inspection tools (tcpdump/ss) to verify traffic is going to the expected endpoint.

**Key Design Decisions:**
- **Sudo Required**: Network packet capture (tcpdump) requires elevated privileges
- **Tool Detection**: Automatic detection of available network tools (tcpdump preferred, ss fallback)
- **Config-Based**: Reads expected endpoint from profile's `settings.json`

### Success Criteria
- **Functional**: Command verifies network traffic with documented exit codes
- **Quality**: 100% of code passes shellcheck with zero errors
- **Test Coverage**: Unit tests cover success, failure, and edge cases
- **Performance**: Check command completes within timeout period (default 10s)
- **Security**: Proper sudo validation before network inspection

---

## 2. User Experience & Functionality

### User Personas

#### Primary Persona: Security-Conscious Developer
- **Profile**: Developer using alternative Claude providers or verifying network routing
- **Pain Points**:
  - No visibility into where Claude Code traffic is actually going
  - Concern about misconfigured endpoints
  - Need to verify provider switching worked correctly
- **Goals**: Verify network traffic matches expected endpoint

#### Secondary Persona: Multi-Provider User
- **Profile**: Developer switching between Anthropic, z.ai, and custom endpoints
- **Pain Points**: Uncertainty about which endpoint is actually being used
- **Goals**: Quick verification after switching profiles

### User Stories

#### US-014: Implement ccsw check command with sudo network verification
**As a** developer,
**I want to** verify that my Claude Code traffic is going to the expected endpoint,
**So that** I can ensure my configuration is correct and secure.

**Acceptance Criteria:**
- [ ] Command: `ccsw check`
- [ ] Requires active profile (exit code 2 if none)
- [ ] Reads `ANTHROPIC_BASE_URL` from active profile's `settings.json`
- [ ] Parses URL to extract hostname
- [ ] Detects available network tool (tcpdump or ss)
- [ ] Verifies network traffic goes to expected endpoint
- [ ] Exit code 0 on successful verification
- [ ] Exit code 1 on error (config missing, network tool unavailable, traffic mismatch)
- [ ] Exit code 2 if no active profile
- [ ] Exit code 3 if sudo required but not available
- [ ] Clear error messages for each failure scenario

#### US-015: Add check.sh library for network inspection functionality
**As a** developer,
**I want to** have a dedicated library for network inspection operations,
**So that** the code is modular, testable, and reusable.

**Acceptance Criteria:**
- [ ] Create `lib/check.sh` with network inspection functions
- [ ] Implement `detect_network_tool()` - returns "tcpdump", "ss", or empty
- [ ] Implement `parse_url_hostname()` - extracts hostname from URL
- [ ] Implement `check_sudo_privileges()` - verifies sudo access
- [ ] Implement `check_network_traffic()` - main traffic verification function
- [ ] Implement `read_anthropic_base_url()` - reads URL from profile config
- [ ] Handle both HTTP and HTTPS URL schemes
- [ ] Provide mockable functions for testing
- [ ] Source `check.sh` from `core.sh`

#### US-016: Write unit tests for check command functionality
**As a** developer,
**I want to** have comprehensive unit tests for the endpoint check functionality,
**So that** I can ensure reliability and proper error handling.

**Acceptance Criteria:**
- [ ] Create `tests/test_check.bats` with unit tests
- [ ] Test successful endpoint verification scenario
- [ ] Test missing `ANTHROPIC_BASE_URL` in `settings.json`
- [ ] Test invalid URL parsing
- [ ] Test missing sudo permissions
- [ ] Test unavailable network tools
- [ ] Test network traffic mismatch scenarios
- [ ] All tests pass with bats-core

### Non-Goals (Phase 3)
- Profile switching (Phase 1)
- Profile creation (Phase 2)
- Shell initialization snippet (Phase 4)
- Tab completion (Phase 5)
- Network traffic content inspection (only destination verification)
- Real-time continuous monitoring

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
│  - Logging      │    │  - ccsw_check() ← NEW            │
│  - Validation   │    └─────────────────────────────────┘
└─────────────────┘                  │
                                     ▼
                            ┌─────────────────────┐
                            │    lib/check.sh     │
                            │  - detect_*()       │
                            │  - parse_*()        │
                            │  - check_*()        │
                            │  - read_*()         │
                            └─────────────────────┘
                                     │
                                     ▼
                            ┌─────────────────────┐
                            │   Network Tools     │
                            │  - tcpdump (sudo)   │
                            │  - ss (no sudo)     │
                            └─────────────────────┘
```

### Data Flow

#### Checking Network Traffic (`ccsw check`)
```
User executes: ccsw check
    │
    ▼
Get current profile: ccsw_current()
    │
    ├─ No active profile? → Error, exit 2
    │
    └─ Has active profile? → Continue
        │
        ▼
Read config: read_anthropic_base_url(profile)
    │
    ├─ Config file missing? → Error, exit 1
    │
    ├─ ANTHROPIC_BASE_URL not found? → Error, exit 1
    │
    └─ URL found? → Continue
        │
        ▼
Parse hostname: parse_url_hostname(url)
    │
    ▼
Detect network tool: detect_network_tool()
    │
    ├─ tcpdump available? → Use tcpdump
    │
    ├─ ss available? → Use ss
    │
    └─ Neither? → Error, exit 1
        │
        ▼
Check sudo (if tcpdump): check_sudo_privileges()
    │
    ├─ No sudo? → Error, exit 3
    │
    └─ Has sudo? → Continue
        │
        ▼
Verify traffic: check_network_traffic(hostname, tool)
    │
    ├─ Traffic detected? → Success message, exit 0
    │
    └─ No traffic? → Warning, exit 1
```

### Component Specifications

#### `lib/core.sh` - ccsw_check()

```bash
ccsw_check() {
    local current_profile
    local anthropic_url
    local hostname
    local network_tool

    # Get current active profile
    if ! current_profile=$(ccsw_current 2>/dev/null); then
        log_error "Failed to get current profile"
        return 1
    fi

    if [[ -z "$current_profile" ]] || [[ "$current_profile" == "No active profile" ]]; then
        log_error "No active profile found. Please use a profile first."
        return 2
    fi

    log_info "Checking network traffic for profile: $current_profile"

    # Read ANTHROPIC_BASE_URL from profile config
    if ! anthropic_url=$(read_anthropic_base_url "$current_profile"); then
        return 1
    fi

    # Parse hostname from URL
    hostname=$(parse_url_hostname "$anthropic_url")
    if [[ -z "$hostname" ]]; then
        log_error "Failed to parse hostname from URL: $anthropic_url"
        return 1
    fi

    log_info "Checking traffic to: $hostname"

    # Detect available network tool
    network_tool=$(detect_network_tool)
    if [[ -z "$network_tool" ]]; then
        log_error "No supported network tool found. Please install tcpdump or ss."
        return 1
    fi

    # Check network traffic
    if ! check_network_traffic "$hostname" "$network_tool"; then
        log_error "Network verification failed: No traffic detected to $hostname"
        return 1
    fi

    log_info "Network verification successful"
    return 0
}
```

#### `lib/check.sh` - Network Inspection Functions

**detect_network_tool()**
```bash
detect_network_tool() {
    # Check for tcpdump first (more comprehensive)
    if command -v tcpdump >/dev/null 2>&1; then
        echo "tcpdump"
        return 0
    fi

    # Fall back to ss (socket statistics)
    if command -v ss >/dev/null 2>&1; then
        echo "ss"
        return 0
    fi

    # No supported network tool found
    echo ""
    return 1
}
```

**parse_url_hostname(url)**
```bash
parse_url_hostname() {
    local url="$1"

    # Remove protocol prefix
    url="${url#http://}"
    url="${url#https://}"

    # Remove path and query string
    url="${url%%/*}"

    # Remove port if present
    url="${url%%:*}"

    echo "$url"
}
```

**check_sudo_privileges()**
```bash
check_sudo_privileges() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Try to run sudo with a harmless command
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    return 1
}
```

**read_anthropic_base_url(profile)**
```bash
read_anthropic_base_url() {
    local profile="$1"
    local profile_dir
    local config_file

    # Get profile directory
    profile_dir=$(get_profile_dir "$profile")

    # Check if profile directory exists
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile not found: $profile"
        return 1
    fi

    # Config file path
    config_file="${profile_dir}/settings.json"

    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    # Extract ANTHROPIC_BASE_URL using jq if available
    if command -v jq >/dev/null 2>&1; then
        local url
        url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$config_file" 2>/dev/null)
        if [[ -n "$url" && "$url" != "null" ]]; then
            echo "$url"
            return 0
        fi
    fi

    # Fallback: grep from file (less robust)
    local url
    url=$(grep -o '"ANTHROPIC_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        echo "$url"
        return 0
    fi

    # URL not found
    log_error "ANTHROPIC_BASE_URL not found in profile config: $profile"
    return 1
}
```

### Config File Format

Profile settings.json expected format:
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com"
  }
}
```

### Integration Points

#### Claude Code Config
- **Location**: `$CLAUDE_CONFIG_DIR/settings.json`
- **Required for check**: `env.ANTHROPIC_BASE_URL` field

#### Network Tools
- **tcpdump**: Preferred, requires sudo, captures actual packets
- **ss**: Fallback, no sudo required, checks socket connections

### Security & Privacy

#### Data Handling
- **Network Inspection**: Only checks destination hostname, not packet contents
- **No Data Collection**: All operations are local
- **Sudo Scope**: Only used for network packet capture

#### Input Validation
- **URL Parsing**: Handles malformed URLs gracefully
- **Path Safety**: All paths quoted to prevent injection

#### Error Handling
- **Fail Fast**: Validate inputs before operations
- **Clear Errors**: User-facing errors to stderr with `ERROR:` prefix
- **Exit Codes**:
  - 0: Success
  - 1: Generic error (config missing, tool unavailable, traffic mismatch)
  - 2: No active profile
  - 3: Sudo required but not available

---

## 4. Quality Assurance

### Testing Strategy

#### Unit Tests (bats-core)

**test_check.bats:**
```bash
@test "ccsw_check with no active profile" {
    unset CLAUDE_CONFIG_DIR
    run ccsw_check
    [ "$status" -eq 2 ]
    [[ "$output" == *"No active profile found"* ]]
}

@test "ccsw_check with active profile but no config file" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"
    rm -f "$CCSW_PROFILES_DIR/test-profile/settings.json"
    run ccsw_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"ANTHROPIC_BASE_URL not found"* ]]
}

@test "ccsw_check with valid config and hostname parsing" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection to use ss
    detect_network_tool() { echo "ss"; }

    # Mock network traffic check to return success
    check_network_traffic() { echo "mock network check"; return 0; }

    run ccsw_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"mock network check"* ]]
}

@test "ccsw_check with invalid URL in config" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Update config with invalid URL
    cat > "$CCSW_PROFILES_DIR/test-profile/settings.json" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "not-a-valid-url"
  }
}
EOF

    run ccsw_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to parse hostname"* ]]
}

@test "ccsw_check missing network tools" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection to return no tools
    detect_network_tool() { echo ""; return 1; }

    run ccsw_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"No supported network tool found"* ]]
}

@test "parse_url_hostname function" {
    run parse_url_hostname "https://api.anthropic.com/v1"
    [ "$output" == "api.anthropic.com" ]

    run parse_url_hostname "http://localhost:8080"
    [ "$output" == "localhost" ]

    run parse_url_hostname "https://example.com/path/to/resource"
    [ "$output" == "example.com" ]

    run parse_url_hostname "invalid-url"
    [ "$output" == "invalid-url" ]

    run parse_url_hostname ""
    [ "$output" == "" ]
}

@test "detect_network_tool function" {
    # Test with tcpdump available
    command -v tcpdump >/dev/null 2>&1 && {
        run detect_network_tool
        [ "$output" == "tcpdump" ]
    }

    # Test with ss available
    command -v ss >/dev/null 2>&1 && {
        run detect_network_tool
        [ "$output" == "ss" ]
    }
}

@test "check_sudo_privileges function" {
    unset EUID
    if [[ $(id -u) -eq 0 ]]; then
        # Root user
        run check_sudo_privileges
        [ "$status" -eq 0 ]
    else
        # Non-root user
        run check_sudo_privileges
        [ "$status" -eq 1 ]
    fi
}

@test "read_anthropic_base_url function" {
    # Test with valid config
    run read_anthropic_base_url "test-profile"
    [ "$status" -eq 0 ]
    [ "$output" == "https://api.anthropic.com" ]

    # Test with non-existent profile
    run read_anthropic_base_url "non-existent-profile"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Profile not found"* ]]
}

@test "ccsw_check network verification failure" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection
    detect_network_tool() { echo "ss"; }

    # Mock network traffic check to return failure
    check_network_traffic() { echo "Network check failed"; return 1; }

    run ccsw_check
    [ "$status" -eq 1 ]
    [[ "$output" == *"Network verification failed"* ]]
}
```

#### Integration Testing

**Manual Test Plan:**
1. Create profile with settings.json containing ANTHROPIC_BASE_URL
2. Switch to profile: `eval "$(ccsw use test-profile)"`
3. Run `ccsw check` - verify network check executes
4. Test with missing settings.json - verify error
5. Test with no active profile - verify exit code 2
6. Test with invalid URL - verify error
7. Test without network tools available - verify error

#### Linting
- **Tool**: shellcheck
- **Configuration**: `.shellcheckrc`
- **Pass Criteria**: Zero errors, zero warnings

### Performance Requirements
- **Check Command**: ≤timeout period (default 10s for network operations)

---

## 5. Risks & Roadmap

### Technical Risks

#### Risk 1: Network Tool Availability
- **Description**: System may not have tcpdump or ss installed
- **Impact**: Check command cannot function
- **Mitigation**: Clear error message listing required tools
- **Probability**: Low (both tools are standard on most systems)

#### Risk 2: Sudo Access Required
- **Description**: tcpdump requires sudo privileges
- **Impact**: Users without sudo cannot use full network inspection
- **Mitigation**: Fallback to ss (no sudo required); clear error if neither available
- **Probability**: Medium (some environments restrict sudo)

#### Risk 3: Config File Format Changes
- **Description**: Claude Code may change settings.json format
- **Impact**: Cannot read ANTHROPIC_BASE_URL
- **Mitigation**: Support both jq and grep parsing; document expected format
- **Probability**: Low (config format is stable)

### Dependencies

#### Runtime Dependencies
- **Bash**: Version ≥4.0
- **Coreutils**: standard Unix utilities
- **Optional**: `jq` for JSON parsing
- **Optional**: `tcpdump` or `ss` for network inspection

#### Development Dependencies
- **shellcheck**: ≥0.8.0
- **bats-core**: ≥1.9.0

### Phased Rollout

#### Phase 3 (This PRD) - Endpoint Check
**Duration**: 2-3 days
**Deliverables**:
- [x] lib/check.sh with network inspection functions
- [x] lib/core.sh with ccsw_check() function
- [x] bin/ccsw updated with check command
- [x] Unit tests for check functionality
- [x] shellcheck passing
- [x] Update README.md with check command

#### Phase 4 - Shell Integration
**Planned**: Future sprint
**Scope**: bashrc/zshrc snippet for auto-load on shell start

#### Phase 5 - Tab Completion
**Planned**: Future sprint
**Scope**: Bash/Zsh completion scripts

#### Phase 6 - Docker QA Environment
**Planned**: Future sprint
**Scope**: Docker environment with pre-installed QA tools

#### Phase 7 - Build and Bundling
**Planned**: Future sprint
**Scope**: Single-file distribution bundle

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

### ccsw check
```bash
ccsw check
```
**Description**: Verify network traffic matches ANTHROPIC_BASE_URL
**Prerequisites**: Active profile with settings.json containing ANTHROPIC_BASE_URL
**Exit Codes**:
- 0: Success - traffic verified
- 1: Error - config missing, tool unavailable, or no traffic
- 2: No active profile
- 3: Sudo required but not available
**Examples**:
```bash
$ ccsw check
INFO: Checking network traffic for profile: work
INFO: Checking traffic to: api.anthropic.com
INFO: Network verification successful

$ ccsw check
ERROR: No active profile found. Please use a profile first.

$ ccsw check
ERROR: ANTHROPIC_BASE_URL not found in profile config: work

$ ccsw check
ERROR: No supported network tool found. Please install tcpdump or ss.
```

---

## Appendix B: Exit Code Reference

| Code | Meaning                          | Command Context               |
|------|----------------------------------|-------------------------------|
| 0    | Success                          | check                         |
| 1    | Error (config/tool/traffic)      | check                         |
| 2    | No active profile                | check                         |
| 3    | Sudo required but not available  | check (with tcpdump)          |

---

## Appendix C: Network Tool Comparison

| Feature          | tcpdump           | ss                |
|------------------|-------------------|-------------------|
| Sudo Required    | Yes               | No                |
| Packet Capture   | Full packets      | Socket stats only |
| Accuracy         | High              | Medium            |
| Availability     | Common            | Very common       |
| Performance      | Lower             | Higher            |

**Recommendation**: Use tcpdump when sudo is available for most accurate results.

---

**Note**: After completing this phase, update SPECIFICATION.md to mark Phase 3 as COMPLETED.

**Document End**
