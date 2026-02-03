.PHONY: build run clean icon

ICON_SRC = Knob/AppIcon.svg
ICON_OUT = Knob/AppIcon.icns

icon: $(ICON_SRC)
	rm -rf .icon_build
	mkdir -p .icon_build/Assets.xcassets/AppIcon.appiconset .icon_build/out
	for size in 16 32 64 128 256 512; do \
		sips --resampleHeightWidth $$size $$size -s format png $(ICON_SRC) --out .icon_build/Assets.xcassets/AppIcon.appiconset/icon_$$size.png; \
	done
	echo '{"images":[' \
		'{"filename":"icon_16.png","idiom":"mac","scale":"1x","size":"16x16"},' \
		'{"filename":"icon_32.png","idiom":"mac","scale":"2x","size":"16x16"},' \
		'{"filename":"icon_32.png","idiom":"mac","scale":"1x","size":"32x32"},' \
		'{"filename":"icon_64.png","idiom":"mac","scale":"2x","size":"32x32"},' \
		'{"filename":"icon_128.png","idiom":"mac","scale":"1x","size":"128x128"},' \
		'{"filename":"icon_256.png","idiom":"mac","scale":"2x","size":"128x128"},' \
		'{"filename":"icon_256.png","idiom":"mac","scale":"1x","size":"256x256"},' \
		'{"filename":"icon_512.png","idiom":"mac","scale":"2x","size":"256x256"},' \
		'{"filename":"icon_512.png","idiom":"mac","scale":"1x","size":"512x512"}' \
		'],"info":{"author":"xcode","version":1}}' \
		> .icon_build/Assets.xcassets/AppIcon.appiconset/Contents.json
	echo '{"info":{"author":"xcode","version":1}}' > .icon_build/Assets.xcassets/Contents.json
	xcrun actool .icon_build/Assets.xcassets \
		--compile .icon_build/out \
		--platform macosx \
		--minimum-deployment-target 13.0 \
		--app-icon AppIcon \
		--output-partial-info-plist .icon_build/out/Info.plist
	mv .icon_build/out/AppIcon.icns $(ICON_OUT)
	rm -rf .icon_build

build: $(ICON_OUT)
	xcodebuild -project Knob.xcodeproj -scheme Knob -configuration Release -derivedDataPath build

$(ICON_OUT): $(ICON_SRC)
	$(MAKE) icon

run: build
	pkill -x Knob 2>/dev/null || true
	sleep 0.5
	open build/Build/Products/Release/Knob.app

clean:
	xcodebuild -project Knob.xcodeproj -scheme Knob clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Knob-*

stop:
	pkill -x Knob 2>/dev/null || true
