# shellcheck shell=sh
# Keep the lab help command ahead of shell builtins such as BusyBox ash's help.
help() {
  /usr/local/bin/lab-help-command "$@"
}

# BusyBox ash reads ENV for subsequent interactive, non-login shells.
export ENV=/etc/profile.d/lab-commands.sh
