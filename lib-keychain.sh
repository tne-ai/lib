#!/usr/bin/env bash
# vi: se ts=4 sw=4 et
##
## use the openssh keychain if native OS provide keyring does
## not provide it
## On mac's the El Capitan and later native keychain supports id_ed25519
## On Ubuntu 22.04 and later the native Gnome keyring supports id_ed25519

## usage use_openssh_keychain [key1 key2...]
## if no parameters, look for all i .ssh 
## returns 0 if no reboot required other wise returns 1
use_openssh_keychain() {
	local no_keychain_found=0
	local KEYS

	# only for linux systems
	if [[ ! $OSTYPE =~ linux ]]; then
		return
	fi

    if (( $# == 0 )); then
		mapfile -d '' KEYS < <(find "$HOME/.ssh" -name "*id_ed25519" -o -name "*id_rsa")
	else
		KEYS=("$@")
	fi

	# disable the Gnome keyring not compatible with id_ed25519 keys 2016 or earlier
	# https://www.google.com/search?q=gnome+keyring+id_25519&oq=gnome+keyring+id_25519&aqs=chrome..69i57j33i160l4.6846j0j4&client=ubuntu&sourceid=chrome&ie=UTF-8
	# do not need to disable gnome keyring if present, just start keychain 2017 or later
	# and point the SSH_AUTH_SOCK to it
	# note this does not work on Ubuntu, you cannot just kill the gnome keyring"
	# if [[ ! $(lsb_release -d) =~ Ubuntu ]]  && set | grep -q "^SSH_AUTH_SOCK=.*keyring"
	# then
	#    if pgrep ssh-agent
	#    then
	#       pkill ssh-agent
	#   fi
	# fi

	# keychain will start if it isn't already and running eval will mean we use it instead of the
	# gnome keyring and if the keys requested are not there it will add them
	eval "$(keychain --eval "${KEYS[@]}")"

	# The daemon has keyring if it gnome keyring, it has agent if it is keychain
	#if [[ -z $SSH_AUTH_SOCK || ! $SSH_AUTH_SOCK =~ agent ]]
	#then
	# keychain will ignore if they are already present
	#   eval "$(keychain --eval $@)"
	# if no keychain is found, you need to eval the keychain --eval command or
	# have it at boot up.
	#     no_keychain_found=1
	#else
	#    ssh-add $@
	# fi

	# We should not ever need this as the logic above should handle
	# But if it fails this is @jmc's fall back search
	if [[ -z $SSH_AUTH_SOCK ]]; then
		# Use the ssh-agent if it is active
		# Normally prebuild.sh should add the keychain and ssh-add to the .bash_profile
		# But if it doesn't, we manually go through looking for the right agent
		agents=()
		# this prevents problems per Shellcheck SC2207
		# https://github.com/koalaman/shellcheck/wiki/SC2207
		IFS=" " read -r -a agents <<<"$(find /tmp/ssh-* -user "$USER" -name 'agent.*' -print 2>/dev/null)"

		for agent in "${agents[@]}"; do
			if [[ ! -r $agent ]]; then
				continue
			fi
			for KEY in "${KEYS[@]}"; do

				if SSH_AUTH_SOCK="$agent" ssh-add -l | grep -q "$KEY"; then
					continue
				fi
			done
			export SSH_AUTH_SOCK="$agent"
			break
		done
	fi
	return $no_keychain_found
}
