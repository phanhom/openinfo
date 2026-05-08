#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# openinfo — one-line install / update
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash
#
#   With AI config (skip prompts):
#     curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash -s -- \
#       --ai-url https://api.openai.com/v1 --ai-key sk-xxx --ai-model gpt-4o
#
#   Check for updates:
#     curl -fsSL https://raw.githubusercontent.com/phanhom/openinfo/main/install.sh | bash -s -- --check
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME="openinfo"
APP_BUNDLE="${APP_NAME}.app"
REPO="phanhom/openinfo"
INSTALL_PATH="/Applications/${APP_BUNDLE}"
VERSION_FILE="${INSTALL_PATH}/Contents/Resources/installed-version.txt"
ENV_FILE="$HOME/.openinfo.env"

# ── Colors ──────────────────────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
NC="\033[0m"

# ── Parse args ──────────────────────────────────────────────────────────────
AI_URL=""
AI_KEY=""
AI_MODEL=""
CHECK_ONLY=false
SKIP_PROMPTS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai-url)   AI_URL="$2";   shift 2 ;;
    --ai-key)   AI_KEY="$2";   shift 2 ;;
    --ai-model) AI_MODEL="$2"; shift 2 ;;
    --check)    CHECK_ONLY=true; shift ;;
    --skip)     SKIP_PROMPTS=true; shift ;;
    --version)  shift 2 ;;  # ignored, always latest
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────────────────

get_latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name":' | head -1 | sed 's/.*"tag_name": "//;s/".*//' 2>/dev/null || echo ""
}

get_installed_version() {
  if [[ -f "$VERSION_FILE" ]]; then cat "$VERSION_FILE"
  else echo ""; fi
}

# Read existing .env values
read_env() {
  local key="$1"
  if [[ -f "$ENV_FILE" ]]; then
    grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | sed "s/^${key}=//" | sed 's/^"//' | sed 's/"$//' || echo ""
  else echo ""
  fi
}

prompt_with_default() {
  local label="$1"
  local default="$2"
  local secret="$3"  # "true" to hide input

  if [[ -n "$default" ]]; then
    echo -ne "  ${CYAN}${label}${NC} ${DIM}[${default}]${NC}: "
  else
    echo -ne "  ${CYAN}${label}${NC}: "
  fi

  if [[ "$secret" == "true" ]]; then
    # Read silently for API keys
    local input=""
    while IFS= read -rs -n1 char; do
      if [[ -z "$char" ]]; then break; fi  # Enter pressed
      input="${input}${char}"
      echo -n "*"
    done
    echo ""
  else
    local input=""
    IFS= read -r input
  fi

  # Empty input → use default
  if [[ -z "$input" ]]; then
    input="$default"
  fi
  echo "$input"
}

# ── ──check mode ────────────────────────────────────────────────────────────
LATEST_VERSION=$(get_latest_version)
INSTALLED_VERSION=$(get_installed_version)

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
      echo -e "  ${YELLOW}⚠ Update available${NC}"
      echo "    Re-run installer to update:"
      echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash${NC}"
    fi
  fi
  echo ""
  exit 0
fi

# ── Install / Update ────────────────────────────────────────────────────────
IS_UPDATE=false
if [[ -d "$INSTALL_PATH" ]]; then
  IS_UPDATE=true
fi

echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════╗${NC}"
if $IS_UPDATE; then
  echo -e "${BOLD}${CYAN}  ║       OpenInfo Updater           ║${NC}"
else
  echo -e "${BOLD}${CYAN}  ║       OpenInfo Installer          ║${NC}"
fi
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════╝${NC}"
echo ""

# Version info
if $IS_UPDATE; then
  echo -e "  Current: ${INSTALLED_VERSION:-unknown}"
fi
echo -e "  Latest:  ${LATEST_VERSION}"
echo ""

# ── 1. Check macOS version ─────────────────────────────────────────────────
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "0")
if [[ "$(echo "$OS_VERSION" | cut -d. -f1)" -lt 15 ]]; then
  echo "✗ Requires macOS 15+. You have $OS_VERSION."
  exit 1
fi
echo -e "  ${GREEN}✓${NC} macOS $OS_VERSION"
echo ""

# ── 2. Download ────────────────────────────────────────────────────────────
RELEASE_URL="https://github.com/${REPO}/releases/latest/download/${APP_BUNDLE}.zip"
TMP_DIR=$(mktemp -d)
ZIP_PATH="${TMP_DIR}/${APP_BUNDLE}.zip"

echo -e "${BOLD}Downloading ${LATEST_VERSION}…${NC}"

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$ZIP_PATH" "$RELEASE_URL" 2>&1) || true
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "✗ Failed to download (HTTP $HTTP_CODE)."
  echo "  Build from source instead:"
  echo "    git clone https://github.com/${REPO}.git && cd openinfo && make install"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} Downloaded ($(du -h "$ZIP_PATH" | cut -f1))"

# ── 3. Install ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Installing to /Applications…${NC}"

# Kill running instance first
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

unzip -qo "$ZIP_PATH" -d "$TMP_DIR" 2>/dev/null
rm -rf "$INSTALL_PATH" 2>/dev/null || true
ditto "$TMP_DIR/${APP_BUNDLE}" "$INSTALL_PATH" 2>/dev/null || \
  cp -R "$TMP_DIR/${APP_BUNDLE}" "$INSTALL_PATH"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true
echo "$LATEST_VERSION" > "$VERSION_FILE" 2>/dev/null || true

echo -e "  ${GREEN}✓${NC} Installed"
rm -rf "$TMP_DIR"

# ── 4. AI configuration ────────────────────────────────────────────────────
# If values were passed via CLI args, use those and skip prompts
if [[ -n "$AI_URL" && -n "$AI_KEY" && -n "$AI_MODEL" ]]; then
  cat > "$ENV_FILE" <<-EOF
AI_BASE_URL=${AI_URL}
AI_API_KEY=${AI_KEY}
AI_MODEL_NAME=${AI_MODEL}
EOF
  echo ""
  echo -e "  ${GREEN}✓${NC} AI configured at ~/.openinfo.env"
else
  # Interactive configuration — pre-fill existing values on update
  EXISTING_URL=$(read_env "AI_BASE_URL")
  EXISTING_KEY=$(read_env "AI_API_KEY")
  EXISTING_MODEL=$(read_env "AI_MODEL_NAME")

  if ! $SKIP_PROMPTS; then
    echo ""
    echo -e "${BOLD}AI Chat setup (optional — press Enter to skip)${NC}"
    echo ""

    NEW_URL=$(prompt_with_default "Base URL" "$EXISTING_URL" "false")
    # If URL is empty, skip the rest
    if [[ -z "$NEW_URL" ]]; then
      echo -e "  ${DIM}Skipped — AI chat will be unavailable${NC}"
    else
      NEW_KEY=$(prompt_with_default "API Key" "$EXISTING_KEY" "true")
      NEW_MODEL=$(prompt_with_default "Model" "$EXISTING_MODEL" "false")

      if [[ -n "$NEW_KEY" && -n "$NEW_MODEL" ]]; then
        cat > "$ENV_FILE" <<-EOF
AI_BASE_URL=${NEW_URL}
AI_API_KEY=${NEW_KEY}
AI_MODEL_NAME=${NEW_MODEL}
EOF
        echo -e "  ${GREEN}✓${NC} AI configured at ~/.openinfo.env"
      else
        echo -e "  ${DIM}Incomplete — skipping AI setup${NC}"
      fi
    fi
  fi
fi

# ── 5. Done ────────────────────────────────────────────────────────────────
echo ""
if $IS_UPDATE; then
  echo -e "${BOLD}${GREEN}  ✅ Updated to ${LATEST_VERSION}${NC}"
else
  echo -e "${BOLD}${GREEN}  ✅ OpenInfo ${LATEST_VERSION} installed${NC}"
fi
echo ""
echo "  Launch from Applications, or run:"
echo -e "    ${CYAN}open /Applications/${APP_BUNDLE}${NC}"
echo ""
echo "  Update anytime:"
echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash${NC}"
if ! $SKIP_PROMPTS && [[ ! -f "$ENV_FILE" ]]; then
  echo ""
  echo "  Configure AI later:"
  echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash${NC}"
fi
echo ""