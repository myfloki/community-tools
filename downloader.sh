#!/bin/sh

# Exit immediately if any command fails
set -e

# ANSI colors (for printf '%b')
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

# On exit, if we failed (non-zero), print a red error
on_exit() {
  code=$?
  if [ "$code" -ne 0 ]; then
    printf '%b\n' "${RED}❌ Script failed with exit code ${code}.${RESET}" >&2
  fi
}
trap 'on_exit' EXIT

# GitHub repositories (owner/repo), space-separated
REPOS="
flokiorg/tWallet
flokiorg/grpc-miner
flokiorg/fcli
flokiorg/go-flokicoin
"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  i686) ARCH="386" ;;
esac

# Set install path
case "$OS" in
  linux|darwin)
    BIN_DIR="/usr/local/bin"
    USE_SUDO="sudo"
    ;;
  msys*|mingw*|cygwin)
    BIN_DIR="$HOME/.local/bin"
    USE_SUDO=""
    ;;
  *)
    BIN_DIR="$HOME/.local/bin"
    USE_SUDO=""
    ;;
esac

TMP_DIR="/tmp/community_tools"
mkdir -p "$BIN_DIR"

# 🔍 Check requirements
check_requirements() {
  printf '%b\n' "${CYAN}🔍 Checking requirements...${RESET}"

  missing=""
  command -v jq >/dev/null 2>&1 || missing="${missing} jq"
  (command -v tar >/dev/null 2>&1 || command -v unzip >/dev/null 2>&1) || missing="${missing} tar/unzip"
  (command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1) || missing="${missing} curl/wget"

  if [ -n "$missing" ]; then
    printf '%b\n' "${RED}❌ Missing required tools:${RESET}${missing}"
    printf '%b\n' "${YELLOW}Please install them and rerun the script.${RESET}"
    exit 1
  fi

  printf '%b\n\n' "${GREEN}✅ All requirements met.${RESET}"
}

# 🌐 Get release JSON via curl or wget
get_latest_json() {
  repo=$1
  if command -v curl >/dev/null 2>&1; then
    curl -s "https://api.github.com/repos/$repo/releases/latest"
  else
    wget -qO- "https://api.github.com/repos/$repo/releases/latest"
  fi
}

# 📦 Download & install one repo
download_and_install() {
  repo=$1

  printf '%b %s\n' "${CYAN}🔗 Processing:${RESET}" "$repo"

  release_json=$(get_latest_json "$repo")
  download_url=$(printf '%s\n' "$release_json" |
    jq -r --arg os "$OS" --arg arch "$ARCH" \
      '.assets[] | select(.name|test($os) and test($arch)) | .browser_download_url' |
    head -n 1)

  if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
    printf '%b %s\n\n' "${RED}🚫 No compatible release for${RESET}" "$repo"
    return
  fi

  file_name=$(basename "$download_url")
  file_path="/tmp/$file_name"

  printf '%b %s\n' "${YELLOW}⬇️  Downloading:${RESET}" "$file_name"
  if command -v curl >/dev/null 2>&1; then
    curl -sSL -o "$file_path" "$download_url"
  else
    wget -q --show-progress -O "$file_path" "$download_url"
  fi

  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  printf '%b\n' "${YELLOW}📦 Extracting:${RESET}"
  case "$file_name" in
    *.tar.gz) tar -xzf "$file_path" -C "$TMP_DIR" ;;
    *.zip) unzip -oq "$file_path" -d "$TMP_DIR" ;;
    *)
      printf '%b\n' "${RED}⚠️ Unsupported format. Skipping.${RESET}"
      return
      ;;
  esac
  rm -f "$file_path"

  printf '%b %s\n' "${YELLOW}⚙️  Installing to${RESET}" "$BIN_DIR"
  find "$TMP_DIR" -type f | while IFS= read -r bin; do
    bin_name=$(basename "$bin")
    $USE_SUDO cp "$bin" "$BIN_DIR/$bin_name"
    $USE_SUDO chmod +x "$BIN_DIR/$bin_name"
    printf '%b %s\n' "${GREEN}✅ Installed:${RESET}" "$bin_name"
  done

  rm -rf "$TMP_DIR"
  printf '\n'
}

# 🚀 Main
check_requirements

printf '%b\n\n' "${CYAN}🚀 Installing community tools...${RESET}"
for repo in $REPOS; do
  download_and_install "$repo"
done

# 🔧 PATH check
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    printf '%b %s\n' "${YELLOW}⚠️  $BIN_DIR is not in your PATH.${RESET}"
    printf '%b\n' "${CYAN}👉 Add to your shell profile:${RESET}"
    case "$OS" in
      linux|darwin)
        printf "  %b\n" \
          "${GREEN}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.profile && . ~/.profile${RESET}"
        ;;
      msys*|mingw*|cygwin)
        printf "  %b\n" \
          "${GREEN}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bash_profile && . ~/.bash_profile${RESET}"
        printf "  Or add $BIN_DIR to Windows Environment Variables.\n"
        ;;
      *)
        printf "  %b\n" \
          "${GREEN}export PATH=\"$BIN_DIR:\$PATH\"${RESET}"
        ;;
    esac
    printf '\n'
    ;;
esac

printf '%b\n' "${GREEN}🎉 All tools installed!${RESET}"