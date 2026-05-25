#!/usr/bin/env bash
set -euo pipefail

ui::menu() { :; }
ui::input() { :; }
ui::confirm() {
  printf "%s [y/N] " "$*" >&2
  read -r resp
  [[ "$resp" =~ ^[yY] ]]
}
ui::progress() { :; }
