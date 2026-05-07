#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# openinfo — one-line installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash
#
# Or with AI config:
#   curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash -s -- \
#     --ai-url https://api.openai.com/v1 \
#     --ai-key sk-xxx \
#     --ai-model gpt-4o
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME="openinfo"
APP_BUNDLE="${APP_NAME}.app"
REPO="phanhom/openinfo"
VERSION="${VERSION:-latest}"

# ── Colors ──────────────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# ── Parse args ──────────────────────────────────────────────────────────────
AI_URL=""
AI_KEY=""
AI_MODEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai-url)   AI_URL="$2";   shift 2 ;;
    --ai-key)   AI_KEY="$2";   shift 2 ;;
    --ai-model) AI_MODEL="$2"; shift 2 ;;
    --version)  VERSION="$2";  shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}  ║      OpenInfo Installer      ║${NC}"
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════╝${NC}"
echo ""

# ── 1. Check requirements ──────────────────────────────────────────────────
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "0")
if [[ "$(echo "$OS_VERSION" | cut -d. -f1)" -lt 15 ]]; then
  echo "✗ Requires macOS 15+. You have $OS_VERSION."
  exit 1
fi
echo "✓ macOS $OS_VERSION"

# ── 2. Download the release .app.zip ───────────────────────────────────────
RELEASE_URL="https://github.com/${REPO}/releases/${VERSION}/download/${APP_BUNDLE}.zip"
TMP_DIR=$(mktemp -d)
ZIP_PATH="${TMP_DIR}/${APP_BUNDLE}.zip"

echo ""
echo -e "${BOLD}Downloading latest OpenInfo…${NC}"
echo "  ${RELEASE_URL}"

if ! curl -fsSL -o "$ZIP_PATH" "$RELEASE_URL" 2>&1; then
  echo ""
  echo "✗ Failed to download release."
  echo "  If this is the first release, you may need to build locally:"
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

# Remove existing if present
rm -rf "/Applications/${APP_BUNDLE}" 2>/dev/null || true

# Use ditto to preserve extended attributes
ditto "$TMP_DIR/${APP_BUNDLE}" "/Applications/${APP_BUNDLE}" 2>/dev/null || \
  cp -R "$TMP_DIR/${APP_BUNDLE}" "/Applications/${APP_BUNDLE}"

# Remove quarantine flag
xattr -dr com.apple.quarantine "/Applications/${APP_BUNDLE}" 2>/dev/null || true

echo -e "✓ ${GREEN}Installed to /Applications/${APP_BUNDLE}${NC}"

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
echo -e "${BOLD}${GREEN}  ✅ OpenInfo installed!${NC}"
echo ""
echo "  Launch it from your Applications folder."
echo ""
echo "  First time? macOS Gatekeeper may block it:"
echo -e "    ${CYAN}xattr -dr com.apple.quarantine /Applications/${APP_BUNDLE}${NC}"
echo ""
echo "  To configure AI chat later, edit ~/.openinfo.env:"
echo -e "    ${CYAN}echo \"AI_BASE_URL=https://api.openai.com/v1\"  >> ~/.openinfo.env${NC}"
echo -e "    ${CYAN}echo \"AI_API_KEY=sk-...\"                       >> ~/.openinfo.env${NC}"
echo -e "    ${CYAN}echo \"AI_MODEL_NAME=gpt-4o\"                    >> ~/.openinfo.env${NC}"
echo ""
echo "  Uninstall:"
echo -e "    ${CYAN}rm -rf /Applications/${APP_BUNDLE}${NC}"
echo ""
