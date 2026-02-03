.PHONY: build release run clean icon

ICON_SRC = screenshots/Content_Knob_at_80_percent.png
ICON_OUT = Knob/AppIcon.icns

icon: $(ICON_SRC)
	rm -rf AppIcon.iconset
	mkdir AppIcon.iconset
	sips -z 16 16     $(ICON_SRC) --out AppIcon.iconset/icon_16x16.png
	sips -z 32 32     $(ICON_SRC) --out AppIcon.iconset/icon_16x16@2x.png
	sips -z 32 32     $(ICON_SRC) --out AppIcon.iconset/icon_32x32.png
	sips -z 64 64     $(ICON_SRC) --out AppIcon.iconset/icon_32x32@2x.png
	sips -z 128 128   $(ICON_SRC) --out AppIcon.iconset/icon_128x128.png
	sips -z 256 256   $(ICON_SRC) --out AppIcon.iconset/icon_128x128@2x.png
	sips -z 256 256   $(ICON_SRC) --out AppIcon.iconset/icon_256x256.png
	sips -z 512 512   $(ICON_SRC) --out AppIcon.iconset/icon_256x256@2x.png
	sips -z 512 512   $(ICON_SRC) --out AppIcon.iconset/icon_512x512.png
	iconutil -c icns AppIcon.iconset -o $(ICON_OUT)
	rm -rf AppIcon.iconset

build: $(ICON_OUT)
	xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Debug build

release: $(ICON_OUT)
	xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Release -derivedDataPath build

$(ICON_OUT): $(ICON_SRC)
	$(MAKE) icon

run: build
	pkill -x Knob 2>/dev/null || true
	sleep 0.5
	open ~/Library/Developer/Xcode/DerivedData/Knob-bzvfuggowxngrqaciottolguhrsu/Build/Products/Debug/Knob.app

clean:
	xcodebuild -project Knob.xcodeproj -scheme Knob clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Knob-*

stop:
	pkill -x Knob 2>/dev/null || true
