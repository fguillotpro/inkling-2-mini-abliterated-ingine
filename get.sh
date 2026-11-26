#!/usr/bin/env bash
# One-line install (fork install, dram-parking branch):
#   curl -fsSL https://raw.githubusercontent.com/fguillotpro/inkling-2-mini-abliterated-ingine/dram-parking/get.sh | bash
# Clones this installer to ~/inkling-2-mini-abliterated-ingine (or $INGINE_DIR) and opens its menu: choose 1
# to install, then 3 to start the server. Running it again reopens the menu of the existing clone.
# INGINE_DIR, INGINE_REPO and INGINE_BRANCH override the default folder, repository and branch.
# Everything happens inside main, which runs only once this whole file has been downloaded.
set -euo pipefail

main() {
  local repo="${INGINE_REPO:-https://github.com/fguillotpro/inkling-2-mini-abliterated-ingine.git}"
  local branch="${INGINE_BRANCH:-dram-parking}"
  local dir="${INGINE_DIR:-$HOME/inkling-2-mini-abliterated-ingine}"
  local repo_path="${repo#*github.com/}"
  repo_path="${repo_path%.git}"

  if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "This installer needs Linux x86_64 with an NVIDIA RTX 5090." >&2
    exit 1
  fi
  if ! command -v git >/dev/null; then
    echo "git is required. Install it (sudo apt install git, sudo dnf install git or sudo pacman -S git), then run this again." >&2
    exit 1
  fi

  if [[ -e "$dir" ]]; then
    if [[ "$(git -C "$dir" remote get-url origin 2>/dev/null)" != *"$repo_path"* ]]; then
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

main "$@"
