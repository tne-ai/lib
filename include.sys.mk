##
## System performance optimisation for AI/dev sessions on macOS
## Disables CPU-hungry background services (AVG real-time scanning, Spotlight indexing)
## that thrash the disk whenever code is being written or compiled.
##
## Replaces include.avg.mk — all avg-* targets are preserved here.
##
## Usage:
##   make sys-sudoers    # once — installs NOPASSWD rules for avg + mdutil
##   make sys-optimize   # disable AVG scanning + Spotlight indexing
##   make sys-restore    # re-enable both
##   make sys-status     # show current state
##
##   make avg-add        # AVG exclusion only
##   make avg-remove
##   make avg-status
##   make spotlight-off  # Spotlight only
##   make spotlight-on
##   make spotlight-status
##

# ── AVG ───────────────────────────────────────────────────────────────────────
AVG_CFGCTL  := /Applications/AVGAntivirus.app/Contents/Backend/utils/com.avg.cfgctl
AVG_CONF    := /Library/Application Support/AVGAntivirus/config/com.avg.fileshield.conf
AVG_SECTION := fileshield
AVG_KEY     := pathExclusions
AVG_PATH    ?= $(or $(WS_DIR),$(HOME)/ws/git/src)
# Space-separated list of paths to exclude; ~/.claude has plugin caches + session files.
AVG_PATHS   ?= $(AVG_PATH) $(HOME)/.claude

avg-add: ## Add $$AVG_PATHS (default: $$WS_DIR + ~/.claude) to AVG real-time scan exclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)" >&2; exit 1; }
	@for p in $(AVG_PATHS); do \
		sudo "$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -a "$$p" && echo "AVG: added $$p"; \
	done

avg-remove: ## Remove $$AVG_PATHS from AVG real-time scan exclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)" >&2; exit 1; }
	@for p in $(AVG_PATHS); do \
		sudo "$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -r "$$p" && echo "AVG: removed $$p"; \
	done

avg-status: ## Show current AVG pathExclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)" >&2; exit 1; }
	@"$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -d 2>/dev/null || echo "(none)"

avg-sudoers: ## Install NOPASSWD sudoers rule for com.avg.cfgctl (run once)
	@echo "$(USER) ALL=(root) NOPASSWD: $(AVG_CFGCTL)" | sudo tee /etc/sudoers.d/avg-cfgctl
	@sudo chmod 440 /etc/sudoers.d/avg-cfgctl
	@echo "Done. avg-add/avg-remove will no longer prompt for password."

# ── Spotlight ─────────────────────────────────────────────────────────────────
# mdutil operates per-volume; default is / which covers the whole boot disk.
SPOTLIGHT_VOLUME ?= /

spotlight-off: ## Disable Spotlight indexing on $$SPOTLIGHT_VOLUME (default: /)
	@sudo mdutil -d "$(SPOTLIGHT_VOLUME)"
	@echo "Spotlight: indexing disabled on $(SPOTLIGHT_VOLUME)"

spotlight-on: ## Re-enable Spotlight indexing on $$SPOTLIGHT_VOLUME
	@sudo mdutil -i on "$(SPOTLIGHT_VOLUME)"
	@echo "Spotlight: indexing enabled on $(SPOTLIGHT_VOLUME)"

spotlight-status: ## Show Spotlight indexing status
	@mdutil -s "$(SPOTLIGHT_VOLUME)"

# ── Combined ──────────────────────────────────────────────────────────────────
sys-optimize: avg-add spotlight-off ## Disable AVG scanning + Spotlight for dev session

sys-restore: avg-remove spotlight-on ## Re-enable AVG scanning + Spotlight

sys-status: avg-status spotlight-status ## Show status of both services

sys-sudoers: avg-sudoers ## Install all NOPASSWD sudoers rules (avg + mdutil via passwordless sudo)
	@echo "$(USER) ALL=(root) NOPASSWD: /usr/bin/mdutil" | sudo tee /etc/sudoers.d/mdutil
	@sudo chmod 440 /etc/sudoers.d/mdutil
	@echo "Done. spotlight-off/on will no longer prompt for password."

.PHONY: avg-add avg-remove avg-status avg-sudoers \
        spotlight-off spotlight-on spotlight-status \
        sys-optimize sys-restore sys-status sys-sudoers
