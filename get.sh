#!/usr/bin/env bash
# One-line install (fork install, dram-parking branch):
#   curl -fsSL https://raw.githubusercontent.com/fguillotpro/inkling-2-mini-abliterated-ingine/dram-parking/get.sh | bash
# Clones this installer to ~/inkling-2-mini-abliterated-ingine (or $INGINE_DIR) and opens its menu: choose 1
# to install, then 3 to start the server. Running it again reopens the menu of the existing clone.
# INGINE_DIR, INGINE_REPO and INGINE_BRANCH override the default folder, repository and branch.
# Everything happens inside main, which runs only once this whole file has been downloaded.
set -euo pipefail

# Normalizes a github URL of any common form to the "owner/repo" pair — https:// (with or without .git,
# with or without a trailing slash), git@host:owner/repo (with or without a :port), ssh:// (with or without
# a :port), a bare owner/repo, and non-github hosts with any of those shapes. The install check compares on
# this key, not on raw URL text, so a clone made through either form overlaps a re-run made through another.
repo_path_of() {
  local repo="$1"
  repo="${repo%/}"
  repo="${repo%.git}"
  repo="${repo#*://}"
  repo="${repo#*@}"
  if [[ "$repo" =~ ^github\.com:[0-9]+/(.*)$ ]]; then
    repo="${BASH_REMATCH[1]}"
  elif [[ "$repo" =~ ^github\.com:(.*)$ ]]; then
    repo="${BASH_REMATCH[1]}"
  elif [[ "$repo" =~ ^github\.com/(.*)$ ]]; then
    repo="${BASH_REMATCH[1]}"
  elif [[ "$repo" == *:* ]]; then
    # scp-style host:owner/repo or host:port/owner/repo — drop the host, then a port segment
    repo="${repo#*:}"
    if [[ "$repo" =~ ^[0-9]+/(.*)$ ]]; then
      repo="${BASH_REMATCH[1]}"
    fi
  elif [[ "$repo" == */* && "$repo" != */*/* ]]; then
    :  # a bare owner/repo — leave unchanged
  else
    # host/owner/repo — drop the host segment
    repo="${repo#*/}"
  fi
  printf '%s' "$repo"
}

main() {
  local repo="${INGINE_REPO:-https://github.com/fguillotpro/inkling-2-mini-abliterated-ingine.git}"
  local branch="${INGINE_BRANCH:-dram-parking}"
  local dir="${INGINE_DIR:-$HOME/inkling-2-mini-abliterated-ingine}"
  local repo_path
  repo_path="$(repo_path_of "$repo")"

  if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "This installer needs Linux x86_64 with an NVIDIA RTX 5090." >&2
    exit 1
  fi
  if ! command -v git >/dev/null; then
    echo "git is required. Install it (sudo apt install git, sudo dnf install git or sudo pacman -S git), then run this again." >&2
    exit 1
  fi

  if [[ -e "$dir" ]]; then
    if [[ "$(repo_path_of "$(git -C "$dir" remote get-url origin 2>/dev/null)")" != "$repo_path" ]]; then
      echo "$dir exists and is not this installer. Choose another folder: curl ... | INGINE_DIR=/path/to/folder bash" >&2
      exit 1
    fi
    echo "Using the installer already in $dir (menu option 4 updates it)."
  else
    echo "Downloading the installer to $dir ($branch) ..."
    git clone --quiet --branch "$branch" "$repo" "$dir"
  fi

  # Piped into bash, standard input is this script, not the keyboard: give the menu the terminal.
  if ! { true </dev/tty; } 2>/dev/null; then
    printf 'No terminal for the menu. Run it yourself:\n  cd %q && bash setup.sh\n' "$dir"
    exit 0
  fi
  cd "$dir"
  exec bash setup.sh </dev/tty
}

# Run the installer when this file is executed (or piped in), not when it is sourced for its functions.
# When piped, ${BASH_SOURCE[0]} is unset (guarded); when executed, it equals $0.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
