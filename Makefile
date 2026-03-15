.PHONY: build release sign install clean

# Override with your Developer ID Application identity
SIGNING_IDENTITY ?= Developer ID Application
BUNDLE_ID := cc.gen4.icloud-kv
INSTALL_DIR := $(HOME)/.local/bin

build:
	swift build

release:
	swift build -c release

sign: release
	codesign --force --sign "$(SIGNING_IDENTITY)" \
		--entitlements icloud-kv.entitlements \
		--identifier "$(BUNDLE_ID)" \
		.build/release/icloud-kv

install: sign
	mkdir -p "$(INSTALL_DIR)"
	cp .build/release/icloud-kv "$(INSTALL_DIR)/icloud-kv"
	@echo "Installed to $(INSTALL_DIR)/icloud-kv"

clean:
	swift package clean
	rm -rf .build
