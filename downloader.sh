#!/bin/bash

# GitHub repositories (owner/repo)
REPOS=(
    "flokiorg/tWallet"
    "flokiorg/grpc-miner"
    "flokiorg/fcli"
    "flokiorg/go-flokicoin"
)

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
    linux | darwin)
        BIN_DIR="/usr/local/bin"
        USE_SUDO="sudo"
        ;;
    msys* | mingw* | cygwin)
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

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# 🔍 Check requirements
check_requirements() {
    echo -e "${CYAN}🔍 Checking requirements...${RESET}"

    local missing=()

    command -v jq >/dev/null || missing+=("jq")
    command -v tar >/dev/null || command -v unzip >/dev/null || missing+=("tar or unzip")
    command -v curl >/dev/null || command -v wget >/dev/null || missing+=("curl or wget")

    if [ "${#missing[@]}" -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${RESET} ${missing[*]}"
        echo -e "${YELLOW}Please install them and rerun the script.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}✅ All requirements met.${RESET}\n"
}

# 🌐 Get release asset URL using curl or wget
get_latest_url() {
    local repo="$1"

    if command -v curl >/dev/null; then
        curl -s "https://api.github.com/repos/$repo/releases/latest"
    else
        wget -qO- "https://api.github.com/repos/$repo/releases/latest"
    fi
}

# 📦 Download and install
download_and_install() {
    local repo="$1"
    local name=$(basename "$repo")

    echo -e "${CYAN}🔗 Processing:${RESET} $repo"

    local release_json=$(get_latest_url "$repo")
    local download_url=$(echo "$release_json" | jq -r --arg os "$OS" --arg arch "$ARCH" \
        '.assets[] | select(.name | test($os) and test($arch)) | .browser_download_url' | head -n 1)

    if [[ "$download_url" == "null" || -z "$download_url" ]]; then
        echo -e "${RED}🚫 No compatible release found for $repo.${RESET}\n"
        return
    fi

    local file_name=$(basename "$download_url")
    local file_path="/tmp/$file_name"

    echo -e "${YELLOW}⬇️  Downloading:${RESET} $file_name"
    if command -v curl >/dev/null; then
        curl -sSL -o "$file_path" "$download_url"
    else
        wget -q --show-progress -O "$file_path" "$download_url"
    fi

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    echo -e "${YELLOW}📦 Extracting:${RESET}"
    case "$file_name" in
        *.tar.gz) tar -xzf "$file_path" -C "$TMP_DIR" ;;
        *.zip) unzip -oq "$file_path" -d "$TMP_DIR" ;;
        *) echo -e "${RED}⚠️ Unsupported format. Skipping.${RESET}"; return ;;
    esac
    rm -f "$file_path"

    echo -e "${YELLOW}⚙️  Installing to $BIN_DIR...${RESET}"
    find "$TMP_DIR" -type f -perm +111 | while read -r bin; do
        bin_name=$(basename "$bin")
        $USE_SUDO cp "$bin" "$BIN_DIR/$bin_name"
        $USE_SUDO chmod +x "$BIN_DIR/$bin_name"
        echo -e "${GREEN}✅ Installed: $bin_name${RESET}"
    done

    rm -rf "$TMP_DIR"
    echo
}

# 🚀 Start script
check_requirements

echo -e "${CYAN}🚀 Installing community tools...${RESET}\n"
for repo in "${REPOS[@]}"; do
    download_and_install "$repo"
done

# 🔧 PATH check
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}⚠️  $BIN_DIR is not in your PATH.${RESET}"
    echo -e "${CYAN}👉 Add the following to your shell profile:${RESET}"

    case "$OS" in
        linux | darwin)
            echo -e "   ${GREEN}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc${RESET}"
            ;;
        msys* | mingw* | cygwin)
            echo -e "   ${GREEN}echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bash_profile && source ~/.bash_profile${RESET}"
            echo -e "   Or add ${BIN_DIR} to your Windows Environment Variables."
            ;;
        *)
            echo -e "   ${GREEN}export PATH=\"$BIN_DIR:\$PATH\"${RESET}"
            ;;
    esac
    echo
fi

echo -e "${GREEN}🎉 All tools installed!${RESET}"