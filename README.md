# ccsw - Claude Config Switcher

A state-free Bash CLI tool for managing multiple Claude Code configurations.

## Installation

### Requirements
- Bash ≥ 4.0
- coreutils (standard Unix utilities)

### Setup
1. Clone or download the ccsw project
2. Place the `bin/ccsw` executable in your PATH:
   ```bash
   # Copy to a directory in your PATH
   cp ccsw/bin/ccsw /usr/local/bin/

   # Or make it executable and add to PATH
   chmod +x ccsw/bin/ccsw
   export PATH="$PATH:/path/to/ccsw/bin"
   ```

## Usage

### Commands

#### `ccsw list`
List all available profiles sorted alphabetically.

```bash
$ ccsw list
profile1
profile2
my-profile
work-config
```

#### `ccsw use <profile>`
Switch to a profile by outputting an export statement for eval.

```bash
$ ccsw use my-profile
export CLAUDE_CONFIG_DIR=/home/user/.config/ccsw/configs/my-profile

# Use with eval to switch profiles
$ eval "$(ccsw use my-profile)"
$ ccsw current
my-profile
```

#### `ccsw current`
Show the currently active profile from `CLAUDE_CONFIG_DIR`.

```bash
$ ccsw current
my-profile

# When no profile is active
$ ccsw current
No active profile

# When CLAUDE_CONFIG_DIR points to external directory
$ ccsw current
External: /path/to/external/directory
WARN: CLAUDE_CONFIG_DIR points to external directory: /path/to/external/directory
```

#### `ccsw delete <profile>`
Delete a profile directory with safety guards.

```bash
$ ccsw delete old-profile
$ ccsw delete my-profile
ERROR: Cannot delete active profile: my-profile
```

### Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success |
| 1 | Profile not found or general error |
| 2 | Cannot delete active profile (safety guard) |
| 3 | CLAUDE_CONFIG_DIR points to external directory |

## Environment Variables

- `CLAUDE_CONFIG_DIR`: Set automatically when using `ccsw use`
- `CCSW_CONFIG_DIR`: Override default config directory (default: `~/.config/ccsw`)
- `CCSW_PROFILES_DIR`: Override default profiles directory (default: `$CCSW_CONFIG_DIR/configs`)

## State-Free Design

ccsw is designed to be state-free - it doesn't write any configuration files. Instead, it outputs environment variables that you can use with `eval`:

```bash
# Switch to a profile
$ eval "$(ccsw use work)"
$ echo $CLAUDE_CONFIG_DIR
/home/user/.config/ccsw/configs/work

# The profile switch only affects the current shell session
$ # Open a new terminal
$ ccsw current
No active profile
```

This makes ccsw safe to use and ensures that profile changes don't persist accidentally.

## Examples

### Basic Usage
```bash
# List all profiles
ccsw list

# Switch to work profile
eval "$(ccsw use work)"

# Check current profile
ccsw current

# Switch back to personal profile
eval "$(ccsw use personal)"
```

### Shell Integration
Add this to your `.bashrc` or `.zshrc` for easy profile switching:

```bash
# Function to switch to a profile
ccsw() {
    /path/to/ccsw/bin/ccsw "$@"
}

# Quick profile switch
alias cwork='eval "$(ccsw use work)"'
alias cpersonal='eval "$(ccsw use personal)"'
```

### Script Usage
```bash
#!/bin/bash
# Switch to test profile for running tests
eval "$(ccsw use test)"
./run-tests

# Switch back to default
eval "$(ccsw use default)"
```

## Troubleshooting

### Profile Not Found
```bash
$ ccsw use nonexistent
ERROR: Profile not found: nonexistent
```
- Check the profile name with `ccsw list`
- Ensure the profile directory exists in `~/.config/ccsw/configs/`

### Cannot Delete Active Profile
```bash
$ ccsw delete current-profile
ERROR: Cannot delete active profile: current-profile
```
- Switch to a different profile first: `eval "$(ccsw use other-profile)"`
- Or unset the environment variable: `unset CLAUDE_CONFIG_DIR`

### External Directory Warning
```bash
$ ccsw current
External: /some/other/path
WARN: CLAUDE_CONFIG_DIR points to external directory: /some/other/path
```
- This warning appears when `CLAUDE_CONFIG_DIR` is set but doesn't point to a ccsw-managed profile
- Use `unset CLAUDE_CONFIG_DIR` to clear the current profile

### Performance
All commands execute within 100ms on modern systems. Profile operations are instantaneous as no file I/O is performed.

## Project Structure

```
ccsw/
├── bin/ccsw          # Main CLI executable
├── lib/
│   ├── utils.sh      # Utility functions
│   └── core.sh       # Core CRUD functions
├── tests/            # Unit tests
└── README.md         # This file
```

## Contributing

1. Follow the bash-defensive-patterns guidelines
2. All scripts must pass shellcheck with zero errors
3. Maintain state-free design principles
4. Add appropriate error handling and exit codes

## QA

### Unit Tests (Bats)

The project uses [Bats](https://bats-core.readthedocs.io/) (Bash Automated Testing System) for unit testing.

#### Prerequisites
```bash
# Install Bats (Ubuntu/Debian)
sudo apt install bats

# Or via GitHub
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

#### Running Tests

```bash
# Run all unit tests
bats tests/

# Run specific test file
bats tests/test_core.bats
bats tests/test_utils.bats

# Run with verbose output
bats -p tests/

# Run specific test by name
bats -f "ccsw_list" tests/
```

### Integration Tests

Manual integration testing scripts are available in the `scripts/` directory:

```bash
# Run simple integration tests
./scripts/integration_test_simple.sh

# Run manual integration tests
./scripts/manual_integration_test.sh

# Run full integration test suite
./scripts/test_integration.sh
```

### Shellcheck

All shell scripts should pass shellcheck with zero errors:

```bash
# Check all shell scripts
shellcheck bin/ccsw lib/*.sh scripts/*.sh

# Check specific file
shellcheck bin/ccsw
```

### EditorConfig

Verify that all files conform to the EditorConfig settings:

```bash
# Install editorconfig-checker (if not already installed)
go install github.com/editorconfig-checker/editorconfig-checker/cmd/editorconfig-checker@latest

# Or via npm
npm install -g editorconfig-checker

# Check all files
editorconfig-checker

# Check specific directory
editorconfig-checker bin/

# Check specific file
editorconfig-checker bin/ccsw
```

### Manual Testing

For quick manual verification of state-free behavior:

```bash
# Create isolated test environment
(
  export CCSW_CONFIG_DIR=$(mktemp -d)
  export CCSW_PROFILES_DIR="$CCSW_CONFIG_DIR/configs"
  mkdir -p "$CCSW_PROFILES_DIR"

  # Create test profile
  mkdir -p "$CCSW_PROFILES_DIR/test"

  # Test switching (requires subshell for isolation)
  eval "$(bin/ccsw use test)" && echo "Active: $(bin/ccsw current)"

  # Cleanup happens automatically when subshell exits
)
```
