# xcode-select points at the Command Line Tools on this machine, which ship no
# XCTest. Overriding DEVELOPER_DIR here fixes `make test` without sudo and without
# changing the global toolchain.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: spike sweep test build dev release clean

## spike: fire a tap train. make spike TAPS=24 INTERVAL=30 ID=1
TAPS ?= 24
INTERVAL ?= 30
ID ?= 1
spike:
	cd mac && swift run spike --taps $(TAPS) --interval $(INTERVAL) --actuation $(ID)

## sweep: every actuation ID at 24 taps / 30ms, announced
sweep:
	cd mac && swift run spike --sweep

## test: the whole Swift suite. The drift test runs in real time (~100s).
test:
	cd mac && swift test

## build: assemble Thrum.app
build:
	./scripts/build-app.sh

## dev: the landing page
dev:
	cd web && pnpm dev

## release: build, package, publish
release: build
	./scripts/package-dmg.sh
	gh release create v$(shell cat VERSION) dist/Thrum-$(shell cat VERSION).dmg \
		--title "Thrum $(shell cat VERSION)" --generate-notes

clean:
	rm -rf mac/.build dist web/.next
