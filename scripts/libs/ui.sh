#!/usr/bin/env bash
# dockage — Interactive UI (fzf > bash select > plain text)
set -euo pipefail

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
    echo "=== $title ===" >&2
    for i in "${!keys[@]}"; do
      echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
    done
    printf "Choice: " >&2; read -r choice
    local idx=$((choice - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ] && echo "${keys[$idx]}"
    return
  fi

  # fzf: arrow keys, type to search, Enter/Escape
  if command -v fzf &>/dev/null; then
    local result
    result=$(
      for i in "${!keys[@]}"; do
        printf "%s\t%s\n" "${keys[$i]}" "${labels[$i]}"
      done | fzf --with-nth=2.. --delimiter=$'\t' \
                  --header="$title" --prompt="  Choose: " \
                  --height=~40% --reverse --cycle
    ) || return 1
    local key
    IFS=$'\t' read -r key _ <<< "$result"
    echo "$key"
    return
  fi

  # Bash select fallback
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
    echo "=== $title ===" >&2
    for i in "${!keys[@]}"; do
      echo "  $((i+1))) ${keys[$i]} — ${labels[$i]}" >&2
    done
    printf "Choice: " >&2; read -r choice
    local idx=$((choice - 1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#keys[@]}" ] && echo "${keys[$idx]}"
    return
  fi

  # fzf
  if command -v fzf &>/dev/null; then
    local result
    result=$(
      for i in "${!keys[@]}"; do
        printf "%s\t%s\n" "${keys[$i]}" "${labels[$i]}"
      done | fzf --with-nth=2.. --delimiter=$'\t' \
                  --header="$title" --prompt="  Choose: " \
                  --height=~80% --reverse --cycle
    ) || return 1
    local key
    IFS=$'\t' read -r key _ <<< "$result"
    echo "$key"
    return
  fi

  # Bash select fallback
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
    printf "%s: " "$prompt" >&2; read -r val; echo "$val"
    return
  fi
  printf "  %s: " "$prompt" >&2; read -r val; echo "$val"
}

# ── Yes/No confirm ─────────────────────────
ui::confirm() {
  if ! ui::interactive; then
    printf "%s [y/N] " "$*" >&2; read -r resp; [[ "$resp" =~ ^[yY] ]]
    return
  fi
  printf "  %s [y/N] " "$*" >&2; read -r resp; [[ "$resp" =~ ^[yY] ]]
}

# ── Message box ────────────────────────────
ui::msgbox() {
  local title="$1"; shift
  echo "=== $title ===" >&2
  echo "$*" >&2
  if ui::interactive; then
    printf "  Press Enter to continue." >&2; read -r
  fi
}

ui::info() { ui::msgbox "Info" "$*"; }
