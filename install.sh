#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# openinfo — one-line install / update
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash
#
#   With AI config:
#     curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash -s -- \
#       --ai-url https://api.openai.com/v1 --ai-key sk-xxx --ai-model gpt-4o
#
#   Check for updates (no install):
#     curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash -s -- --check
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME="openinfo"
APP_BUNDLE="${APP_NAME}.app"
REPO="phanhom/openinfo"
INSTALL_PATH="/Applications/${APP_BUNDLE}"
VERSION_FILE="${INSTALL_PATH}/Contents/Resources/installed-version.txt"

# ── Colors ──────────────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
NC="\033[0m"

# ── Parse args ──────────────────────────────────────────────────────────────
AI_URL=""
AI_KEY=""
AI_MODEL=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai-url)   AI_URL="$2";   shift 2 ;;
    --ai-key)   AI_KEY="$2";   shift 2 ;;
    --ai-model) AI_MODEL="$2"; shift 2 ;;
    --check)    CHECK_ONLY=true; shift ;;
    --version)  VERSION="$2";  shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Get latest release tag from GitHub ──────────────────────────────────────
get_latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name":' | head -1 | sed 's/.*"tag_name": "//;s/".*//' 2>/dev/null || echo ""
}

# ── Get installed version ───────────────────────────────────────────────────
get_installed_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    cat "$VERSION_FILE"
  else
    echo ""
  fi
}

LATEST_VERSION=$(get_latest_version)
INSTALLED_VERSION=$(get_installed_version)

# ── --check mode ────────────────────────────────────────────────────────────
if $CHECK_ONLY; then
  echo ""
  if [[ -d "$INSTALL_PATH" ]]; then
    echo -e "${BOLD}OpenInfo ${INSTALLED_VERSION:-unknown} installed${NC}"
    echo "  Location: ${INSTALL_PATH}"
  else
    echo -e "${BOLD}OpenInfo not installed${NC}"
  fi
  if [[ -n "$LATEST_VERSION" ]]; then
    echo "  Latest:   ${LATEST_VERSION}"
    if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]; then
      echo -e "  ${GREEN}✓ Up to date${NC}"
    elif [[ -d "$INSTALL_PATH" ]]; then
      echo -e "  ${YELLOW}⚠ Update available:${NC}"
      echo "    curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash"
    fi
  else
    echo "  Latest:   (offline)"
  fi
  echo ""
  exit 0
fi

# ── Install / Update ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}  ║      OpenInfo Installer      ║${NC}"
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════╝${NC}"
echo ""

# Show version info
if [[ -d "$INSTALL_PATH" ]]; then
  echo -e "  Installed: ${INSTALLED_VERSION:-unknown}"
fi
if [[ -n "$LATEST_VERSION" ]]; then
  echo -e "  Latest:    ${LATEST_VERSION}"
fi
echo ""

# ── 1. Check requirements ──────────────────────────────────────────────────
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "0")
if [[ "$(echo "$OS_VERSION" | cut -d. -f1)" -lt 15 ]]; then
  echo "✗ Requires macOS 15+. You have $OS_VERSION."
  exit 1
fi
echo "✓ macOS $OS_VERSION"

# ── 2. Download the release .app.zip ───────────────────────────────────────
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/${APP_BUNDLE}.zip"
TMP_DIR=$(mktemp -d)
ZIP_PATH="${TMP_DIR}/${APP_BUNDLE}.zip"

echo ""
echo -e "${BOLD}Downloading ${LATEST_VERSION:-OpenInfo}…${NC}"
echo "  ${RELEASE_URL}"

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$ZIP_PATH" "$RELEASE_URL" 2>&1) || true
if [[ "$HTTP_CODE" != "200" ]]; then
  echo ""
  echo "✗ Failed to download release (HTTP $HTTP_CODE)."
  echo "  You can build from source instead:"
  echo "    git clone https://github.com/${REPO}.git"
  echo "    cd ${APP_NAME} && make install"
  echo ""
  exit 1
fi

echo "✓ Downloaded ($(du -h "$ZIP_PATH" | cut -f1))"

# ── 3. Extract ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Installing to /Applications…${NC}"

unzip -qo "$ZIP_PATH" -d "$TMP_DIR" 2>/dev/null

# Remove existing
rm -rf "$INSTALL_PATH" 2>/dev/null || true

# Copy using ditto (preserves extended attributes)
ditto "$TMP_DIR/${APP_BUNDLE}" "$INSTALL_PATH" 2>/dev/null || \
  cp -R "$TMP_DIR/${APP_BUNDLE}" "$INSTALL_PATH"

# Remove quarantine flag
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

# Write version info
echo "$LATEST_VERSION" > "$VERSION_FILE" 2>/dev/null || true

echo -e "✓ ${GREEN}Installed to ${INSTALL_PATH}${NC}"

# ── 4. Clean up ─────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

# ── 5. Optional: configure AI ──────────────────────────────────────────────
if [[ -n "$AI_URL" && -n "$AI_KEY" && -n "$AI_MODEL" ]]; then
  cat > ~/.openinfo.env <<- EOF
AI_BASE_URL=${AI_URL}
AI_API_KEY=${AI_KEY}
AI_MODEL_NAME=${AI_MODEL}
EOF
  echo ""
  echo -e "✓ ${GREEN}AI configured at ~/.openinfo.env${NC}"
fi

# ── 6. Done ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}  ✅ OpenInfo ${LATEST_VERSION} installed!${NC}"
echo ""
echo "  Launch it from your Applications folder."
echo ""
echo "  To check for updates later:"
echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- --check${NC}"
echo ""
echo "  To update:"
echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash${NC}"
echo ""
echo "  To configure AI chat, edit ~/.openinfo.env:"
echo -e "    ${CYAN}echo \"AI_BASE_URL=https://api.openai.com/v1\"  >> ~/.openinfo.env${NC}"
echo -e "    ${CYAN}echo \"AI_API_KEY=sk-...\"                       >> ~/.openinfo.env${NC}"
echo -e "    ${CYAN}echo \"AI_MODEL_NAME=gpt-4o\"                    >> ~/.openinfo.env${NC}"
echo ""
