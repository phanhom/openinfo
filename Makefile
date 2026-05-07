SHELL := /bin/bash -euo pipefail

APP_NAME := openinfo
APP_BUNDLE := $(APP_NAME).app

# SPM output path varies by platform — find the release binary dynamically
BINARY := $(shell find .build -maxdepth 4 -path "*/release/$(APP_NAME)" -type f 2>/dev/null | head -1)

# Try to derive version from the closest git tag
GIT_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

.PHONY: build bundle zip install uninstall clean

# ── 1. Build ───────────────────────────────────────────────────────────────
build:
	swift build -c release --product $(APP_NAME)

# ── 2. Bundle into .app ────────────────────────────────────────────────────
bundle: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	# Copy bundled resources (SVG assets)
	cp Sources/$(APP_NAME)/Resources/*.svg "$(APP_BUNDLE)/Contents/Resources/" 2>/dev/null || true
	# Write version info
	printf '%s' "$(GIT_TAG)" > "$(APP_BUNDLE)/Contents/Resources/installed-version.txt"
	# Generate Info.plist
	/usr/libexec/PlistBuddy -c "Save" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null
	/usr/libexec/PlistBuddy -c "Add CFBundleExecutable             string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleName                  string OpenInfo" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleDisplayName           string OpenInfo" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleIdentifier            string com.openinfo.app" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleVersion               string 1" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleShortVersionString    string 1.0.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundlePackageType           string APPL" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add CFBundleInfoDictionaryVersion string 6.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add LSMinimumSystemVersion        string 15.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add LSUIElement                   bool YES" "$(APP_BUNDLE)/Contents/Info.plist"

# ── 3. Zip for release ──────────────────────────────────────────────────────
zip: bundle
	rm -f "$(APP_BUNDLE).zip"
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(APP_BUNDLE).zip"
	@echo "✅ Created $(APP_BUNDLE).zip"

# ── 4. Install to /Applications ────────────────────────────────────────────
install: bundle
	@echo ""
	@echo "==> Installing OpenInfo…"
	cp -R "$(APP_BUNDLE)" /Applications/
	rm -rf "$(APP_BUNDLE)"
	@echo ""
	@echo "✅ Installed to /Applications/$(APP_BUNDLE)"
	@echo ""
	@echo "First launch requires Gatekeeper bypass:"
	@echo '  xattr -dr com.apple.quarantine /Applications/$(APP_BUNDLE)'
	@echo ""
	@echo "Optional — AI Chat setup:"
	@echo '  echo "AI_BASE_URL=https://api.openai.com/v1"  > ~/.openinfo.env'
	@echo '  echo "AI_API_KEY=sk-your-key-here"           >> ~/.openinfo.env'
	@echo '  echo "AI_MODEL_NAME=gpt-4o"                  >> ~/.openinfo.env'
	@echo ""
	@echo "Done! Launch OpenInfo from Applications."

# ── Uninstall ──────────────────────────────────────────────────────────────
uninstall:
	rm -rf "/Applications/$(APP_BUNDLE)"
	@echo "✅ OpenInfo removed from /Applications"

# ── Clean ──────────────────────────────────────────────────────────────────
clean:
	rm -rf "$(APP_BUNDLE)"
	swift clean
	@echo "✅ Cleaned"
