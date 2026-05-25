#!/usr/bin/env bash
# dockage — Interactive UI (whiptail with text fallback)
set -euo pipefail

# ── Availability + TTY check ────────────────
ui::available() {
  command -v whiptail &>/dev/null
}

ui::interactive() {
  ui::available && [ -t 0 ] && [ -t 1 ]
}

# ── Menu ────────────────────────────────────
ui::menu() {
  local title="$1"; shift
  if ! ui::interactive; then
    echo "=== $title ===" >&2
    local i=1
    while [ $# -gt 1 ]; do
      echo "  $i) $1 — $2" >&2
      i=$((i+1)); shift 2
    done
    printf "Choice: " >&2; read -r choice
    echo "$choice"
    return
  fi

  local items=()
  while [ $# -gt 1 ]; do
    items+=("$1" "$2")
    shift 2
  done
  whiptail --title "$title" --menu "" 18 60 10 "${items[@]}" 3>&1 1>&2 2>&3
}

# ── Radiolist ───────────────────────────────
ui::radiolist() {
  local title="$1"; shift
  if ! ui::interactive; then
    echo "=== $title ===" >&2
    local i=1
    while [ $# -gt 2 ]; do
      echo "  $i) $1 — $2" >&2
      i=$((i+1)); shift 3
    done
    printf "Choice: " >&2; read -r choice
    echo "$choice"
    return
  fi

  local items=()
  while [ $# -gt 2 ]; do
    items+=("$1" "$2" "$3")
    shift 3
  done
  whiptail --title "$title" --radiolist "" 18 60 10 "${items[@]}" 3>&1 1>&2 2>&3
}

# ── Input box ───────────────────────────────
ui::input() {
  local title="$1"
  local prompt="$2"
  if ! ui::interactive; then
    printf "%s: " "$prompt" >&2
    read -r val
    echo "$val"
    return
  fi
  whiptail --title "$title" --inputbox "$prompt" 8 60 3>&1 1>&2 2>&3
}

# ── Yes/No confirm ─────────────────────────
ui::confirm() {
  if ! ui::interactive; then
    printf "%s [y/N] " "$*" >&2
    read -r resp
    [[ "$resp" =~ ^[yY] ]]
    return
  fi
  whiptail --title "Confirm" --yesno "$*" 10 60
}

# ── Message box ────────────────────────────
ui::msgbox() {
  local title="$1"; shift
  if ! ui::interactive; then
    echo "=== $title ===" >&2
    echo "$*" >&2
    return
  fi
  whiptail --title "$title" --msgbox "$*" 15 70
}

# ── Info box ───────────────────────────────
ui::info() {
  ui::msgbox "Info" "$*"
}
