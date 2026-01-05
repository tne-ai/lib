# Claude AI Guidelines for Rich's Fine Library

This document provides guidelines for AI assistants (like Claude) when working with this repository.

## Repository Overview

This is **Rich's Fine Library** - a comprehensive, production-grade utility library providing:

- Reusable shell/bash functions for system configuration, Docker, networking, installation, and cloud operations
- Make-based build system templates for project bootstrapping
- Cross-platform support (macOS, Linux, WSL, Raspberry Pi clusters)
- Documentation tooling with mkdocs integration
- Pre-commit hooks and GitHub Actions CI/CD

## Key Architecture Patterns

### Library Sourcing Pattern

All shell libraries use a guard pattern to prevent multiple sourcing:

```bash
lib_name="$(basename "${BASH_SOURCE%.*}")"
lib_name=${lib_name//-/_}
if eval "[[ ! -v $lib_name ]]"; then
    eval "$lib_name=true"
    # ... library functions ...
fi
```

### Workspace Structure

The library expects a standard workspace layout:

```
~/ws/
└── git/
    └── src/
        ├── Makefile (includes lib/include.mk)
        ├── lib/ (this repository)
        └── bin/
```

### Include Pattern

Projects use the library by:
1. Symlinking or copying `include.sh` to the script directory
2. Sourcing it: `source "$(dirname "$0")/include.sh"`
3. Loading specific libraries: `source_lib lib-name.sh`

## Shell Libraries Reference

| Library | Purpose |
|---------|---------|
| `include.sh` | Bootstrap loader, workspace discovery, `source_lib` function |
| `lib-debug.sh` | Logging (log_verbose, log_error), debugging, tracing |
| `lib-util.sh` | Core utilities: OS detection, disk/GPU info, prompts |
| `lib-config.sh` | Configuration file editing, profile management |
| `lib-install.sh` | Multi-platform package installation (brew, apt, snap, pip, npm) |
| `lib-docker.sh` | Docker and Docker Swarm management |
| `lib-git.sh` | Git repository helpers |
| `lib-ssh.sh` | SSH key management |
| `lib-keychain.sh` | OS keychain integration |
| `lib-mac.sh` | macOS-specific functions |
| `lib-network.sh` | Network configuration |
| `lib-remote.sh` | Remote execution framework |
| `lib-avahi.sh` | Avahi/mDNS service publishing |

## Makefile Includes Reference

| Include | Purpose |
|---------|---------|
| `include.mk` | Base commands, help system, pre-commit, git-lfs |
| `include.python.mk` | Python environments (uv, Poetry, Pipenv) |
| `include.docker.mk` | Multi-arch Docker builds |
| `include.node.mk` | Node.js tooling |
| `include.gcp.base.mk` | Google Cloud Platform |
| `include.ai.mk` | AI/ML infrastructure (Ollama, Qdrant) |

## Code Style Guidelines

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang for portability
- Include the library guard pattern at the top
- Document functions with `## function_name: description` comments
- Use `log_verbose`, `log_warning`, `log_error` for output (from lib-debug.sh)
- Prefer `[[ ]]` over `[ ]` for conditionals
- Quote variables: `"$var"` not `$var`
- Use `local` for function-scoped variables

### Makefiles

- Use `##` comments for self-documenting targets (shown in `make help`)
- Include guard pattern: check if already included before processing
- Use `.PHONY` for non-file targets
- Prefer variables over hardcoded paths

## Testing Changes

Before committing shell script changes:

```bash
# Check syntax
bash -n script.sh

# Run shellcheck if available
shellcheck script.sh

# Test in context
source include.sh
source_lib lib-name.sh
# Test specific functions
```

## Common Tasks

### Adding a New Shell Library

1. Create `lib-newname.sh` with the guard pattern
2. Add functions with `##` documentation
3. Document in README.md and this file
4. Test with `source_lib lib-newname.sh`

### Adding a New Makefile Include

1. Create `include.newname.mk`
2. Add include guard at top
3. Document targets with `##` comments
4. Include from main Makefile: `include $(LIB_DIR)/include.newname.mk`

### Modifying Configuration Functions

The `lib-config.sh` provides several patterns:
- `config_mark` / `config_add`: For marker-based block additions
- `config_add_once`: For single line additions
- `config_replace`: For line replacement
- `set_config_var` / `get_config_var`: For key=value config files

## Dependencies

- **Required**: bash 4.2+ (for `[[ -v varname ]]` syntax)
- **Optional**: lua (for config var functions), shellcheck, pre-commit

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `WS_DIR` | Workspace root directory |
| `SOURCE_DIR` | Source code directory |
| `BIN_DIR` | Binary/scripts directory |
| `VERBOSE` | Enable verbose logging |
| `DEBUGGING` | Enable debug logging |
| `SCRIPTNAME` | Current script name (set by scripts) |

## Links

- [Full Documentation](https://lib.docs.tongfamily.com)
- [Developer Guide](DEVELOPER.md)
- [Code Practices](CODE_PRACTICES.md)
