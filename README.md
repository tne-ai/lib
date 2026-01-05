# Rich's Fine Library

A comprehensive, production-grade utility library providing reusable shell/bash functions, Make-based build system templates, and cross-platform support for macOS, Linux, WSL, and Raspberry Pi clusters.

## Quick Start

### Using in a New Project

1. Copy `Makefile.base` to your new repo as `Makefile`
2. Adjust the `.INCLUDE_DIR` path to point to this lib directory
3. Run `make install-repo` to get all default files in place
4. Optionally copy `envrc.base` to `.envrc` at your project root (not in subdirectories)

### Sourcing Shell Libraries

```bash
# In your script, source the bootstrap loader
source "$(dirname "$0")/include.sh"

# Then load specific libraries as needed
source_lib lib-debug.sh
source_lib lib-install.sh
source_lib lib-config.sh
```

## Shell Libraries

### Core Libraries

#### `include.sh` - Bootstrap Loader
The main entry point that provides workspace discovery and the `source_lib` function.

```bash
# Automatically finds workspace and sets WS_DIR, SOURCE_DIR, BIN_DIR
source include.sh

# Load any library by name
source_lib lib-util.sh
```

#### `lib-debug.sh` - Logging and Debugging
Provides logging functions and debug tracing capabilities.

```bash
source_lib lib-debug.sh

log_verbose "Only shown when VERBOSE=true"
log_warning "Always shown warning message"
log_error 1 "Error message, exits with code 1"
log_assert "[[ -f file.txt ]]" "file.txt must exist"

# Enable tracing for debugging
DEBUGGING=true
trace_on   # Start single-step debugging
trace_off  # Stop debugging
```

**Environment Variables:**
- `VERBOSE=true` - Enable verbose output
- `DEBUGGING=true` - Enable debug output and tracing
- `TIMEIT=true` - Show timing information

#### `lib-util.sh` - Core Utilities
General-purpose utility functions for system detection and operations.

```bash
source_lib lib-util.sh

# OS Detection
util_os              # Returns: mac, linux, windows, or docker
in_os mac            # Returns 0 if on macOS
in_os linux          # Returns 0 if on Linux
in_wsl               # Returns 0 if in Windows Subsystem for Linux
in_ssh               # Returns 0 if in SSH session

# Linux Distribution Info
linux_distribution   # Returns: ubuntu, debian, etc.
linux_version        # Returns: 22.04, 11, etc.
linux_codename       # Returns: jammy, bullseye, etc.
desktop_environment  # Returns: gnome, xfce, kde, etc.

# System Info
util_gpu_memory      # Returns GPU memory in GB
util_disk_used       # Returns disk usage percentage
util_full_version    # Returns: macos.arm64.14.0 or linux.ubuntu.22.04.x86_64

# File Operations
util_backup file.txt           # Creates file.txt.bak (incremental)
dir_empty directory            # Returns 0 if empty
util_find "search term"        # Find files in home directory

# Validation
is_command git docker          # Returns 0 if all commands exist
util_semver                    # Parse semantic version from stdin
prompt_user "Continue?" "cmd"  # Interactive yes/no prompt

# Web
util_web_open https://url      # Opens URL in default browser
```

### Configuration Management

#### `lib-config.sh` - Configuration Editing
Edit shell profiles and configuration files programmatically.

```bash
source_lib lib-config.sh

# Profile Detection (respects bash vs zsh)
config_profile                 # Returns path to main profile (.profile or .zprofile)
config_profile_nonexportable   # Returns .bashrc or .zshrc
config_profile_interactive     # Returns interactive profile path

# Marker-based Configuration (prevents duplicate entries)
if ! config_mark; then
    config_add <<-EOF
        export MY_VAR="value"
        alias ll='ls -la'
EOF
fi

# Single Line Operations
config_add_once "" "export PATH=/new/path:\$PATH"
config_replace "" "old_line_prefix" "new_complete_line"

# Key=Value Config Files (uses lua)
set_config_var KEY "value" /etc/config.conf
get_config_var KEY /etc/config.conf
clear_config_var KEY /etc/config.conf

# Shell Management
config_add_shell /opt/homebrew/bin/bash    # Add shell to /etc/shells
config_change_default_shell /bin/zsh       # Change user's default shell

# Utilities
config_backup file.conf        # Create backup before editing
config_sudo /etc/file          # Returns "sudo" if needed for file
source_profile                 # Re-source profile after changes
```

### Installation & Package Management

#### `lib-install.sh` - Multi-Platform Installation
Unified package installation across different package managers.

```bash
source_lib lib-install.sh

# Universal Package Install (tries brew, cask, snap, apt in order)
package_install git vim docker
package_uninstall old-package
package_update                 # Update all package managers

# Homebrew (macOS/Linux)
brew_install package1 package2
brew_is_installed package
cask_install 1password firefox
cask_is_installed app
tap_install homebrew/cask-fonts

# Linux Package Managers
apt_install build-essential
apt_is_installed package
snap_install --classic code
snap_is_installed package
deb_install package-name https://url/package.deb

# Python
pip_install numpy pandas
pipx_install black ruff        # CLI tools in isolated environments

# Node.js
npm_install -g typescript
node_install package

# Other
gem_install bundler            # Ruby
mas_install 123456789          # Mac App Store (app ID)
appimage_install https://url/app.AppImage

# Download Utilities
download_url https://url/file.tar.gz
download_url_open https://url/installer.dmg  # Download and open/mount
download_url_pgp "$file_url" "$sig_url" "$key_url"  # Verify PGP signature
```

### Git & Version Control

#### `lib-git.sh` - Git Repository Helpers

```bash
source_lib lib-git.sh

# Repository Info
git_default_branch             # Returns: main or master
git_repo                       # Returns 0 if in a git repo
git_organization               # Returns the org/user from remote URL

# Repository Management
git_install_or_update repo     # Clone or pull updates
git_install_or_update -f repo  # Force reset to origin/master
git_install_or_update repo user ~/custom/path

# Configuration
git_set_ssh repo               # Switch remote from HTTPS to SSH
git_set_config user.name "Name"
```

### Infrastructure & Containers

#### `lib-docker.sh` - Docker Management

```bash
source_lib lib-docker.sh

# Container Operations
docker_available               # Returns 0 if Docker is running
docker_start                   # Start Docker daemon
docker_architecture            # Returns: intel, rpi1, rpi2, rpi3, rpi

# Container Management
docker_find_container myapp    # Returns 0 if container exists
docker_remove_container myapp  # Stop and remove container

# Docker Machine (for remote/VM Docker hosts)
use_docker_machine default
rm_docker_machine -f machine1 machine2

# Swarm Clusters
set_docker_consul_master hostname
docker_machine_create_swarm remote false "consul://..."
```

### Security & SSH

#### `lib-ssh.sh` - SSH Key Management

```bash
source_lib lib-ssh.sh

# Functions for managing SSH keys and ~/.ssh configuration
# Handles proper permissions (600 for keys, 700 for directory)
```

#### `lib-keychain.sh` - OS Keychain Integration

```bash
source_lib lib-keychain.sh

# Native OS keyring support for SSH keys
# Works with macOS Keychain and Ubuntu 22.04+ secret service
# Detects system reboots for key re-adding
```

### Platform-Specific

#### `lib-mac.sh` - macOS Functions

```bash
source_lib lib-mac.sh

# macOS-specific operations
# Login item management
# System preferences automation
```

#### `lib-network.sh` - Network Configuration

```bash
source_lib lib-network.sh

# Network utilities and configuration
# Requires lib-install.sh
```

#### `lib-remote.sh` - Remote Execution

```bash
source_lib lib-remote.sh

# Remote command execution
# Directory structure copying to remote hosts
```

#### `lib-avahi.sh` - mDNS/Bonjour Services

```bash
source_lib lib-avahi.sh

# Avahi service publishing
# Static and dynamic service advertisement
```

### Utility Libraries

#### `lib-timezone.sh` - Timezone Management

```bash
source_lib lib-timezone.sh
# Timezone detection and configuration
```

#### `lib-version-compare.sh` - Version Comparison

```bash
source_lib lib-version-compare.sh
# Semantic version comparison utilities
```

#### `lib-cluster.sh` - Cluster Management

```bash
source_lib lib-cluster.sh
# Remote cluster management utilities
```

## Makefile Includes

Include these in your Makefile for additional functionality:

```makefile
LIB_DIR := path/to/lib
include $(LIB_DIR)/include.mk           # Base commands, help, pre-commit
include $(LIB_DIR)/include.python.mk    # Python (uv, Poetry, Pipenv)
include $(LIB_DIR)/include.docker.mk    # Docker multi-arch builds
include $(LIB_DIR)/include.node.mk      # Node.js tooling
include $(LIB_DIR)/include.gcp.base.mk  # Google Cloud Platform
include $(LIB_DIR)/include.ai.mk        # AI/ML (Ollama, Qdrant)
```

Run `make help` to see all available targets with descriptions.

## Documentation

Full documentation is available at [lib.docs.tongfamily.com](https://lib.docs.tongfamily.com).

Local documentation server:
```bash
make mkdocs           # Start local server at http://localhost:8000
make mkdocs-stop      # Stop the server
```

Browse documentation files in the [docs](docs) directory.

## Additional Resources

- [DEVELOPER.md](DEVELOPER.md) - Developer guide, git workflows, best practices
- [CODE_PRACTICES.md](CODE_PRACTICES.md) - Coding guidelines
- [claude.md](claude.md) - AI assistant guidelines
- [agents.md](agents.md) - Agent patterns and automation
