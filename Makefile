APP=SpaceCadet
PLIST=com.apple.space-cadet.plist
LAUNCHAGENT_DIR=$(HOME)/Library/LaunchAgents
BIN=.build/release/$(APP)

.PHONY: build release run test install-agent unload-agent

build:
	swift build

release:
	swift build -c release

run:
	swift run $(APP)

test:
	swift test

install-agent: release
	mkdir -p $(LAUNCHAGENT_DIR)
	cp scripts/$(PLIST) $(LAUNCHAGENT_DIR)/$(PLIST)
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST) 2>/dev/null || true
	launchctl load $(LAUNCHAGENT_DIR)/$(PLIST)

unload-agent:
	launchctl unload $(LAUNCHAGENT_DIR)/$(PLIST)
