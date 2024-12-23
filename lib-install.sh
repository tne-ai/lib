#!/usr/bin/env bash
# vim: ai:sw=4:ts=4:noet
##
##Installation works on either Mac OS X (Darwin) or Ubuntu
##
## package_install goes through multiple installers
## if you know what installer then its more efficient to just call the
## installer
#

# create a variable that is just the filename without an extension
lib_name="$(basename "${BASH_SOURCE%.*}")"
# dashes are not allowed in bash variable names so make them underscores
lib_name=${lib_name//-/_}
# This is how to create a pointer by reference in bash so
# it checks for the existence of the variable named in $lib_name
# not how we use the escaped $ to get the reference
# as of bash 4.2 we can test directly
if eval "[[ ! -v $lib_name ]]"; then
	# how to do an indirect reference
	eval "$lib_name=true"

	# brew_profile_install brew shell profile
	brew_profile_install() {
		# pre-install may have added this or otherwise, so if
		# we see this variable assume something else installed it
		if [[ ! -v HOMEBREW_PROFILE ]]; then return; fi

		# Assume that if brew is set we do not need to do this

		if ! config_mark; then
			config_add <<-EOF
				# Added by $SCRIPTNAME on $(date)
				if [ -z "$HOMEBREW_PREFIX" ]; then
					HOMEBREW_PREFIX="/opt/homebrew"
					if  uname | grep -q Linux; then
						HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
					elif uname | grep -q Darwin && uname -m | grep -q x86_64; then
						HOMEBREW_PREFIX="/usr/local"
					fi
					eval "\$(\$HOMEBREW_PREFIX/bin/brew shellenv)"
				fi
			EOF
		fi
	}

	# usage: tap_install [ -flags...] [ taps... ]
	tap_install() {
		if ! command -v brew &>/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		declare -a flags
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		for tap in "$@"; do
			log_verbose "brew tap $tap exists?"
			if ! brew tap | grep -q "^$tap"; then
				log_verbose "no $tap found installing"
				# since no flags
				#shellcheck disable=SC2068
				brew tap ${flags[@]} "$tap"
			fi
		done
	}
	cask_is_installed() {
		if ! command -v brew &>/dev/null; then return 1; fi
		declare -i missing=0
		for cask in "$@"; do
			log_verbose "is $cask installed?"
			# cask output can be case sensitive so brew info 1password
			# returns 1Password but no longer as the first entry
			# As of Dec 2022 brew list now crashes when piped to grep???!
			if ! brew list --cask "$cask" &>/dev/null; then
				log_verbose "no $cask found"
				missing+=1
			fi
		done
		log_verbose "$missing casks are missing"
		return "$missing"
	}
	## cask_install [ casks... ]: returns number of casks not installed
	cask_install() {
		if ! command -v brew &>/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		# https://askubuntu.com/questions/385528/how-to-increment-a-variable-in-bash
		# performance better if you declare an integer
		declare -i missing=0
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		for cask in "$@"; do
			log_verbose "brew --cask $cask exists?"
			# shellcheck disable=SC2068
			if ! brew info "$cask" &>/dev/null; then
				log_verbose "$cask not a cask"
				missing+=1
			elif ! cask_is_installed "$cask" && ! brew install --cask ${flags[@]} "$cask"; then
				log_verbose "$cask install failed"
				missing+=1
			fi
		done
		log_verbose "cask install return $missing"
		return "$missing"
	}
	cask_uninstall() {
		brew_uninstall "$@"
	}
	# https://unix.stackexchange.com/questions/265267/bash-converting-path-names-for-sed-so-they-escape
	# Uses bash substring replacement
	flags_to_grep() {
		echo "${1//-/\\-}"
	}

	brew_is_installed() {
		declare -i missing=0
		log_verbose "are $# package(s) $*"
		for package in "$@"; do
			log_verbose "looking for $package"
			# for some reason piping stdout to /dev/null
			# means brew list always returns successful
			if ! brew list -q "$package" 2>/dev/null; then
				log_verbose "did not find $package"
				((++missing))
			fi
		done
		log_verbose "missing $missing packages"
		return "$missing"
	}

	# Mac Brew installations for simple packages called bottles
	# usage: brew_install [flags] [bottles...]
	# returns: number of failed installed
	# if the package is not in brew then count that as a failed installation
	brew_install() {
		if ! command -v brew &>/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		declare -i failed=0
		declare -a flags
		# find all the flags at the start
		log_verbose "brew_install called with $*"
		while [[ $1 =~ ^- ]]; do
			log_verbose "adding flag $1"
			flags+=("$1")
			shift
		done
		log_verbose "installing packages $* with flags ${flags[*]}"
		for package in "$@"; do
			log_verbose "brew looking for $package"
			if ! brew info "$package" &>/dev/null; then
				log_verbose "$package is not in brew"
				failed+=1
			elif ! brew_is_installed "$package"; then
				log_verbose "$package not installed"
				# shellcheck disable=SC2068
				if ! brew install ${flags[@]} "$package"; then
					log_verbose "$package install failed"
					failed+=1
				fi
			fi
		done
		return "$failed"
	}
	brew_uninstall() {
		if ! command -v brew &>/dev/null; then return 1; fi
		brew uninstall "$@"
	}
	# usage: brew_conflict package1 package2 new_packages
	# error code 0 if there is a conflict
	brew_conflict() {
		if ! command -v brew &>/dev/null; then return 1; fi
		if (($# < 2)); then return; fi
		local package1="$1"
		shift
		local package2="$2"
		shift
		# https://apple.stackexchange.com/posts/322371/revisions
		if brew list "$package1" >&/dev/null &&
			brew deps --tree "$@" | grep "$package2" &>/dev/null; then
			return
		fi
		return 1
	}
	# Mac App Store
	# you will get warnings if already installed but continues
	mas_install() {
		if ! command -v mas &>/dev/null; then return 1; fi
		mas install "$@"
	}
	mas_uninstall() {
		if ! command -v mas &>/dev/null; then return 1; fi
		mas uninstall "$@"
	}
	mas_is_installed() {
		if ! command -v mas &>/dev/null; then return 1; fi
		log_verbose "are $# package(s) $*"
		declare -i missing=0
		for MAS in "$@"; do
			if ! mas list | grep -q "$MAS"; then
				missing+=1
			fi
		done
		log_verbose "missing $missing packages"
		return "$missing"
	}

	# install a apt-get package uses apt_run underneath
	apt_install() {
		apt_run install "$@"
	}
	apt_uninstall() {
		apt_run remove "$@"
	}
	apt_is_installed() {
		declare -i missing=0
		for package in "$@"; do
			if ! dpkg -l "$package" >/dev/null; then
				missing+=1
			fi
		done
		return "$missing"
	}
	apt_run() {
		local flags=()
		declare -i failed=0
		if ! command -v apt-get >/dev/null; then return 1; fi
		if (($# < 1)); then return 1; fi
		operation="$1"
		shift
		# find all the flags at the start
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		for package in "$@"; do
			if ! apt-cache show "$package" >/dev/null; then
				failed+=1
			elif ! apt_is_installed "$package"; then
				if ! sudo apt-get "$operation" -y "${flags[@]}" "$package"; then
					log_verbose "$package not an apt or install failed"
					failed+=1
				fi
			fi
		done
		return "$failed"
	}
	# Apt repository install
	# usage: apt_repository_install [ppa:team/repo | single_repo string]
	apt_repository_install() {
		if [[ $# -lt 1 ]]; then
			return 1
		fi
		if [[ ! $OSTYPE =~ linux ]]; then
			return 2
		fi
		# note that apt-add-repository does not duplicate add entries so can apply
		# multiple times
		sudo apt-add-repository -y "$@"
		sudo apt-get update -y
	}
	# install a debian package and check if it already exists
	# the last parameters are fed directly to download_url and must match
	# usage: deb_install debian-package-name url [dest_file [dest_dir [md5 [sha256]]]]
	# the rest of the parameters are passed onto download_url
	deb_install() {
		if (($# < 2)); then return 1; fi
		local package="$1"
		local url="$2"
		local dest="${3:-"$(basename "$url")"}"
		local dest_dir="${4:-"$WS_DIR/cache"}"
		log_verbose "check $package is already installed"
		# for some reason grep -q does not work here it always fails
		if dpkg-query -l | awk '{print $2}' | grep "^$package" >/dev/null; then
			log_verbose "Package $package already installed"
			return
		fi
		shift
		log_verbose "call download_url $*"
		download_url "$@"
		log_verbose "dpkg install from  $dest_dir finding $dest"
		sudo dpkg -i "$dest_dir/$dest"
	}

	snap_is_installed() {
		if ! command -v snap &>/dev/null; then return 1; fi
		declare -i missing=0
		for package in "$@"; do
			if ! snap list "$package" &>/dev/null; then
				((++missing))
			fi
		done
		log_verbose "search for $* returning $missing"
		return "$missing"
	}
	## nap_install [ -flags.. ] [ packages... ]: return number of failed
	snap_install() {
		if ! command -v snap &>/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		declare -a flags=()
		declare -i failed=0
		# find all the flags at the start
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		log_verbose "snap install $*"
		for package in "$@"; do
			log_verbose "snap $package search"
			# shellcheck disable=SC2068
			if ! snap search "$package" | cut -f 1 -d' ' | grep -q "^$package\$" &>/dev/null; then
				log_verbose "$package not snap package"
				((++failed))
			elif snap_is_installed "$package" &>/dev/null; then
				log_verbose "snap $package already installed"
				continue
			elif ! sudo snap install ${flags[@]} "$package"; then
				log_verbose "$package installed failed"
				((++failed))
			else
				log_verbose "$package installed"
			fi
		done
		return "$failed"
	}
	snap_uninstall() {
		for package in "$@"; do
			sudo snap remove "$package"
		done
	}

	## appimage_install url [ full_dest_path [ dest_dir ]]: Puts an App image in the home directory Applications
	#
	appimage_install() {
		if (($# < 1)); then return 1; fi
		local url="$1"
		local dest_dir="${3:-"$HOME/Applications"}"
		local dest="${2:-"$dest_dir/$(basename "$1")"}"
		log_verbose "appimage_install: download $url to $dest_dir as $dest"
		mkdir -p "$dest_dir"
		download_url "$url" "$dest" "$dest_dir"
		chmod +x "$dest"

	}

	## app_install [apps]: use snap if linux, brew cask otherwise
	app_install() {
		log_verbose "app_install with $*"
		if [[ $OSTYPE =~ linux ]]; then
			log_verbose "Snap install $*"
			snap_install "$@"
		else
			cask_install "$@"
		fi
	}

	## General package install when you do know what packager it is
	# initialize package managers and update them all
	# usage: package_update
	package_update() {
		local output='> /dev/null'
		if $VERBOSE; then
			output=""
		fi
		# brew is on mac, linux and wsl
		# use eval to pipe if needed for verbosity
		if command -v brew >/dev/null; then
			# Need eval because of the $output piping
			eval brew update "$output"
			# ignore upgrade errors
			eval brew upgrade "$output" || false
		elif [[ $OSTYPE =~ darwin ]]; then
			# if on Mac try macports (deprecated)
			if command -v port >/dev/null; then
				# https://guide.macports.org
				# -N means noninteractive
				# Need eval because of the $output
				eval sudo port -N selfupdate "$output"
				# returns an error if nothing to upgrade ignore it
				eval sudo port -N upgrade outdated "$output" || true
			fi
		else
			# assume on linux
			eval sudo apt-get update "$output"
			eval sudo apt-get upgrade "$output"
		fi
	}
	## package_install [ -flags... ] [ packages... ]
	# install a package on Mac OS X (aka Darwin) or linux
	# Assums that any flags at the front are passed to the underlying package
	# manager
	# On brew assumes you've tapped the right cask (eg added the right repo
	# usage: package_install [flags] [packages...]
	# returns: 0 if all packages installed otherwise the error code of the
	# first install that failed
	package_install() {
		if (($# < 1)); then
			return
		fi
		# find all the flags at the start
		declare -a flags
		declare -i failures
		declare -i found
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		local failures=0
		for package in "$@"; do
			found=0
			log_verbose "looking for $package"
			# the order is important as we stop at first packager found
			for packager in brew cask snap apt; do
				log_verbose "trying ${packager}_install $package"
				if ${packager}_install "${flags[@]}" "$package"; then
					log_verbose "${packager}_install $package succeeded"
					((++found))
					break
				fi
			done
			if ((found == 0)); then
				((++failures))
			fi
		done
	}
	#  package_uninstall -flags.. [packages...]
	# Will also make sure that the right flags are installed for brew
	package_uninstall() {
		# consume the flags to pass on
		local flags=()
		log_verbose "parameters $*"
		while [[ $1 =~ ^- ]]; do
			log_verbose "found flag"
			flags+=("$1")
			shift
		done
		log_verbose "parameters $*"
		for package in "$@"; do
			for packager in brew cask snap apt; do
				if ${packager}_uninstall "${flags[@]}" "$package"; then
					break
				fi
			done
		done
		# need to rehash commands other current bash will see old paths
		hash -r
	}

	# install a debian package and check if it already exists
	# the last parameters are fed directly to download_url and must match
	# usage: dpkg_install debian-package-name url [dest_file [dest_dir [md5 [sha256]]]]
	# the rest of the parameters are passed onto download_url
	dpkg_install() {
		if ! command -v dpkg >/dev/null; then return 1; fi
		if (($# < 2)); then return; fi
		local package="$1"
		local url="$2"
		local dest="${3:-"$(basename "$url")"}"
		local dest_dir="${4:-"$WS_DIR/cache"}"
		if dpkg-query -l | awk '{print $2}' | grep -q "^$package"; then
			return
		else
			shift
			download_url "$@"
		fi
		sudo dpkg -i "$dest_dir/$dest"
	}
	dpkg_is_installed() {
		if ! command -v dpkg >/dev/null; then return 1; fi
		declare -a flags
		if (($# < 1)); then return; fi
		# find all the flags at the start
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		for package in "$@"; do
			if command -v dpkg >/dev/null && dpkg -l "$package" &>/dev/null; then
				log_verbose "$package is in dpkg"
				if ! dpkg -s "$package" 2>/dev/null | grep -q "ok installed"; then
					log_verbose "$package not installed"
					((++count))
				fi
				continue
			fi
		done
	}

	# standalone installers
	#
	# pip_install is for packages that have code, for command line utilities use
	# pipx_install and it will install into your current python venv
	# we have one special flag -f which means run sudo and must be the first one
	# note that will not work as expected if you are poetry, so detect this
	# and do a poetry add instead
	# if already installed then upgrade it
	# usage: pip_install -f [python flags..] [packages...]
	pip_install() {
		if (($# < 1)); then return; fi
		log_verbose "in pip_install with $*"
		if ! command -v pip &>/dev/null; then return 1; fi
		declare -a flags
		local use_sudo=""
		while [[ $1 =~ ^- ]]; do
			# one flag is for us to force use of sudo
			if [[ $1 == -f ]]; then
				use_sudo=sudo
				shift
			fi
			# rest of flats we pass on to pip
			flags+=("$1")
			shift
		done
		for package in "$@"; do
			# note we pass flags unquoted  so each is a separate flag
			# conditionally run sudo if asked
			# shellcheck disable=SC2086
			# if [[ -v poetry_active ]]; then
			# 	log_verbose "in poetry do install instead of $package"
			# 	poetry add "$package"
			# else
			# note that we are not venv aware here that is too hard
			log_verbose "using pip at $(command -v pip) for $package"
			$use_sudo pip install "${flags[@]}" "$package"
			# fi
		done
	}

	# pipx is for cli toolsand it is installed in venv and then into
	# ~/.local/bin
	# usage: pipx_install [-i inject venv ] [-p python_path ] [packages...]
	pipx_install() {
		if (($# < 1)); then return; fi
		local python_version
		python_version="$(command -v python)"
		while [[ $1 =~ ^- ]]; do
			# one flag is for us to force use of sudo
			if [[ $1 == -p ]]; then
				shift
				if (($# > 0)); then
					python_version="$1"
					shift
				fi
			elif [[ $1 == -i ]]; then
				shift
				if (($# > 0)); then
					inject_env="$1"
					shift
				fi
			fi
		done
		for package in "$@"; do
			if [[ -v inject_env ]]; then
				# the tool list should be injected
				pipx inject "$inject_env" "$package"
			# the space ensures it is an exact match as version comes after
			elif pipx list --short | grep -q "^$package "; then
				pipx upgrade "$package"
			else
				pipx install --python "$python_version" "$package"
			fi
		done
	}
	## bundle_install org repo for vim bundles
	bundle_install() {
		if (($# != 2)); then
			return 1
		fi
		mkdir -p "$HOME/.vim/bundle"
		if [[ ! -e "$HOME/.vim/bundle/$2" ]]; then
			cd "$HOME/.vim/bundle" &&
				git clone "git@github.com:$1/$2"
		fi
	}
	## npm install first checks for existance always does a global
	## usage npm_install [-f force sudo ] [any flag that begins with - like -g] package1,...
	npm_install() {
		node_install "$@"
	}
	# node install is more general but calls npm install
	node_install() {
		if ! command -v npm >/dev/null; then return 1; fi
		if (($# < 1)); then return 0; fi
		declare -a flags
		local use_sudo=""
		# Look for and add for all flags beginning with a dash
		while [[ $1 =~ ^- ]]; do
			if [[ $1 == -f ]]; then
				use_sudo=sudo
			fi
			flags+=("$1")
			shift
		done
		for package in "$@"; do
			# https://ponderingdeveloper.com/2013/09/03/listing-globally-installed-npm-packages-and-version/
			# do not quote $flags so that each flag becomes a separate argument
			# again
			# shellcheck disable=SC2086
			if ! npm list --depth=0 "$package" >/dev/null 2>&1; then
				# try this without sudo
				# sudo npm install $flags $1
				# shellcheck disable=SC2086
				$use_sudo npm install "${flags[@]}" "$package"
			fi
			shift
		done
	}
	# usage: gem_install [ -flags.. ] [ ruby packages ]
	gem_install() {
		if ! command -v gem >/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		local flags=()
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		for package in "$@"; do
			if ! gem install "$package"; then
				sudo gem install "${flags[@]}" "$package"
			fi
		done
	}
	# Mercurial install into the current working directory
	# hg_install url_of_repo [parent_dir_of_local_repo]
	hg_install() {
		if ! command -v hg >/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		local url=$1
		local repo
		repo=$(basename "$url")
		local dir
		dir=${2:-"$WS_DIR/git"}
		mkdir -p "$dir"
		pushd "$dir" >/dev/null || return 1
		if [[ ! -d $repo ]]; then
			hg clone "$url" "$repo"
		else
			pushd "$repo" >/dev/null || return 1
			hg pull
			hg update
			popd >/dev/null || return 1
		fi
		popd >/dev/null || return 1
	}
	# install a modprobe package
	mod_install() {
		if ! command -v modprobe >/dev/null; then return 1; fi
		if (($# < 1)); then return; fi
		for mod in "$@"; do
			if ! lsmod | grep -q "$mod"; then
				sudo modprobe "$mod"
			fi
			if ! grep -q "^$mod" /etc/modules; then
				sudo tee -a /etc/modules <<<"$mod"
			fi
		done
	}

	# take md5 if non zero and check for it
	# if md5 is zero then check a non-zero sha256
	# check_sum file [ md5_checksum [sha256_checksum]]
	check_sum() {
		local dest=${1:-/dev/null}
		local md5=${2:-0}
		local sha256=${3:-0}
		# if no sum then we just say it works
		if [[ $md5 == 0 && $sha256 == 0 ]]; then
			return 0
		elif [[ $md5 != 0 && ($(md5sum "$dest" | cut -f1 -d' ') == "$md5") ]]; then
			return 0
		elif [[ $sha256 != 0 && ($(sha256sum "$dest" | cut -f1 -d' ') == "$sha256") ]]; then
			return 0
		fi
		return 1
	}

	# clone the repo into this file location
	# git_clone repo [location]
	# return code: 0 on success, 1 on failure
	# echos the location of the
	git_clone() {
		if (($# < 1)); then return 1; fi
		local repo="$1"
		local dest_dir="${2:-$WS_DIR/git}"
		local repo_path
		repo_path="$2/$(basename "$1")"
		if [[ ! -e $repo_path ]]; then
			git clone "$1" "$2"
		fi
	}

	# install_mac_app application [location]
	install_mac_app() {
		if [[ ! $OSTYPE =~ darwin ]]; then return 0; fi
		if (($# < 1)); then return 1; fi
		src="$1"
		dir="${2:-/Applications}"
		# move the app if it does not already exist
		if [[ ! -e "$dir/$(basename "$src")" ]]; then
			log_verbose "move $src to $dir"
			sudo mv "$src" "$dir"
		fi
	}

	# will always download unless the md5sum matches or sha256sum
	# To use sha256 add it as the last argument and it overrides
	# the md5 value
	# Also if we recognize the file type will process them
	# if it is a tar, will return the actual file(s) on stdout that
	# were extracted
	#
	# usage: download_url url [dest_file [dest_dir [md5 [sha256]]]]
	# returns: list of file extracted or downloaded
	download_url() {
		if (($# < 1)); then return 1; fi
		local url="$1"
		local dest_dir="${3:-"$WS_DIR/cache"}"
		local dest="${2:-$dest_dir/$(basename "$url")}"
		local md5="${4:-0}"
		local sha256="${5:-0}"

		log_verbose "download $url to $dest_dir as $dest"
		mkdir -p "$dest_dir"
		# If file exists and there is md5 sum, we assume the file download worked
		if [[ -e $dest ]]; then
			# if no md5 or sha supplied assume it worked
			# check_md5 succeeds on a zero so last test is
			# check_sha256
			if check_sum "$dest" "$md5" "$sha256"; then
				return 0
			fi
		fi
		# Use the resume feature to make sure you got it by first trying and if
		# http://www.cyberciti.biz/faq/curl-command-resume-broken-download/
		log_verbose "curl -C - -L $url -o $dest"
		mkdir -p "$dest_dir"
		if ! curl -C - -L "$url" -o "$dest"; then
			# if we fail see if the return code doesn't allow -C for resume and retry
			# Amazon AWS for instance doesn't allow resume and returns 31
			# Private Internet Access servers return 33 for same issue
			# but we cannot capture this return code because the if returns true
			# so we just do a retry without resume
			curl -L "$url" -o "$dest"
		fi
		check_sum "$dest" "$md5"
	}
	# download file and then attach or open as appropriate
	# this was  in lib-mac.sh
	# Usage: download_url_open url [[[file] [download_directory]] [destination_directory]]
	# But now is in lib-install.sh and uses download_url
	download_url_open() {
		if (($# < 1)); then return 1; fi
		local url="$1"
		log_verbose "url is $1"
		# http://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash
		local file="${2:-${url##*/}}"
		local dest="${3:-"$WS_DIR/cache"}"
		local target="${4:-"$dest"}"
		mkdir -p "$dest"
		local extension="${file##*.}"
		log_verbose "curl from $url to $dest/$file open $extension"
		log_verbose "go to $dest"
		pushd "$dest" >/dev/null || return 1
		download_url "$url" "$file" "$dest"
		log_verbose "download successful check what we got in $dest/$file looking at $extension"
		case "$extension" in
		deb)
			log_verbose
			sudo dpkg -i "$file"
			;;
		dmg)
			log_verbose mounting "$file"
			# do not mount if it has been already
			if ! hdiutil info | grep -q "$file"; then
				hdiutil attach "$file"
			fi
			;;
		vbox-extpack)
			open "$file"
			;;
		pkg)
			# packages can be batch installed
			log_verbose "package install $file"
			sudo installer -pkg "$file" -target /
			;;
		tar)
			tar xzf "$file" --directory "$target"
			;;
		gz)
			open "$file"
			;;
		app)
			log_verbose "Found $file as an app"
			install_mac_app "$file"
			;;
		zip)
			# unpack the file
			log_verbose "unzip $file into $target"
			unzip "$file" -d "$target"

			# If the file unpacked into an app move it
			local app="${file%.*}.app"
			log_verbose "Looking for $app"
			if [[ -e $app ]]; then
				log_verbose "try to install $app"
				install_mac_app "$app"
			fi
			# try again trying to strip version numbers and junk from name
			local app="${app%.*}.app"
			log_verbose "looking for $app"
			if [[ -e $app ]]; then
				log_verbose "try to install $app"
				install_mac_app "$app"
			fi
			directory="${file%.*}"
			log_verbose "is $directory a directory"
			if [[ -d $directory ]]; then
				log_verbose "$directory is a directory the user should try"
				return
			fi

			# check to see if this is a pkg
			# could be a hammerspoon. spoon file which self installs
			local spoon="${file%.*}"
			log_verbose "looking for $spoon"
			if [[ -e $spoon ]]; then
				open "$spoon"
			fi

			pref="${file%.*}.prefPane"
			log_verbose "Looking for $pref"
			if [[ -e $pref ]]; then
				install_mac_app "$pref" "/Library/PreferencePanes"
			fi
			# try again trying to strip version numbers and junk from name
			pref="${pref%_*}.prefPane"
			log_verbose "Looking for $pref"
			if [[ -e $pref ]]; then
				install_mac_app "$pref" "/Library/PreferencePanes"
			fi
			# https://stackoverflow.com/questions/407184/how-to-check-the-extension-of-a-filename-in-a-bash-script
			# https://apple.stackexchange.com/questions/72226/installing-pkg-with-terminal
			# see if the zip file is a package
			pkg="${file%.*}"
			log_verbose "Looking for $pkg"
			if [[ -e $pkg ]]; then
				log_verbose "trying pkg install of $pkg"
				sudo installer -pkg "$pkg" -target /
			fi
			;;
		esac
		popd >/dev/null || return 1
	}
	# usage: extract_tar tarfile
	# note tar returns to stdin all the files extract
	extract_tar() {
		if (($# < 1)); then return 1; fi
		local tar="$1"
		local files
		files=$(tar -tf "$tar")
		for file in $files; do
			# need to echo since the caller needs names of files
			# even if already extracted
			echo "$file"
			if [[ ! -e $file ]]; then
				tar -xf "$tar" "$file"
			fi
		done
	}
	# Downloads and checkes the pgp signature against the signer
	# https://www.gnupg.org/gph/en/manual/x135.html
	# usage: pgp_download $file_url $file_pgp_url $signer_url
	download_url_pgp() {
		if (($# < 3)); then return 1; fi
		local url
		url="$(eval echo "$1")"
		local signature_url
		signature_url="$(eval echo "$2")"
		local signer_url
		signer_url="$(eval echo "$3")"
		# does an eval if you have varible
		download_url "$url"
		download_url "$signature_url"
		download_url "$signer_url"
		file="$WS_DIR/cache/$(basename "$url")"
		signature="$WS_DIR/cache/$(basename "$signature_url")"
		signer="$WS_DIR/cache/$(basename "$signer_url")"
		gpg --import "$signer"
		if ! gpg --verify "$signature" "$file" 2>&1 | grep -q "Good signature"; then
			return 1
		fi
	}

fi
