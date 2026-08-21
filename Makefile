APP_NAME := Markport
BUILD_DIR := build

build:
	bash build.sh

run: build
	open "$(BUILD_DIR)/$(APP_NAME).app"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUILD_DIR)/$(APP_NAME).app" /Applications/

clean:
	rm -rf "$(BUILD_DIR)"

.PHONY: build run install clean
