#!/usr/bin/env bash
# dockage — Interactive UI (bash select → text fallback)
# No whiptail dependency. Select uses arrow keys + Enter natively.
set -euo pipefail

# ── Detection ────────────────────────────────
# Interactive: stdin is a real terminal (not pipe/CI)
ui::interactive() { [ -t 0 ]; }

# ── Menu: returns selected item key ──────────
ui::menu() {
  local title="$1"; shift
  local -a keys=() labels=()
  while [ $# -gt 1 ]; do
    keys+=("$1")
    labels+=("$2")
    shift 2
  done

  if ! ui::interactive; then
    # Plain text (pipe/CI)
    echo "=== $title ===" >&2
    for i in "${!keys[@]}"; do
      echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
    done
    printf "Choice: " >&2; read -r choice
    local idx=$((choice - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ] && echo "${keys[$idx]}"
    return
  fi

  # Bash select with arrow keys
  echo "  $title" >&2
  echo "" >&2
  PS3="  Choose: "
  select _ in "${labels[@]}"; do
    if [ -n "$REPLY" ] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#keys[@]}" ]; then
      echo "${keys[$((REPLY-1))]}"
      break
    fi
  done
}

# ── Radiolist: returns selected item key ─────
ui::radiolist() {
  local title="$1"; shift
  local -a keys=() labels=()
  while [ $# -gt 2 ]; do
    keys+=("$1")
    labels+=("$2")
    shift 3
  done

  if ! ui::interactive; then
    # Plain text
    echo "=== $title ===" >&2
    for i in "${!keys[@]}"; do
      echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
    done
    printf "Choice: " >&2; read -r choice
    local idx=$((choice - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ] && echo "${keys[$idx]}"
    return
  fi

  # Bash select with arrow keys
  echo "  $title" >&2
  echo "" >&2
  local -a display=()
  for i in "${!keys[@]}"; do
    display+=("${keys[$i]} — ${labels[$i]}")
  done
  PS3="  Choose: "
  select _ in "${display[@]}"; do
    if [ -n "$REPLY" ] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#keys[@]}" ]; then
      echo "${keys[$((REPLY-1))]}"
      break
    fi
  done
}

# ── Input box ───────────────────────────────
ui::input() {
  local prompt="$2"
  if ! ui::interactive; then
    printf "%s: " "$prompt" >&2
    read -r val
    echo "$val"
    return
  fi
  printf "  %s: " "$prompt" >&2
  read -r val
  echo "$val"
}

# ── Yes/No confirm ─────────────────────────
ui::confirm() {
  if ! ui::interactive; then
    printf "%s [y/N] " "$*" >&2
    read -r resp
    [[ "$resp" =~ ^[yY] ]]
    return
  fi
  printf "  %s [y/N] " "$*" >&2
  read -r resp
  [[ "$resp" =~ ^[yY] ]]
}

# ── Message box ────────────────────────────
ui::msgbox() {
  local title="$1"; shift
  if ! ui::interactive; then
    echo "=== $title ===" >&2
    echo "$*" >&2
    return
  fi
  echo "=== $title ===" >&2
  echo "$*" >&2
  printf "  Press Enter to continue." >&2
  read -r
}

# ── Info alias ─────────────────────────────
ui::info() { ui::msgbox "Info" "$*"; }
