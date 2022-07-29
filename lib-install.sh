#!/usr/bin/env bash
# vim: ai:sw=4:ts=4:noet
##
##Installation works on either Mac OS X (Darwin) or Ubuntu
##
## use package if the same package may be in brew, port, apt or snap
## package_install [-flags ] [packages...] - smart about not reinstalling
## package_uninstall [-flags] [packages...]
## is_package_installed [packages] - almost never needed install
##
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

	# install a apt-get package uses apt_run underneath
	apt_install() {
		apt_run install "$@"
	}
	apt_uninstall() {
		apt_run remove "$@"
	}
	apt_run() {
		local flags=()
		if ! command -v apt-get >/dev/null; then return 1; fi
		if (($# < 1)); then return 1; fi
		operation="$1"
		shift
		# find all the flags at the start
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		local failed
		for package in "$@"; do
			if apt list --installed "$package" | grep -q "$package" &&
				sudo apt-get "$operation" -y "${flags[@]}" "$package"; then
				((++failed))
			fi
		done
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
			# Need eval because of the $output
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
	## package_is_installed [packages...]
	## returns 0 if all the packages are installed
	## if no installed then returns how many packages were not installed
	# For home brew, make sure the thing is installed with the right
	# flags it will uninstall if the flags are wrong and return install needed
	package_is_installed() {
		local count=0
		# looks for the flags and makes sure they are installed, if not then do
		# assumes brew is up to date
		# just run overall brew so all flags can pass though
		local flags=()
		for item in "$@"; do
			if [[ ! $item =~ ^- ]]; then
				# break on the first non flag
				break
			fi
			flags+=("$item")
			shift
		done
		for package in "$@"; do
			log_verbose "looking for $package"
			# most of the time we have brew on linux, mac and wsl
			for packager in brew_package cask port dpkg; do
				if ! ${packager}_is_available; then
					continue
				fi
				if ${packager}_is_installed "${flags[@]}" "$package"; then
					((++count))
					break
				fi
			done
		done
		log_verbose "$count packages not installed"
		return "$count"
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
		local flags=()
		if (($# < 1)); then
			return
		fi
		# find all the flags at the start
		while [[ $1 =~ ^- ]]; do
			flags+=("$1")
			shift
		done
		local failures=0
		for package in "$@"; do
			# do not check flags so do not quote
			#shellcheck disable=SC2086
			log_verbose "no package $package, try to install"
			for packager in brew cask apt snap; do
				log_verbose "Trying ${packager}_install ${flags[*]}$ package"
				if ${packager}_is_available &&
					${packager}_install "${flags[@]}" "$package"; then
					((++failures))
				fi
			done
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
			for packager in cask brew port snap; do
				if ${packager}_uinstall "${flags[@]}" "$package"; then
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
		local flags=()
		if ! command -v dpkg >/dev/null; then return 1; fi
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

	# install python packages passing on flags
	# we have one special flag -f which means run sudo and must be the first one
	# usage: pip_install -f [python flags..] [packages...]
	pip_install() {
		if ! command -v pip >/dev/null; then return 1; fi
		local flags=()
		local use_sudo=""
		if (($# < 1)); then
			return
		fi
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
		log_verbose "PATH is $PATH"
		log_verbose "using pip at $(command -v pip)"
		for package in "$@"; do
			# note we pass flags unquoted  so each is a separate flag
			# conditionally run sudo if asked
			# shellcheck disable=SC2086
			$use_sudo pip install "${flags[@]}" "$package"
		done
	}

	## bundle_install org repo
	bundle_install() {
		if (($# != 2)); then
			return 1
		fi
		if [[ ! -e "$HOME/.vim/bundle/$2" ]]; then
			cd "$HOME/.vim/bundle" &&
				git clone "git@github.com:$1/$2"
		fi
	}

	## npm install first checks for existance always does a global
	## usage npm_install [-f force sudo ] [any flag that begins with - like -g] package1,...
	npm_install() {
		if (($# < 1)); then
			return 0
		fi
		local flags=()
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
		log_verbose "curl -C - -L $url -o $dest_dir/dest"
		mkdir -p "$dest_dir"
		if ! curl -C - -L "$url" -o "$dest_dir/$dest"; then
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
		if [[ ! $OSTYPE =~ darwin ]]; then return 0; fi
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
		pushd "$dest" >/dev/null || return 1
		download_url "$url" "$file" "$dest"
		case "$extension" in
		deb)
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
			sudo installer -pkg "$file" -target /
			;;
		tar)
			tar xzf "$file" --directory "$target"
			;;
		gz)
			open "$file"
			;;
		zip)
			# unpack the file
			log_verbose "unzip $file"
			unzip "$file" -d "$target"
			# If the file unpacked into an app move it
			local app="${file%.*}.app"
			if [[ -e $app ]]; then
				install_in_dir "$app"
			fi
			# try again trying to strip version numbers and junk from name
			app=${app%.*}.app
			if [[ -e $app ]]; then
				install_in_dir "$app"
			fi
			# could be a hammerspoon. spoon file which self installs
			local spoon=${file%.*}
			log_verbose "looking for $spoon"
			if [[ -e $spoon ]]; then
				open "$spoon"
			fi
			pref=${file%.*}.prefPane
			if [[ -e $pref ]]; then
				install_in_dir "$pref" "/Library/PreferencePanes"
			fi
			# try again trying to strip version numbers and junk from name
			pref=${pref%_*}.prefPane
			if [[ -e $pref ]]; then
				install_in_dir "$pref" "/Library/PreferencePanes"
			fi
			# check to see if this is a pkg
			# https://stackoverflow.com/questions/407184/how-to-check-the-extension-of-a-filename-in-a-bash-script
			# https://apple.stackexchange.com/questions/72226/installing-pkg-with-terminal
			# see if the zip file is a package
			pkg=${file%.*}
			if [[ -e $pkg ]]; then
				echo "trying pkg install of $pkg"
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
