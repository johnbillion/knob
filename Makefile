.PHONY: build run clean

build:
	xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Debug build

run: build
	pkill -x Knob 2>/dev/null || true
	sleep 0.5
	open ~/Library/Developer/Xcode/DerivedData/Knob-bzvfuggowxngrqaciottolguhrsu/Build/Products/Debug/Knob.app

clean:
	xcodebuild -project Knob.xcodeproj -scheme Knob clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Knob-*

stop:
	pkill -x Knob 2>/dev/null || true
