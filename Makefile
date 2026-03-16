.PHONY: build release sign install clean

# Override with your Developer ID Application identity
SIGNING_IDENTITY ?= Developer ID Application
BUNDLE_ID := cc.digitalassistant.cirrus-kv
INSTALL_DIR := $(HOME)/.local/bin

build:
	swift build

release:
	swift build -c release

sign: release
	codesign --force --sign "$(SIGNING_IDENTITY)" \
		--entitlements cirrus-kv.entitlements \
		--identifier "$(BUNDLE_ID)" \
		.build/release/cirrus-kv

install: sign
	mkdir -p "$(INSTALL_DIR)"
	cp .build/release/cirrus-kv "$(INSTALL_DIR)/cirrus-kv"
	@echo "Installed to $(INSTALL_DIR)/cirrus-kv"

clean:
	swift package clean
	rm -rf .build
