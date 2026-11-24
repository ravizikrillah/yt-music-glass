.PHONY: test build run install dmg clean

test:
	@bash scripts/test.sh

build:
	@bash scripts/build.sh

run: build
	@pkill -x YTMusicGlass 2>/dev/null || true
	@open -n "dist-macos/YT Music Glass.app"

install: build
	@pkill -x YTMusicGlass 2>/dev/null || true
	@rm -rf "/Applications/YT Music Glass.app"
	@cp -R "dist-macos/YT Music Glass.app" "/Applications/YT Music Glass.app"
	@echo "Installed -> /Applications/YT Music Glass.app"
	@open "/Applications/YT Music Glass.app"

dmg:
	@bash scripts/dmg.sh

clean:
	@rm -rf dist-macos
