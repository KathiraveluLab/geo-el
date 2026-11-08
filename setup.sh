#!/usr/bin/env bash
set -euo pipefail

echo "[geo-el] Checking Linux prerequisites (Erlang/OTP and Elixir)..."

install_linux_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "[geo-el] Detected apt-get. Installing Erlang and Elixir..."
    sudo apt-get update
    sudo apt-get install -y erlang elixir build-essential git curl
  elif command -v dnf >/dev/null 2>&1; then
    echo "[geo-el] Detected dnf. Installing Erlang and Elixir..."
    sudo dnf install -y erlang elixir make automake gcc gcc-c++ git curl
  elif command -v pacman >/dev/null 2>&1; then
    echo "[geo-el] Detected pacman. Installing Erlang and Elixir..."
    sudo pacman -Sy --noconfirm erlang elixir base-devel git curl
  elif command -v apk >/dev/null 2>&1; then
    echo "[geo-el] Detected apk. Installing Erlang and Elixir..."
    sudo apk add --no-cache erlang elixir build-base git curl
  elif command -v zypper >/dev/null 2>&1; then
    echo "[geo-el] Detected zypper. Installing Erlang and Elixir..."
    sudo zypper install -y erlang elixir git curl
  else
    echo "[geo-el] ERROR: Unsupported Linux package manager. Please install Erlang/OTP and Elixir manually." >&2
    exit 1
  fi
}

if ! command -v erl >/dev/null 2>&1 || ! command -v mix >/dev/null 2>&1; then
  install_linux_packages
else
  echo "[geo-el] Erlang/OTP and Elixir are already installed."
fi

echo "[geo-el] Initializing Hex and Rebar package managers..."
mix local.hex --force
mix local.rebar --force

echo "[geo-el] Fetching project dependencies via mix setup..."
mix setup

echo "[geo-el] Running mix precommit verification..."
mix precommit

echo "[geo-el] Setup and verification completed. Run 'mix phx.server' to start the application."

