# shellcheck shell=bash
# Terminal output for install.sh, uninstall.sh and doctor.sh. Source it; do not run it.
# Colors and animation are off when stdout is not a terminal, or when NO_COLOR or CI is set.
# WTF_NO_ANIM=1 turns off only the animation (spinner and typewriter).

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ -z "${CI:-}" ]; then
  UI_ANIM=1
  C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_CYAN=$'\033[36m'
else
  UI_ANIM=
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN=''
fi
if [ -n "${WTF_NO_ANIM:-}" ]; then UI_ANIM=; fi

ui_ok() { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
ui_warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
ui_fail() { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; }
ui_info() { printf '  %s· %s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# ui_logo TEXT: the logo, then the tagline that ends with TEXT ("v1.0.0" or "not installed").
ui_logo() {
  local row
  echo
  for row in \
    '╦ ╦╦╔═╗╔═╗╦═╗  ╔╦╗╔═╗╔═╗╔╦╗╦  ╦╦╔═╗╦ ╦╔═╗╦═╗  ╔═╗╦═╗ ╦' \
    '║║║║╚═╗╠═╝╠╦╝   ║ ║╣ ╠═╣║║║╚╗╔╝║║╣ ║║║║╣ ╠╦╝  ╠╣ ║╔╩╦╝' \
    '╚╩╝╩╚═╝╩  ╩╚═   ╩ ╚═╝╩ ╩╩ ╩ ╚╝ ╩╚═╝╚╩╝╚═╝╩╚═  ╚  ╩╩ ╚═'; do
    printf '  %s%s%s\n' "$C_BOLD$C_CYAN" "$row" "$C_RESET"
  done
  printf '  %spaste fix for Wispr Flow in TeamViewer · %s%s\n\n' "$C_DIM" "${1:-}" "$C_RESET"
}

# ui_path PATH: PATH with $HOME shown as ~.
ui_path() {
  case "$1" in
    "$HOME"/*) printf '%s%s\n' '~' "${1#"$HOME"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# ui_installed_version BIN: "v1.0.0" from BIN --version, or "not installed". Never fails.
ui_installed_version() {
  local v=''
  if [ -x "$1" ]; then v=$("$1" --version 2>/dev/null) || v=''; fi
  v=${v##* }
  if [ -n "$v" ]; then echo "v$v"; else echo "not installed"; fi
}

_ui_now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time' 2>/dev/null || date +%s; }

_UI_PID='' _UI_OUT=''
# shellcheck disable=SC2317  # called by trap; older shellcheck flags it as unreachable
_ui_spin_abort() {
  kill "$_UI_PID" 2>/dev/null || true
  rm -f "$_UI_OUT"
  printf '\r\033[K\033[?25h'
  exit 130
}

# ui_spin MSG [SPIN_MSG] -- CMD...: run CMD with a spinner that shows SPIN_MSG (default MSG).
# Success prints "✓ MSG (1.8s)". Failure prints "✗ SPIN_MSG failed" and the output of CMD.
# Returns the exit code of CMD.
ui_spin() {
  local msg=$1 label=$1 start secs rc=0 i=0
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  shift
  if [ "${1:-}" != "--" ]; then
    label=$1
    shift
  fi
  shift
  _UI_OUT=$(mktemp "${TMPDIR:-/tmp}/wtf-spin.XXXXXX")
  start=$(_ui_now)
  if [ -n "$UI_ANIM" ]; then
    "$@" >"$_UI_OUT" 2>&1 </dev/null &
    _UI_PID=$!
    trap _ui_spin_abort INT TERM HUP
    printf '\033[?25l'
    while kill -0 "$_UI_PID" 2>/dev/null; do
      printf '\r  %s%s%s %s' "$C_CYAN" "${frames[i % 10]}" "$C_RESET" "$label"
      i=$((i + 1))
      sleep 0.08
    done
    wait "$_UI_PID" || rc=$?
    trap - INT TERM HUP
    printf '\r\033[K\033[?25h'
  else
    "$@" >"$_UI_OUT" 2>&1 </dev/null || rc=$?
  fi
  secs=$(awk -v a="$start" -v b="$(_ui_now)" 'BEGIN { printf "%.1f", b - a }')
  if [ "$rc" -eq 0 ]; then
    ui_ok "$msg ${C_DIM}(${secs}s)${C_RESET}"
  else
    ui_fail "$label failed"
    sed 's/^/    /' "$_UI_OUT"
  fi
  rm -f "$_UI_OUT"
  return "$rc"
}

# ui_typewriter TEXT: show a bare "v" at a remote prompt (the bug), then type TEXT over it (the fix).
ui_typewriter() {
  local text=$1 prompt i=0
  prompt="  ${C_DIM}remote>${C_RESET} "
  if [ -z "$UI_ANIM" ]; then
    printf '%s%s\n' "$prompt" "$text"
    return 0
  fi
  printf '%sv' "$prompt"
  sleep 0.6
  printf '\b \b'
  while [ "$i" -lt "${#text}" ]; do
    printf '%s' "${text:i:1}"
    sleep 0.025
    i=$((i + 1))
  done
  printf '\n'
}
