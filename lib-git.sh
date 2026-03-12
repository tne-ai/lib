#!/usr/bin/env bash
##
##
## helper functions for git management
## @author rich
##
##

## returns echos the current default branch
# https://stackoverflow.com/questions/28666357/git-how-to-get-default-branch
# a longer version
# basename "$(git symbolic-ref --short refs/remotes/origin/HEAD)"
# usage: git_default_branch [remote]
git_default_branch() {
	remote=origin
	if (($# >= 1)); then
		remote="$1"
	fi
	git remote set-head "$remote" --auto >/dev/null 2>&1 || true
	basename "$(git rev-parse --abbrev-ref "$remote/HEAD")"

}

## git_repo tells you if you are in a git repo
## git_repo [ directory to check default to $PWD ]
# shellcheck disable=SC2120
git_repo() {
	dir="$PWD"
	if (($# >= 1)); then
		dir="$1"
	fi
	# https://davidwalsh.name/detect-git-directory
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		exit 1
	fi
}

## git_get_org returns as a string the name of the organization for this repo
## git_organization [ directory to check ]
git_organization() {
	# this needs to change when you fork the repo
	# first get the front half
	dir="$PWD"
	# if there is an argument use it
	if (($# >= 1)); then
		dir="$1"
	fi

	if [[ ! -e $dir ]]; then
		return
	fi

	if ! pushd "$dir" >/dev/null; then
		return 1
	fi
	org="$(git remote get-url origin)"
	# expect a string like http://github.com/org/repo or
	# git@github.com:org/repo
	# strip off up the last slash and only up to there and only up to there
	# https://stackoverflow.com/questions/10535985/how-to-remove-filename-prefix-with-a-posix-shell
	# https://www.linuxjournal.com/content/pattern-matching-bash
	# remove up to the first slash you find
	org="${org%/*}"
	org="${org##*[:/]}"
	if ! popd >/dev/null; then
		return 2
	fi

	echo "$org"
}

## git_set_ssh repo switch the remote pull to ssh from https
## https://gist.github.com/m14t/3056747
## usage: git_set_ssh repo path_to_git
git_set_ssh() {
	local repo=${1:-"$src"}
	local git_dir=${2:-"$WS_DIR/git"}
	if ! cd "$git_dir/$repo"; then
		return 1
	fi
	if ! git status; then
		echo >&2 "${FUNCNAME[*]}: ${repo[*]} is not a git repo"
		return 1
	fi
	local url
	url=$(git remote -v | grep -m1 '^origin' | sed -Ene's#.*(https://[^[:space:]]*).*#\1#p')
	if [[ -z $url ]]; then
		log_verbose "$repo already uses ssh"
		return 0
	fi
	git remote set-url origin "git@github.com:${url#https://github.com/}"
	if ! cd -; then
		return 2
	fi

}

## git_set_config variable value
git_set_config() {
	if (($# != 2)); then
		return 1
	fi
	if ! git config --get "$1"; then
		git config --global "$1" "$2"
	fi
}

## git_validate_repo_path: pushd into a path and verify it's a git repo.
## Replaces the common pushd + git_repo boilerplate pattern.
## usage: git_validate_repo_path <path>
git_validate_repo_path() {
	local path="${1:?usage: git_validate_repo_path <path>}"
	if ! pushd "$path" >/dev/null; then log_error 1 "no $path"; fi
	log_verbose "in $PWD"
	# shellcheck disable=SC2119
	if ! git_repo; then log_error 2 "$path is not a git repo"; fi
}

## git_ensure_on_branch: if HEAD is detached, switch to default branch.
## Echoes the current branch name on success.
## usage: git_ensure_on_branch [remote] [dry_run]
git_ensure_on_branch() {
	local remote="${1:-origin}" dry_run="${2:-}"
	local current_branch
	current_branch=$(git branch --show-current)
	if [[ -z "$current_branch" ]]; then
		local def_branch
		def_branch=$(git_default_branch "$remote")
		log_verbose "$(basename "$PWD"): detached HEAD, switching to $def_branch"
		if ! $dry_run git switch "$def_branch"; then return 1; fi
		current_branch="$def_branch"
	fi
	echo "$current_branch"
}

## git_foreach_submodule: iterate over all submodules recursively,
## calling a callback function for each one.
## The callback receives the submodule absolute path as $1.
## usage: git_foreach_submodule <callback>
git_foreach_submodule() {
	local callback="${1:?usage: git_foreach_submodule <callback>}"
	while IFS= read -r submod_path; do
		[[ -z "$submod_path" ]] && continue
		if ! pushd "$submod_path" >/dev/null; then
			log_verbose "warning: cannot enter $submod_path, skipping"
			continue
		fi
		"$callback" "$submod_path" || true
		popd >/dev/null || true
	done < <(git submodule foreach --recursive --quiet 'pwd' 2>/dev/null)
}

## usage: git_install_or_update [-f] repo [user [ destination ]]
##
## examples git_install_or_update -f src
##          git_install_or_update rpi-motion-mmal jritsma
##          git_install_or_update flash hypriot "$WS_DIR/cache"
##          git_install_or_update "https://gist.github.com/schickling/2c48da462a7def0a577e" schickling docker-machine-import-export
## returns: 0 for success, 1 for failure
## output: location of repo
##
git_install_or_update() {
	local return_code=0

	if (($# < 1)); then
		echo >&2 "${FUNCNAME[*]}: missing repo to update"
		return_code=1
	fi

	# -f means force reset to origin/master
	if [[ $1 == -f ]]; then
		git_command='git fetch --all &&
				 git reset --hard origin/master >/dev/null &&
				 git checkout master &&
				 git pull'
		shift
	else
		# handles the case that we are in detached head mode
		# http://git-blame.blogspot.com/2013/06/checking-current-branch-programatically.html
		git_command='if ! git symbolic-ref HEAD;
				 then
					 git checkout master >/dev/null;
				 fi &&
				 git pull >/dev/null'
	fi
	if [[ $1 =~ ^https ]]; then
		local repo="${2:-$(basename "$1")}"
		local full_repo_name="$1"
	else
		local repo=$1
		local full_repo_name="${2:-"richtong"}/$1"
	fi
	local git_dir="${3:-"$WS_DIR/git"}"

	mkdir -p "$git_dir"

	if cd "$git_dir/$repo" &>/dev/null; then
		if ! eval "$git_command" &>/dev/null; then
			echo >&2 "${FUNCNAME[*]}: in $repo, $git_command failed"
			return_code=2
		fi
		if ! cd - >/dev/null; then
			return 3
		fi
	elif cd "$git_dir" &>/dev/null; then
		if [[ ! $full_repo_name =~ ^https ]]; then
			full_repo_name="git@github.com:$full_repo_name"
		fi

		if ! git clone "$full_repo_name" "$repo" &>/dev/null; then
			echo >&2 "${FUNCNAME[*]}: git clone $full_repo_name failed"
			return_code=3
		fi
		if ! cd - &>/dev/null; then
			return 4
		fi
	else
		echo >&2 "${FUNCNAME[*]}: no $git_dir found"
		return_code=4
	fi
	echo "$git_dir/$repo"
	return "$return_code"
}
