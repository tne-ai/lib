##
## AVG Antivirus path exclusion management
## Reduces CPU during dev sessions by excluding $WS_DIR from real-time scanning.
## Requires one-time sudoers setup: make avg-sudoers
##
## Usage:
##   make avg-sudoers   # once — installs NOPASSWD rule for com.avg.cfgctl
##   make avg-add       # add $$WS_DIR to AVG exclusions
##   make avg-remove    # remove $$WS_DIR from AVG exclusions
##   make avg-status    # show current exclusions
##

AVG_CFGCTL := /Applications/AVGAntivirus.app/Contents/Backend/utils/com.avg.cfgctl
AVG_CONF   := /Library/Application Support/AVGAntivirus/config/com.avg.fileshield.conf
AVG_SECTION := fileshield
AVG_KEY    := pathExclusions
AVG_PATH   ?= $(or $(WS_DIR),$(HOME)/ws/git/src)

avg-add: ## Add $$AVG_PATH (default: $$WS_DIR) to AVG real-time scan exclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)"; exit 1; }
	sudo "$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -a "$(AVG_PATH)"
	@echo "Added: $(AVG_PATH)"

avg-remove: ## Remove $$AVG_PATH from AVG real-time scan exclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)"; exit 1; }
	sudo "$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -r "$(AVG_PATH)"
	@echo "Removed: $(AVG_PATH)"

avg-status: ## Show current AVG pathExclusions
	@[[ -x "$(AVG_CFGCTL)" ]] || { echo "AVG not found: $(AVG_CFGCTL)"; exit 1; }
	@"$(AVG_CFGCTL)" -f "$(AVG_CONF)" -t "$(AVG_SECTION)" -v "$(AVG_KEY)" -d 2>/dev/null || echo "(none)"

avg-sudoers: ## Install NOPASSWD sudoers rule for com.avg.cfgctl (run once)
	@echo "$(USER) ALL=(root) NOPASSWD: $(AVG_CFGCTL)" | sudo tee /etc/sudoers.d/avg-cfgctl
	@sudo chmod 440 /etc/sudoers.d/avg-cfgctl
	@echo "Done. avg-add/avg-remove will no longer prompt for password."

.PHONY: avg-add avg-remove avg-status avg-sudoers
