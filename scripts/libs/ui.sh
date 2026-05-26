#!/usr/bin/env bash
# dockage — Interactive UI (whiptail → bash select → text fallback)
set -euo pipefail

# ── Detection ────────────────────────────────
ui::whiptail_ok() { command -v whiptail &>/dev/null && [ -t 0 ] && [ -t 1 ]; }
ui::tty_ok()     { [ -t 0 ] && [ -t 1 ]; }

# ── Menu: returns selected item key ──────────
ui::menu() {
  local title="$1"; shift
  local -a keys=() labels=()
  while [ $# -gt 1 ]; do
    keys+=("$1")
    labels+=("$2")
    shift 2
  done

  if ui::whiptail_ok; then
    local -a witems=()
    for i in "${!keys[@]}"; do
      witems+=("${keys[$i]}" "${labels[$i]}")
    done
    whiptail --title "$title" --menu "" 18 60 10 "${witems[@]}" 3>&1 1>&2 2>&3
    return
  fi

  if ui::tty_ok; then
    echo "  $title" >&2
    echo "" >&2
    local _old_ps3="${PS3-}"
    PS3="  Choose: "
    select _ in "${labels[@]}"; do
      if [ -n "$REPLY" ] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#keys[@]}" ]; then
        echo "${keys[$((REPLY-1))]}"
        break
      fi
    done </dev/tty
    PS3="$_old_ps3"
    return
  fi

  # Plain text (pipe/CI)
  echo "=== $title ===" >&2
  for i in "${!keys[@]}"; do
    echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
  done
  printf "Choice: " >&2; read -r choice
  local idx=$((choice - 1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ]; then
    echo "${keys[$idx]}"
  fi
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

  if ui::whiptail_ok; then
    local -a witems=()
    for i in "${!keys[@]}"; do
      witems+=("${keys[$i]}" "${labels[$i]}" "OFF")
    done
    whiptail --title "$title" --radiolist "" 18 60 10 "${witems[@]}" 3>&1 1>&2 2>&3
    return
  fi

  if ui::tty_ok; then
    echo "  $title" >&2
    echo "" >&2
    local -a display=()
    for i in "${!keys[@]}"; do
      display+=("${keys[$i]} — ${labels[$i]}")
    done
    local _old_ps3="${PS3-}"
    PS3="  Choose: "
    select _ in "${display[@]}"; do
      if [ -n "$REPLY" ] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#keys[@]}" ]; then
        echo "${keys[$((REPLY-1))]}"
        break
      fi
    done </dev/tty
    PS3="$_old_ps3"
    return
  fi

  # Plain text
  echo "=== $title ===" >&2
  for i in "${!keys[@]}"; do
    echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
  done
  printf "Choice: " >&2; read -r choice
  local idx=$((choice - 1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ]; then
    echo "${keys[$idx]}"
  fi
}

# ── Input box ───────────────────────────────
ui::input() {
  local title="$1"
  local prompt="$2"

  if ui::whiptail_ok; then
    whiptail --title "$title" --inputbox "$prompt" 8 60 3>&1 1>&2 2>&3
    return
  fi

  printf "  %s: " "$prompt" >&2
  read -r val
  echo "$val"
}

# ── Yes/No confirm ─────────────────────────
ui::confirm() {
  if ui::whiptail_ok; then
    whiptail --title "Confirm" --yesno "$*" 10 60
    return
  fi

  printf "  %s [y/N] " "$*" >&2
  read -r resp
  [[ "$resp" =~ ^[yY] ]]
}

# ── Message box ────────────────────────────
ui::msgbox() {
  local title="$1"; shift
  if ui::whiptail_ok; then
    whiptail --title "$title" --msgbox "$*" 15 70
    return
  fi
  echo "=== $title ===" >&2
  echo "$*" >&2
  if ui::tty_ok; then
    printf "  Press Enter to continue." >&2; read -r </dev/tty
  fi
}

# ── Info alias ─────────────────────────────
ui::info() { ui::msgbox "Info" "$*"; }
