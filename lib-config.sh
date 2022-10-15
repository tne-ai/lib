#!/usr/bin/env/bash
## vi: set syntax=sh sw=4 ts=4 noet:
## configuration editing for Mac and Ubuntu
## inspired by raspiconfig
##

#
# Ubuntu https://superuser.com/questions/789448/choosing-between-bashrc-profile-bash-profile-etc/789705#789705
# On startup:  GDM reads .profile as /bin/sh before and cannot be interactive or
#              display text # New terminal window: .profile exports and .bashrc because it is
#              interactive non-login
# Terminal: results of .profile and sources .bashrc
# Terminal subshell: results of .profile and .sources bashrc is run becase it is
#          interactive non-login
# ssh in: Note no .profile exports are available. Runs
#         .bash_profile only because it is an interactive login shell # start non-GUI
# console with CTRL-ALT-F5: .bash_profile because it is an interactive login shell
# pipenv shell: this runs like Terminal and just runs bashrc
#
# The Linux strategy:
# .profile: Can be execed directly by /bin/sh so should only run sh commands
#           or check $BASH if it has to run Bash and source .bashrc
#           This should be used to set the PATH and other environment variables
#           like EDITOR or VISUAL
# .bashrc:  Should be used for non-exportables like history, aliases and
#           functions. It should check if in [[ $- =~ i ]] before interactive
#           displays. Command completions which are bash specific go here
# .bash_profile: should just source .profile (which in turn sources .bashrc) as it is only run on ssh
#
# config_setup: source .profile and .bashrc do not put things into .bash_profile
# config_profile : set to .profile and guard $BASH checks no echo's or input allowed
# config_profile_interactive: for interactive input use adds a guard to test if interactive
# config_profile_nonexportable: set to .bashrc for alias and things that
#
# In MacOS, https://apple.stackexchange.com/questions/51036/what-is-the-difference-between-bash-profile-and-bashrc
# is what happens is that .bash_profile is run for login shells, .bashrc is run
# for non-login shells. If zsh is set then it sources.zprofile and then .zshrc for login shells and
# .zshrc is for non-login shells. So in a typical configuration where bash is
# the login shell you should put all the path and other changes just in .zshrc
# on startup: Nothing is run before the GUI starts
# New terminal window: .bash_profile or .zprofile and then .zshrc (and not .bashrc like in Ubuntu)
# Subshell: results of .bash_profile exports plus .bashrc run or .zprofile
#           results of .zprofile and .zshrc and then .zshrc is sourced
# ssh in: .bash_profile run or .zprofile and then .zshrc is sourced
# pipenv shell: this works like Linux so it only runs .bashrc and skips
#               .bash_profile
#
# The MacOS strategy: be as similar to Linus as possible. Be aware that
# .profile: Put the PATH and other variables you want to be set in .profile use
#		    /bin/sh syntax and detect ZSH_VERSION and run emulate sh to make this work.
# .bash_profile: Sources .profile and .bashrc like Ubuntu.
# .bashrc: Same strategy, it should only do non-exportables like history, aliases and functions
#           and check if in [[ $- =~ i ]] before interactive displays. It gets
#           completions because of the pipenv problem since .bash_profile is
#           not run
# .zprofile: source .profile manually with no need to source .zshrc as this is alway done
# .zshrc: handles non-exportables and check to see if it is interactive or not.
#
# Note: checking if you are login shell or not https://unix.stackexchange.com/questions/26676/how-to-check-if-a-shell-is-login-interactive-batch
# can be done by checking for -l in $- in zsh or shopt -q login_shell for bash
#
# config_setup: In .bash_profile sources .profile
#               In .zprofile source .profile (.zshrc is sourced automatically)
#				In .profile source .bashrc
# config_profile = .profile: (.zprofile if ZSH_VERSION) for non-interactive exports
# config_profile_interactive = .bashrc: set to .bashrc (or .zshrc)and you should do an interactive check
# config_profile_nonexportable = .bashrc: set to .bashrc (or .zshrc)for alias and things that
# config_profile_shell: set to .bash_profile (or .zprofile if using zsh

## config_profile: returns the name of the profile to use for non-interactive command
# this should only be for thing that do not display or require input
# this is normally .zprofile but set to .zshrc in the case where the login
# shell is not zsh. That is if you have a Mac using bash and then escept to
# zsh only sometimess
# set ZSH_VERSION to use .zshrc when zsh is not the login shell

config_profile_zsh() {
	echo "$HOME/.zprofile"
}
config_profile_bash() {
	echo "$HOME/.profile"
}
config_profile() {
	if [[ $SHELL =~ zsh || -v ZSH_VERSION ]]; then
		config_profile_zsh
	else
		config_profile_bash
	fi
}

## config the non-login script run with every new shell
# set ZSH_VERSION to use .zshrc
config_profile_nonexportable_zsh() {
	echo "$HOME/.zshrc"
}
config_profile_nonexportable_bash() {
	echo "$HOME/.bashrc"
}
config_profile_nonexportable() {
	if [[ $SHELL =~ zsh || -v ZSH_VERSION ]]; then
		config_profile_nonexportable_zsh
	else
		config_profile_nonexportable_bash
	fi
}

# if this is for initial boot on linux it is .profile
# this should have no output visible
# not used for the Mac
## config_profile_interactive: Use this profile where uses need to see and type
config_profile_interactive_zsh() {
	echo "$HOME/.zshrc"
}
config_profile_interactive_bash() {
	echo "$HOME/.bashrc"
}
config_profile_interactive() {
	if [[ $SHELL =~ zsh || -v ZSH_VERSION ]]; then
		config_profile_interactive_zsh
	else
		config_profile_interactive_bash
	fi
}

config_profile_shell_zsh() {
	echo "$HOME/.zprofile"
}
config_profile_shell_bash() {
	echo "$HOME/.bash_profile"
}
# config_profile_shell: set to .bash_profile (or .zprofile if using zsh
config_profile_shell() {
	if [[ $SHELL =~ zsh || -v ZSH_VERSION ]]; then
		config_profile_shell_zsh
	else
		config_profile_shell_bash
	fi
}

## config_profile_for_bash: put bash specific profile in right files for Ubuntu and Mac
# General commands for path setting should be in .profile in /bin/sh syntax
# Bash specific entries should go to .bash_profile for Mac and .bashrc for
# Ubuntu if you are not using pipenv. But if you are using pipenv, then you
# also have to use .bashrc because you will get completions otherwise
#
#
config_profile_for_bash() {
	if in_os mac; then
		# switch to using .bashrc because pipenv only runs .bashrc and you lose
		# completions otherwise
		#config_profile_shell_bash
		config_profile_shell_interactive
	else
		config_profile_shell_interactive
	fi
}


## source_profile: $file
# Get the profiles from $dir and source it
# needed when updating paths and want to immediately use the new
# commands in the running script
source_profile() {
	#shellcheck disable=SC2043
	file="${1:-$(config_profile_shell)}"

	if [[ -e $file ]]; then
		# turn off undefined variable checking because
		# scripts like bash completion reference undefined
		# as this is a common idium
		set +u
		# shellcheck disable=SC1090
		source "$file" || true
		set -u
	fi

	# do not do this as this inserts standard paths before the custom ones
	#if [[ $OSTYPE =~ darwin ]] && [[ -e /usr/libexec/path_helper ]]; then
	#    eval "$(/usr/libexec/path_helper)"
	#fi

	# rehash in case the path changes changes the execution order
	hash -r
}

## config_add_shell [new-shell-path]
config_add_shell() {
	local DESIRED_SHELL_PATH
	DESIRED_SHELL_PATH="${1:-"$(brew --prefix)/bin/bash"}"
	if [[ ! -e $DESIRED_SHELL_PATH ]]; then
		return 1
	fi
	if ! grep "$DESIRED_SHELL_PATH" /etc/shells; then
		sudo tee -a /etc/shells <<<"$DESIRED_SHELL_PATH" >/dev/null
	fi
}

## config_default_shell [new-shell-path]
config_change_default_shell() {
	local DESIRED_SHELL_PATH
	DESIRED_SHELL_PATH="${1:-"$(brew --prefix)/bin/bash"}"
	if in_os mac; then
		CURRENT_SHELL_PATH="$(dscl . -read "$HOME" UserShell)"
	else
		CURRENT_SHELL_PATH="$(grep "$USER" /etc/passwd | cut -d ":" -f 7)"
	fi
	log_verbose "Current default shell is $CURRENT_SHELL_PATH"
	# https://stackoverflow.com/questions/16375519/how-to-get-the-default-shell
	if [[ $CURRENT_SHELL_PATH != "$DESIRED_SHELL_PATH" ]]; then
		log_verbose "Default user shell is not $DESIRED_SHELL_PATH"
		log_warning you only get one login opportunity to change the shell so type carefully.
		log_warning "If you do not want to change the chsh just press enter"
		log_warning "if you make a mistake just rerun $SCRIPTNAME"
		chsh -s "$DESIRED_SHELL_PATH"
	fi
}

#
#
# Marker and many lines
# ---------
# the first set just looks for a marker line and then adds a bunch of lines
# it does not examine the specific contents of the lines added.
# This is most useful for large scale configurations where you are really
# adding say lines ot a bash script. The marker line is used (usually Added by

# - config_mark: Looks for a marker line and adds one if not already there
# - config_add: reads from the stdin and splats to the file without # comparing
# - config_add_var: Adds a string to a particular bash variable checking first to see if it is already there
#
# The second does whole line replacement.
# -------
# This looks for entire lines with a PREFIX and replaces them. This is most
# useful for smaller edits at the line level.
# - config_add_once: Add a line in a file if it does not exist
# - config_replace: Looks for a specific line and replaces it with a new one
#
# The final type deals with replacing setting variables
# ------
# This is the most specific, it uses lua to actually replace variables. It
# assumes the format is variable=expression and can actually parse the line.
# This is most useful for config flies like /etc/default/zfs and other sysrtemn
# - get_config_var : read out a variabvle
# - set_config_var : writes one
# - change_config_var: removes an item from the value of a config var
# - clear_config_var : removes it
#
# Utility functions
# -------
# There are some useful functions
# config_sudo: based on the file ownership decide where to use sudo or not
# config_lines_to_line: handles multiple lines additions when doing whole lines
# (obsolete use config_to_sed which also does quotes)
# and make it ready for sed by backquoting special characters

# config_backup takes a set of files and backs them up
# usage: config_backup [files...]
config_backup() {
	for target in "$@"; do
		# https://unix.stackexchange.com/questions/67898/using-the-not-equal-operator-for-string-comparison
		if [[ $target =~ ^(.|..)$ ]]; then
			# ignore $file if it is the CWD or the parent
			continue
		fi
		if [[ -e $target ]]; then
			log_verbose "found $target exists copying it to $target.bak"
			n=0
			backup="$target.bak"
			while [[ -e $backup ]]; do
				# $backup exists
				backup="${backup%.bak*}.bak.$((++n))"
				# try the next file down $backup
			done
		fi
	done
}

# https://stackoverflow.com/questions/29613304/is-it-possible-to-escape-regex-metacharacters-reliably-with-sed
# magical oneliner that handles multiline sed replacement.
# Use for finding and replacing multiple lines in a config file
# does need gnu sed and not mac sed
#
# Changed from stdin to stdout because of One bug is that is always adds a new line if there is just one line
# So you can use set_config_var instead for instance if there is just one line
# usage: to_sed_regex
# stdin: input lines does not work for single lines
# returns: 0 on success
# stdout: the properly escaped string (make sure to quote may have spaces
config_to_sed() {
	# IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
	# https://www.cyberciti.biz/faq/unix-howto-read-line-by-line-from-file/
	# IFS=_space_ means that you should read the stdin separated by a space
	# -d '' means the delimiate is a null
	IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g')
	# removes the newline that the redirect put in
	# printf %s "${REPLY%$'\n'}"
	# if a single line, remove another so we will have two extras
	printf %s "${REPLY%$'\n\n'}"
}

# https://stackoverflow.com/questions/40573839/how-to-use-printf-q-in-bash
# arguments: all arguments, so you want your text file to be in a bash variable
# stdout: the escaped string suitable for sed
config_to_sed_printf() {
	printf %q "$@"
}

#  works correct using only sed for multiple lines
config_to_sed_multiline() {
	# IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
	IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g')
	# removes the newline that the redirect put in
	printf %s "${REPLY%$'\n'}"
}

# returns sudo if you need it you need to force evaluation with
# $(config_sudo) which cause sudo to run
# usage: config_sudo files
config_sudo() {
	# use find instead of stat since it works on Mac
	# stat -c '$U' only available with gnu stat
	# if [[ $(stat -c '%U' "$config") != $USER ]]
	# note we do not quote $@ so we can search them all
	# Note that this test does fail because the directory must also be writeable
	# and owned by you so this does not work with `mv` but does with tee
	# if there is no util sudo then make our own because we do not want to
	# depend on lib-util.sh as this system does not allow cascading library
	# dependencies
	for file in "$@"; do
		# get the canonical form or the name assumes you are using the gnu
		file="$(readlink -f "$file")"
		# work up the path of the file until we find a file that exists
		while [[ ! -e $file ]]; do
			file=$(dirname "$file")
		done
		if [[ ! -w $file ]]; then
			echo sudo
		fi
	done
}

# make sure the parent and file exist
# usage: config_touch files...
config_touch() {
	for file in "$@"; do
		if [[ ! -e $file ]]; then
			# cannot use readlink -f not the Mac so use this instead
			# local path=$(readlink -f "$file")
			#does not work if $dir not yet created so do not use
			#this canonical view
			#local dir="$(cd "$(dirname "$file")" && pwd -P)"
			dir="$(dirname "$file")"
			$(config_sudo "$dir") mkdir -p "$dir"
			$(config_sudo "$file") touch "$file"
		fi
	done
}

# converts a bash variable with multiline text
# to a single string with \n in it on stdout
# usage: config_lines_to_line
# stdin: lines that need to be converted
# stdout: single line with \n in them
config_lines_to_line() {
	# note we use quotes on lines to retain the newlines
	# tr then deletes the special character that is a new line
	# sed adds the characters '\' and 'n' not clear why
	# config_to_sed | sed 's/$/\\n/' | tr -d '\n'
	config_to_sed | tr -d '\n'
}

# replaces the original marker work and uses the config_add
# this marks a configuration file as being edited
# It searches the "marker" line and does not add more if it finds it
# and returns the state of the file.
# if the file dopes not exist we create all the parent directories and then the
# file
# usage: config__mark -f [file [ comment-prefix [ marker ]]]
# -f means force a new marker
# returns: 0 if marker was found
#          1 no marker found so we added and this is a fresh file
config_mark() {
	# if (( $# < 1)); then return 1; fi
	if [[ $# -gt 0 && $1 == -f ]]; then
		local force=true
		shift
	fi
	local file=${1:-"$(config_profile)"}
	local comment_prefix="${2:-"#"}"
	local marker="${3:-"Added by $SCRIPTNAME"}"

	config_touch "$file"
	# need the -- incase the comment_prefix has a leading -
	if ${force:-false} || ! grep -q -- "$comment_prefix $marker" "$file"; then
		# do not quote config_sudo because it can return null
		# https://stackoverflow.com/questions/3005963/how-can-i-have-a-newline-in-a-string-in-sh
		$(config_sudo "$file") tee -a "$file" <<<$'\n'"$comment_prefix $marker on $(date)" >/dev/null
		return 1
	fi
}

#
#
# It adds to the stdin use with the redirection <<-EOF typically and then EOF
# usage: config_add [file_to-change] <<-EOF
#        some lines to add
#        EOF
#
# Use config_add_once if you want to replace just a sigle ilne
# this is normally used with config_mark
#
config_add() {
	# if (( $# < 1 )); then return 1; fi
	local file="${1:-"$(config_profile)"}"
	# by default the prefix is the entire line
	# so in the default case it just adds a line
	config_touch "$file"
	local need_sudo
	need_sudo="$(config_sudo "$file")"
	# if output is null then do not put a parameter
	# need_sudo should also  be empty
	$need_sudo tee -a "$file" >/dev/null
}

#
# config_add_var [file|""] variable strings...
# adds a string to a bash variable at the beginning assuming the variable doesn'
# to use the default file, pass a null
# config_add_var "" var strings..
config_add_var() {
	if (($# < 2)); then return 1; fi
	local file="${1:-"$(config_profile)"}"
	local variable="${2:-"PATH"}"
	shift 2
	for string in "$@"; do
		config_add "$file" <<<-"[[ \$$variable =~ $string ]] || export $variable=\"$string\:\$$variable ]]"
	done
}

# Adds a line if it is not already there
# It looks for a prefix and then slams a new line in if it findds it
# forces a replacement if it already exists
# the replacement can be multiple lines
# flags: -x this flag means if you find an instance don't replace
#        the default is you replace a single line
# usage: config_replace [-n] [file| ""] prefix-of-of-the-line-to-be-replaced lines-to-add
config_replace() {
	if (($# < 3)); then return 1; fi
	local MULTILINE=false
	if [[ $1 == -x ]]; then
		local MULTILINE=true
		shift
	fi
	local file="${1:-"$(config_profile)"}"
	local target="${2:-""}"
	local lines="${3:-""}"

	# shold not need to touch assume file existrs
	config_touch "$file"
	need_sudo="$(config_sudo "$file")"
	# not sure but $ means an exact match
	# so if we want to majhc then need to do
	# usage: config_add_lines [-f] [file [ lines ]]
	echo grep -q "^$target" "$file"
	if ! grep -q "^$target" "$file"; then
		# did not find the target so just add the entire line
		#echo no line so add with tee
		# do not quote need_sudo as it can be null if not needed
		$need_sudo tee -a "$file" <<<"$lines" >/dev/null
	elif ! $MULTILINE; then
		# note this requires gnu sed running on a Mac
		# fails with the installed sed
		# to make change work we need to convert
		# $new with real new lines into something with \n in
		# a single string
		# local new_sed="$(config_to_line <<<"$lines")"
		local new_sed
		new_sed="$(config_to_sed <<<"$lines")"
		echo "new=$new_sed"
		local target
		target_sed="$(config_to_sed <<<"$target")"
		echo "target=$target_sed"
		# do not quote need_sudo in case it is null
		# echo $need_sudo sed -i "/^$target_sed/c\\$new_sed" "$file"
		if [[ $(command -v sed) =~ /usr/bin/sed ]]; then
			# this means we do not have gsed and -i will not work
			brew install gnu-sed
			PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
		fi
		$need_sudo sed -i "/^$target_sed/c\\$new_sed" "$file"
		return
	fi

}

# used config_replace but adds a line only if not present
# usage: config_add_once [file| ""] line-to-add
# null first parameter means take the default
config_add_once() {
	if (($# < 2)); then return 1; fi
	local file="${1:-"$(config_profile)"}"
	shift
	local line="$*"
	if ! grep -q "$line" "$file"; then
		echo "adding line $line to $file"
		$(config_sudo "$file") tee -a "$file" <<<"$line" >/dev/null
	fi
	# do not use config replace much simpler to do the check here
	# config_replace "$file" "$lines" "$lines"
}

# for bash_profile, sources .profile and .bashrc. For zsh source .profile as
# .zshrc is always sourced afterwads
# you should guard this with a config_mark_setup
# typically config_profile_shell is .bash_profile
# config_setup: In .bash_profile (aka .config_profile_shell) source .profile config_profile
#               In .zprofile source .profile (.zshrc is sourced automatically)
#				In .profile source .bashrc
config_setup() {
	if ! config_mark "$(config_profile_shell)"; then
		config_add "$(config_profile_shell)" <<-EOF
			# shellcheck disable=SC1091
			[[ -f "$(config_profile)" ]] || source "$(config_profile)"
		EOF
		# now add the .zprofile source of .profiel
		ZSH_VERSION=true config_add "$(config_profile_shell)" <<-EOF
			# shellcheck disable=SC1091
			if [[ -f "$(config_profile)" ]]; then source "$(config_profile); fi"
		EOF
	fi
	if ! config_mark; then
		# .local has mainly pip installed utilities
		# note .profile should only use /bin/sh syntax
		config_add <<-EOF
			# shellcheck disable=SC1091
			if ! echo \$PATH | grep -q "\$HOME/.local/bin"; then PATH="\$HOME/.local/bin:\$PATH"; fi
			if ! echo \$PATH | grep -q "$SOURCE_DIR/bin"; then PATH="$SOURCE_DIR/.local/bin:\$PATH"; fi
		EOF
	fi
}

## config_setup_end: run this at the end so .rc files run after all the paths are set
# to do we should create a function that checks and makes sure this is always
# last in the .profile ONly needed for bash as zsh does this automatically
config_setup_end() {
	if [[ $SHELL =~ zsh || -v ZSH_VERSION ]]; then
		return
	fi
	if ! config_mark; then
		config_add <<-EOF
			if echo "$BASH" | grep -q bash && [-f "$(config_profile_nonexportable)" ]; then
				source "$(config_profile_nonexportable)"; fi
		EOF
	fi
}

# params file variable value
# usage: set_config_var [-f] key value file [marker]
set_config_var() {
	if (($# < 3)); then return 1; fi
	local force=false
	if [[ $1 == -f ]]; then
		force=true
		shift
	fi
	local key="$1"
	local value="$2"
	local file="$3"
	local marker="${4:-"Added by $SCRIPTNAME"}"
	if ! $force && grep "$marker" "$file"; then
		return
	fi
	local temp
	temp="$(mktemp)"
	lua - "$key" "$value" "$file" <<EOF >"$temp"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
	line=key.."="..value
	made_change=true
  end
  print(line)
end
if not made_change then
  print(key.."="..value)
end
EOF

	# note you should not move the file but tee into it
	$(config_sudo "$file") tee "$file" <"$temp" >/dev/null
}

# change part of a  configuration variable
# most useful when there is a long string and you just want to delete one item
# GRUB_CMGLINE is an example where you just want to remove the variable QUIET in
# the string
# usage: modify_config_var key old_value new_value file [marker]
modify_config_var() {
	if (($# < 4)); then return 1; fi
	local key="$1"
	local current_value="$2"
	local new_value="$3"
	local file="$4"
	local marker="${5:-"Added by $SCRIPTNAME"}"
	local current_line
	current_line=$(get_config_var "$key" "$file")
	# do not need eval because you can use variables in bash substitutions
	log_verbose "current $current_line change from $current_value to \"$new_value\""
	local new_line="${current_line/$current_value/$new_value}"
	log_verbose "new_line is $new_line"
	set_config_var "$key" "$new_line" "$file" "$marker"
}

# change part of a  configuration variable
# most useful when there is a long string and you just want to delete one item
# GRUB_CMGLINE is an example where you just want to remove the variable QUIET in
# the string
# usage: modify_config_var key old_value new_value file [marker]
modify_config_var() {
	if (($# < 4)); then return 1; fi
	local key="$1"
	local current_value="$2"
	local new_value="$3"
	local file="$4"
	local marker="${$:-"Added by $SCRIPTNAME"}"
	local current_line
	current_line=$(get_config_var "$key" "$file")
	# do not need eval because you can use variables in bash substitutions
	local new_line=${current_line/$current_value/$new_value}
	set_config_var "$key" "$new_line" "$file"
}

# clears teh config variable
# usage: clear_config_var [-f] key file [marker]
clear_config_var() {
	if (($# < 2)); then return 1; fi
	local force=false
	if [[ $1 == -f ]]; then
		force=true
		shift
	fi
	local key="$1"
	local file="$2"
	local marker="${3:-"Added by $SCRIPTNAME"}"
	if ! $force && grep "$marker" "$file"; then
		return
	fi
	local temp
	temp="$(mktemp)"
	lua - "$key" "$file" <<EOF >"$temp"
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  if line:match("^%s*"..key.."=.*$") then
	line="#"..line
  end
  print(line)
end
EOF
	$(config_sudo "$file") mv "$temp" "$file"
	rm "$temp"
}

# get the state of the config variable after the equal sign
# usage: get_config_var key file
get_config_var() {
	if (($# < 2)); then return 1; fi
	local key="$1"
	local file="$2"
	lua - "$key" "$file" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
local found=false
for line in file:lines() do
  local val = line:match("^%s*"..key.."=(.*)$")
  if (val ~= nil) then
	print(val)
	found=true
	break
  end
end
if not found then
   print(0)
end
EOF
}
