APP=SpaceCadet
PLIST=com.apple.space-cadet.plist
LAUNCHAGENT_DIR=$(HOME)/Library/LaunchAgents
BIN=.build/release/$(APP)

# SwiftLint
XCODE_APP=/Applications/Xcode.app/Contents/Developer
STRICT?=0

.PHONY: build release run test install-agent unload-agent lint

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo "SwiftLint not installed. Install with: brew install swiftlint"; exit 1; }
	@# Prefer full Xcode toolchain for sourcekitd to avoid SwiftLint crash
	@if [ -d "$(XCODE_APP)" ]; then \
		echo "Running SwiftLint with DEVELOPER_DIR=$(XCODE_APP)"; \
		DEVELOPER_DIR=$(XCODE_APP) swiftlint $(if $(filter 1,$(STRICT)),--strict,); \
	else \
		echo "Running SwiftLint with current toolchain"; \
		swiftlint $(if $(filter 1,$(STRICT)),--strict,); \
	fi

build: lint
	swift build

release: lint
	swift build -c release

run:
	swift run $(APP)

test: lint
	swift test

install-agent: release
	mkdir -p $(LAUNCHAGENT_DIR)
	cp scripts/$(PLIST) $(LAUNCHAGENT_DIR)/$(PLIST)
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST) 2>/dev/null || true
	launchctl load $(LAUNCHAGENT_DIR)/$(PLIST)

unload-agent:
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST)
