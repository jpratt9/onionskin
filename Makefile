APP := build/Build/Products/Release/Onionskin.app

.PHONY: project build test run install clean

project:
	xcodegen generate

build: project
	xcodebuild -project Onionskin.xcodeproj -scheme Onionskin -configuration Release -derivedDataPath build build

test: project
	xcodebuild -project Onionskin.xcodeproj -scheme Onionskin -derivedDataPath build test

run: build
	open "$(APP)"

install: build
	ditto "$(APP)" "/Applications/Onionskin.app"

clean:
	rm -rf build Onionskin.xcodeproj
