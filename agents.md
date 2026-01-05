# Agents and Automation Patterns

This document describes the agent patterns and automation approaches available in Rich's Fine Library for building automated workflows, CI/CD pipelines, and infrastructure management.

## Overview

The library provides several layers of automation:

1. **Shell-based Agents** - Bash scripts that perform automated tasks
2. **Make-based Automation** - Makefile targets for build and deployment
3. **GitHub Actions** - CI/CD workflow templates
4. **Pre-commit Hooks** - Automated code quality checks

## Shell-based Agent Patterns

### Remote Execution Agent

The `lib-remote.sh` library provides patterns for executing commands on remote systems:

```bash
source_lib lib-remote.sh

# Execute commands on remote hosts
# Copy directory structures to remote systems
# Manage remote file systems
```

### Cluster Management Agent

The `lib-cluster.sh` library enables managing groups of machines:

```bash
source_lib lib-cluster.sh

# Coordinate operations across multiple hosts
# Parallel command execution
# Cluster state management
```

### Docker Swarm Agent

The `lib-docker.sh` library provides Docker Swarm orchestration:

```bash
source_lib lib-docker.sh

# Create and manage Docker Swarm clusters
docker_machine_create_swarm remote false "consul://discovery"

# Architecture-aware deployment
arch=$(docker_architecture)  # intel, rpi1, rpi2, rpi3

# Container lifecycle management
docker_find_container myapp
docker_remove_container myapp
```

### Installation Agent

The `lib-install.sh` library automates software installation across platforms:

```bash
source_lib lib-install.sh

# Cross-platform package installation
package_install git vim docker

# Platform-specific installers
brew_install package    # macOS/Linux Homebrew
apt_install package     # Debian/Ubuntu
snap_install package    # Snap packages
pip_install package     # Python packages
npm_install package     # Node.js packages
```

### Configuration Agent

The `lib-config.sh` library automates system configuration:

```bash
source_lib lib-config.sh

# Profile configuration with idempotency
if ! config_mark "$HOME/.bashrc"; then
    config_add "$HOME/.bashrc" <<-'EOF'
        export PATH="$HOME/bin:$PATH"
        alias ll='ls -la'
EOF
fi

# Key-value configuration management
set_config_var "OPTION" "value" "/etc/app/config.conf"
```

## Make-based Automation

### Self-Documenting Targets

All Makefile includes use the `##` comment convention for documentation:

```makefile
.PHONY: build
build: ## Build the project
    @echo "Building..."

.PHONY: test
test: ## Run tests
    pytest
```

Run `make help` to see all available targets.

### Available Automation Targets

#### Base Automation (`include.mk`)

```bash
make help              # Show all targets with descriptions
make install-repo      # Initialize repository with templates
make pre-commit        # Run pre-commit hooks
make pre-commit-install # Install pre-commit hooks
make git-lfs           # Setup Git LFS
```

#### Python Automation (`include.python.mk`)

```bash
make python-install    # Install Python dependencies
make python-test       # Run Python tests
make python-lint       # Lint Python code
make python-format     # Format Python code
make python-build      # Build Python package
```

#### Docker Automation (`include.docker.mk`)

```bash
make docker-build      # Build Docker image
make docker-push       # Push to registry
make docker-run        # Run container
make docker-buildx     # Multi-architecture build
```

#### AI/ML Automation (`include.ai.mk`)

```bash
make ollama-install    # Install Ollama
make ollama-run        # Run Ollama server
make qdrant-install    # Install Qdrant vector DB
make qdrant-run        # Run Qdrant server
```

## GitHub Actions Workflows

### Available Workflow Templates

Located in `workflow.base/`:

| Workflow | Description |
|----------|-------------|
| `lint.workflow.yaml` | Code linting and style checks |
| `hugo.github.pages.workflow.yaml` | Static site deployment |
| `docker.workflow.yaml.disabled` | Docker image builds |
| `docker.buildx.workflow.yaml.disabled` | Multi-arch Docker builds |
| `mkdocs.workflow.yaml.disabled` | Documentation builds |

### Using Workflow Templates

1. Copy the template to `.github/workflows/`
2. Remove the `.disabled` suffix if present
3. Customize the workflow for your project

```bash
# Example: Enable linting workflow
cp workflow.base/lint.workflow.yaml .github/workflows/lint.yaml
```

### Workflow Pattern

```yaml
name: Lint
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v4
      - name: Install pre-commit
        run: pip install pre-commit
      - name: Run pre-commit
        run: pre-commit run --all-files
```

## Pre-commit Hook Automation

### Available Configurations

| Configuration | Description |
|---------------|-------------|
| `pre-commit-config.ruff.yaml` | Full Ruff linting suite |
| `pre-commit-config.black.yaml` | Black formatting |
| `pre-commit-config.python.yaml` | Python-specific checks |
| `pre-commit-config.jupyter.yaml` | Jupyter notebook checks |
| `pre-commit-config.template.yaml` | Starter template |

### Setup

```bash
# Install pre-commit
pip install pre-commit

# Copy configuration
cp pre-commit-config.ruff.yaml .pre-commit-config.yaml

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

### Common Hooks

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json

  - repo: https://github.com/astral-sh/ruff-pre-commit
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/shellcheck-py/shellcheck-py
    hooks:
      - id: shellcheck
```

## Agent Development Patterns

### Idempotency

All agents should be idempotent - safe to run multiple times:

```bash
# Bad: May fail on second run
mkdir /path/to/dir

# Good: Idempotent
mkdir -p /path/to/dir

# Bad: Duplicates entries
echo "export PATH=/new:$PATH" >> ~/.bashrc

# Good: Uses marker pattern
if ! config_mark ~/.bashrc; then
    config_add ~/.bashrc <<< 'export PATH=/new:$PATH'
fi
```

### Error Handling

Use proper error handling patterns:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_lib lib-debug.sh

# Check prerequisites
if ! is_command docker; then
    log_error 1 "Docker is required but not installed"
fi

# Graceful degradation
if ! docker_available; then
    log_warning "Docker not running, starting..."
    docker_start || log_error 2 "Failed to start Docker"
fi
```

### Logging

Use the logging functions from `lib-debug.sh`:

```bash
source_lib lib-debug.sh

log_verbose "Debug info (only with VERBOSE=true)"
log_warning "Warning message (always shown)"
log_error 1 "Fatal error (exits with code 1)"

# Conditional execution with logging
if $VERBOSE; then
    make build 2>&1 | tee build.log
else
    make build > /dev/null 2>&1
fi
```

### Cross-Platform Support

Design agents to work across platforms:

```bash
source_lib lib-util.sh
source_lib lib-install.sh

# Platform-aware installation
if in_os mac; then
    brew_install package
elif in_os linux; then
    if in_linux ubuntu; then
        apt_install package
    else
        snap_install package
    fi
fi

# Or use the universal installer
package_install package  # Tries all available package managers
```

## Building Custom Agents

### Agent Script Template

```bash
#!/usr/bin/env bash
##
## my-agent.sh - Description of what this agent does
## @author your-name
##

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTNAME="$(basename "$0")"

# Source libraries
# shellcheck source=include.sh
source "$SCRIPT_DIR/include.sh"
source_lib lib-debug.sh
source_lib lib-util.sh
source_lib lib-install.sh

# Parse arguments
VERBOSE=${VERBOSE:-false}
FORCE=${FORCE:-false}

while getopts "vfh" opt; do
    case $opt in
        v) VERBOSE=true ;;
        f) FORCE=true ;;
        h) echo "Usage: $SCRIPTNAME [-v] [-f] [-h]"; exit 0 ;;
        *) echo "Unknown option: $opt"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Main agent logic
main() {
    log_verbose "Starting agent..."

    # Check prerequisites
    log_assert "is_command git" "git is required"

    # Perform actions
    if $FORCE || ! some_check; then
        log_verbose "Performing action..."
        perform_action
    fi

    log_verbose "Agent completed successfully"
}

# Run main
main "$@"
```

### Registering with Make

Add your agent to the Makefile:

```makefile
.PHONY: my-agent
my-agent: ## Run my custom agent
    @./my-agent.sh $(if $(VERBOSE),-v) $(if $(FORCE),-f)
```

## Integration with AI Assistants

This library is designed to work well with AI assistants like Claude. See [claude.md](claude.md) for:

- Repository architecture overview
- Code style guidelines
- Common patterns and conventions
- Testing approaches

AI assistants can use these patterns to:
- Generate new shell scripts following library conventions
- Create Makefile targets with proper documentation
- Build GitHub Actions workflows
- Implement idempotent automation scripts
