.PHONY: build release sign install clean

# Override with your Developer ID Application identity
SIGNING_IDENTITY ?= Developer ID Application
BUNDLE_ID := cc.digitalassistant.cirrus-kv
INSTALL_DIR := $(HOME)/.local/bin
PROFILE := $(HOME)/Library/Developer/Xcode/UserData/Provisioning Profiles/Cirrus_KV__Developer_ID.provisionprofile
APP_BUNDLE := .build/cirrus-kv.app

build:
	swift build

release:
	swift build -c release

sign: release
	codesign --force --sign "$(SIGNING_IDENTITY)" \
		--entitlements cirrus-kv.entitlements \
		--identifier "$(BUNDLE_ID)" \
		--options runtime \
		.build/release/cirrus-kv

bundle: sign
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp .build/release/cirrus-kv "$(APP_BUNDLE)/Contents/MacOS/cirrus-kv"
	cp "$(PROFILE)" "$(APP_BUNDLE)/Contents/embedded.provisioningprofile"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleExecutable string cirrus-kv" \
		-c "Add :CFBundleName string cirrus-kv" \
		-c "Add :CFBundleVersion string 0.1.0" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :LSMinimumSystemVersion string 13.0" \
		-c "Add :LSUIElement bool true" \
		"$(APP_BUNDLE)/Contents/Info.plist"

install: bundle
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/cirrus-kv.app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/cirrus-kv.app"
	ln -sf "$(INSTALL_DIR)/cirrus-kv.app/Contents/MacOS/cirrus-kv" "$(INSTALL_DIR)/cirrus-kv"
	@echo "Installed to $(INSTALL_DIR)/cirrus-kv (via app bundle)"

clean:
	swift package clean
	rm -rf .build
