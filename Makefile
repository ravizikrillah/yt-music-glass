.PHONY: test build build-arm64 build-x86_64 build-all run install dmg dmg-arm64 dmg-x86_64 dmg-all clean

HOST_ARCH := $(shell uname -m)

test:
	@node packages/shared/scripts/verify-shared.mjs
	@bash apps/macos/scripts/test.sh

build:
	@bash apps/macos/scripts/build.sh "$(HOST_ARCH)"

build-arm64:
	@bash apps/macos/scripts/build.sh arm64

build-x86_64:
	@bash apps/macos/scripts/build.sh x86_64

build-all: build-arm64 build-x86_64

run: build
	@pkill -x YTMusicGlass 2>/dev/null || true
	@open -n "dist-macos/$(HOST_ARCH)/YT Music Glass.app"

install: build
	@pkill -x YTMusicGlass 2>/dev/null || true
	@rm -rf "/Applications/YT Music Glass.app"
	@cp -R "dist-macos/$(HOST_ARCH)/YT Music Glass.app" "/Applications/YT Music Glass.app"
	@echo "Installed -> /Applications/YT Music Glass.app"
	@open "/Applications/YT Music Glass.app"

dmg:
	@bash apps/macos/scripts/dmg.sh "$(HOST_ARCH)"

dmg-arm64:
	@bash apps/macos/scripts/dmg.sh arm64

dmg-x86_64:
	@bash apps/macos/scripts/dmg.sh x86_64

dmg-all:
	@bash apps/macos/scripts/dmg.sh all

clean:
	@rm -rf dist-macos
