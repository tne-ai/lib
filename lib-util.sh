#!/usr/bin/env bash
##
## utility functions for @rich
## Note that in these libraries you should not assume include.sh is loaded
## So do not use log_verbose etc.
##

## Note the if makes sure we only source once which is more efficient
# create a variable that is just the filename without an extension
lib_name="$(basename "${BASH_SOURCE%.*}")"
# dashes are not legal in bash names
lib_name=${lib_name//-/_}
#echo trying $lib_name
# This is how to create a pointer by reference in bash so
# it checks for the existance of the variable named in $lib_name
# not how we use the escaped $ to get the reference
#echo eval [[ -z \${$lib_name-} ]] returns
#eval [[ -z \${$lib_name-} ]]
#echo $?
if eval "[[ ! -v $lib_name ]]"; then
  # how to do an indirect reference
  eval "$lib_name=true"

  util_disk_used() {
    df -k . | sed 1d | awk 'FNR == 1 {print $5}' | cut -f 1 -d "%"
  }

  # https://www.theunixschool.com/2012/04/different-ways-to-print-first-line-of.html
  # ttps://unix.stackexachange.com/questions/108250/print-the-string-between-two-parentheses
  # https://unix.stackexchange.com/questions/293940/how-can-i-make-press-any-key-to-continue
  # https://www.cyberciti.biz/faq/howto-find-linux-vga-video-card-ram/
  util_gpu_memory() {
    if mac_is_arm; then
      echo $(($(sysctl -n hw.memsize) / 2 ** 30))
    elif has_nvidia; then
      lspci -v -s "$(lspci | grep NVIDIA | cut -f 1 -d ' ')" | grep 64-bit | awk -F "[=G]" 'NR==1 {print $2}'
    else # no idea
      echo 0
    fi
  }

  # returns the variable key
  util_press_key() {
    read -n1 -r -p "Press anything to continue.." key
    export key
  }

  # look for a file name with a string complicated because there is not a name default
  # the default is to look for Google Drive somewhere in the name
  # if there are multiple accocunts
  # echos the drives found on stdout
  # returns 0 if files found, 1 if not files are found
  util_find() {
    local result
    local text
    if (($# > 1)); then
      text="$*"
    else
      text="Google Drive"
    fi
    result=$(find -L "$HOME" -maxdepth 2 -name \*"$text"\* 2>/dev/null)
    echo "$result"
    # https://stackoverflow.com/questions/6314679/in-bash-how-do-i-count-the-number-of-lines-in-a-variable
    # no each way to coerce count to a integer return code
    if [[ -z $result ]]; then
      return 1
    fi
  }

  # run github command and enable verbose and echo for dry run
  # this require lib-log.sh
  # usage util_git_cmd [-s] [-n] "cmd and repos"
  # -n dry_run command
  util_git_cmd() {
    local prefix_cmd=""
    local dry_run=""
    log_verbose "util_git_cmd"
    while [[ $1 =~ ^- ]]; do
      log_verbose "flag $1"
      if [[ $1 == "-s" ]]; then
        prefix_cmd="git submodule foreach --recursive"
      elif [[ $1 == "-n" ]]; then
        dry_run=" echo "
      fi
      shift
    done
    # convert arguments back to an array
    # need to do the eval so to force variable parsing
    # shellcheck disable=SC2086
    log_verbose "run prefix_cmd=$prefix_cmd dry_run=$dry_run args=$*"
    log_verbose "run eval $prefix_cmd $dry_run $*"
    # shellcheck disable=SC2086
    if ! eval "$prefix_cmd $dry_run $*"; then
      log_error 20 "Failed with $?: $prefix_cmd $*"
    fi
  }

  # usage: util_sudo [-u user ] [files to be accessed]
  # return the text "sudo" if any of the files are not writeable
  # example: eval $(util_sudo_if /Volumes) mkdir -p /Volumes/<ext>
  util_sudo_if() {
    # https://www.cyberciti.biz/faq/unix-linux-shell-scripting-test-if-filewritable/
    user=root
    if [[ $1 == -u ]]; then
      shift
      user="$1"
      shift
    fi

    for file in "$@"; do
      if [[ ! -w $file ]]; then
        echo sudo -u "$user"
        break
      fi
    done
  }

  # usage: util_group file
  # returns on stdout the
  # https://superuser.com/questions/581989/bash-find-directory-group-owner
  util_group() {
    if (($# == 0)); then return 1; fi
    if [[ $OSTYPE =~ darwin && $(command -v stat) =~ /usr/bin/stat ]]; then
      local flags="-f %Sg"
    else
      local flags="-c %G"
    fi
    # shellcheck disable=SC2086
    stat $flags "$@"
  }

  # backup a file keep iterating until you find a free name
  # usage: util_backup files..
  util_backup() {
    for file in "$@"; do
      if [[ ! -e $file ]]; then
        continue
      fi
      i=""
      while :; do
        backup="$file$i.bak"
        if [[ ! -e $backup ]]; then
          cp "$file" "$backup"
          break
        fi
        # if diff is true then the files are the same we do not need to
        # backup
        if diff "$file" "$backup" >/dev/null; then
          break
        fi
        ((++i))
      done
    done
  }

  # check if a directory is empty
  # usage: dirempty [directory list...]
  # returns: 0 if all are empty, error code is number of subdirectory entries
  dir_empty() {
    if (($# == 0)); then return 0; fi
    local dirs="$1"
    count="$(find . -name "$dirs" | wc -l)"
    return "$count"
  }

  # takes the standard input and adds pretty spaces
  # and an indent
  # usage: indent_output amount_of_indent
  # https://unix.stackexchange.com/questions/148109/shifting-command-output-to-the-right
  indent_output() {
    local indent=${1:-8}
    tr "[:blank:] " "\n" | nl -bn -w "$indent"
  }

  # usage: in_ssh returns 0 if in an ssh session
  # need the the - syntax to prevent -u from calling SSH_CLIENT unbounded
  in_ssh() {
    if [[ -n ${SSH_CLIENT-} || -n ${SSH_TTY-} ]]; then
      return 0
    else
      return 1
    fi
  }

  # usage: promot_user questions bash_command
  prompt_user() {
    if (($# < 2)); then return 1; fi
    local question="$1"
    local cmd="$2"
    # https://stackoverflow.com/questions/2642585/read-a-variable-in-bash-with-a-default-value
    # http://wiki.bash-hackers.org/commands/builtin/read
    # -e means if stdin from a terminal use readline so more features on input
    # -i sets default requires -e
    # -t times out so this still works in batch mode
    # -r disables escapes
    read -re -t 5 -i Yes -p "$question? " response
    # the ,, makes it lower case
    if [[ ${response,,} =~ ^y ]]; then
      # https://unix.stackexchange.com/questions/296838/whats-the-difference-between-eval-and-exec
      eval "$cmd"
    fi
  }

  has_nvidia() {
    if [[ $OSTYPE =~ linux ]] && lspci | grep -q 'NVIDIA'; then
      return 0
    else
      return 1
    fi
  }

  # use the test to avoid set -e problems
  in_vmware_fusion() {
    if [[ $OSTYPE =~ linux ]] && lspci | grep -q VMware; then
      return 0
    else
      return 1
    fi
  }

  # linux service start and restart
  service_start() {
    local svc=${1:-docker}
    local state
    state=$(sudo service "$svc" status)
    case "$state" in
    *running*)
      # Try upstart first, if it fails try systemd
      if ! sudo service "$svc" restart; then
        sudo systemctl restart "$svc"
      fi
      ;;
    *stop*)
      if ! sudo service "$svc" start; then
        sudo systemctl start "$svc"
      fi
      ;;
    *)
      # strange state $svc for $state just return
      ;;
    esac
  }

  # parse out the semantic to how many digits
  # usage: semver -[1|2|3] how many -1 is major, -2 add minor, -3 add path
  # log_verbose "loaded util_semver"
  util_semver() {
    local fields="1,2,3"
    if (($# > 0)); then
      if [[ $1 == -1 ]]; then fields="1"; fi
      if [[ $1 == -2 ]]; then fields="1,2"; fi
    fi
    # sed to get rid of anything strings after the third digit
    # tr get rid of everything that is not a digit or a period with -c
    sed -E 's/([0-9]+)\.([0-9]+).([0-9]+).*/\1.\2.\3/' |
      tr -cd '[:digit:].' | cut -d '.' -f "$fields"
  }

  linux_distribution() {
    if [[ $(uname) =~ Linux ]]; then
      lsb_release -i | awk '{print $3}' | tr '[:upper:]' '[:lower:]'
    fi
  }

  # linux_model: returns the model of the machine as manufacturer is set to Notebook
  # typical model is NV14J for Juno Neptune 14J
  linux_model() {
    if command -v dmidecode >/dev/null; then
      sudo dmidecode -t system | awk 'BEGIN { FS = ":" }; /Product Name/{print $2}'
    fi
  }

  ## in_linux [ ubuntu | debian ]: returns 0 if that is the distribution
  in_linux() {
    if (($# < 1)); then
      return 0
    fi
    if ! command -v linux_distribution &>/dev/null; then
      # lower case test since WSL Distro has initial caps
      if in_wsl && [[ ${WSL_DISTRO_NAME,,} =~ ${1,,} ]]; then
        return 0
      fi
    elif [[ $(linux_distribution) =~ ${1,,} ]]; then
      return 0
    fi

    return 1
  }

  # usage: linux_version
  linux_version() {
    lsb_release -r | cut -f 2
  }

  # usage: linux_codename
  linux_codename() {
    # echo $(linux_distribution)
    case $(linux_distribution) in
    ubuntu)
      # echo ubuntu
      # echo $(linux_version)
      case $(linux_version) in
      22.04)
        echo jammy
        ;;
      21.10)
        echo impish
        ;;
      21.04)
        echo hirsute
        ;;
      20.10*)
        echo groovy
        ;;
      20.04*)
        echo focal
        ;;
      19.10*)
        echo eoam
        ;;
      19.04*)
        echo disco
        ;;
      18.10*)
        echo cosmic
        ;;
      18.04*)
        echo bionic
        ;;
      17.10*)
        echo artful
        ;;
      17.04*)
        echo zesty
        ;;
      16.10*)
        echo yakkety
        ;;
      16.04*)
        echo xenial
        ;;
      15.10*)
        echo wily
        ;;
      15.04*)
        echo vivid
        ;;
      14.10*)
        echo utopic
        ;;
      14.04*)
        echo trusty
        ;;
      13.10*)
        echo saucy
        ;;
      13.04*)
        echo raring
        ;;
      12.10*)
        echo quantal
        ;;
      12.04*)
        echo precise
        ;;
      11.10*)
        echo oneiric
        ;;
      11.04*)
        echo natty
        ;;
      *)
        # echo not found
        return 1
        ;;
      esac
      ;;

    debian)
      # echo debian
      # https://en.wikipedia.org/wiki/Debian_version_history
      case $(linux_version) in
      13*)
        echo trixie
        ;;
      12*)
        echo bookworm
        ;;
      11*)
        echo bullseye
        ;;
      10*)
        echo buster
        ;;
      9*)
        echo stretch
        ;;
      8*)
        echo jessie
        ;;
      7*)
        echo wheezy
        ;;
      6*)
        echo squeeze
        ;;
      *)
        # echo not found
        return 1
        ;;
      esac
      ;;
    esac

  }

  # usage desktop_environment
  # returns [[ xfce || gnome || ubuntu ]]
  # https://unix.stackexchange.com/questions/116539/how-to-detect-the-desktop-environment-in-a-bash-script
  desktop_environment() {
    if [[ ! $OSTYPE =~ linux ]]; then
      return
    # need the {-} construction so that when XDG is unbound we do not generate
    # an error deprecated use the new -v to detect variables
    elif in_ssh; then
      return
    elif [[ -v XDG_CURRENT_DESKTOP ]]; then
      echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    elif [[ -v XDG_DATA_DIRS ]]; then
      echo "$XDG_DATA_DIRS" | grep -Eo 'xfce|kde|gnome|unity'
    fi
  }

  util_os() {
    case $OSTYPE in
    darwin*)
      echo mac
      ;;
    linux*)
      # https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
      if [[ -e /.dockerenv ]]; then
        # assume this is linux
        echo docker
      else
        echo linux
      fi
      ;;
    # this is MSYS2 or Git for Widnows or MingW64 gnu on Cygwin
    msys*)
      echo windows
      ;;
    esac
  }

  # Usage: in_os [ mac | windows | linux | docker ]
  in_os() {
    if (($# < 1)); then
      return 0
    fi
    if [[ ! $(util_os) =~ $1 ]]; then
      return 1
    fi
  }

  # Usage: in_wsl returns true if running in Windows Subsystem for Linux
  in_wsl() {
    if [[ ! -v WSL_DISTRO_NAME ]]; then
      return 1
    fi
  }

  # https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
  # Usage is_command [command list]
  # return 1 if any of these commands do not exist
  is_command() {
    for cmd in "$@"; do
      if ! command -v "$cmd" &>/dev/null; then
        return 1
      fi
    done
  }

  # determine the location of the stow subdirectory as a dot delimited string
  # usage: util_full_version
  # stdout returns the normalized full name os.arch for mac
  # for linux returns os.major.minor.arch
  util_full_version() {
    case $OSTYPE in
    darwin*)
      # darwin version is simpler than the Macos version
      # https://en.wikipedia.org/wiki/MacOS
      # Note that 16 = Sierra, 15=El Capitan,...
      # https://stackoverflow.com/questions/9913942/check-version-of-os-then-issue-a-command-if-the-correct-version
      # But we use the user visible version
      # and M1 vs Intel is so important we promote this up
      echo "macos.$(uname -m).$(sw_vers -productVersion)"
      ;;
    linux*)
      # architecture is last here as most linux configs do not care
      echo "linux.$(linux_distribution).$(linux_version).$(uname -m)"
      ;;
    *)
      return 1
      ;;
    esac
  }

  # run a file if it exists
  run_if() {
    if (($# < 1)); then
      return 1
    fi
    if [[ -r $1 ]]; then
      "$SHELL" "$@"
    fi
  }

  # machine independent open a url in a browser
  # util_web_open url
  util_web_open() {
    if in_os mac; then
      open "$@"
    elif in_os linux; then
      xdg-open "$@"
    fi
  }

fi
