# swift build -c release
# cp -f .build/release/CliTool /usr/local/bin/anco

rm -rf /Users/miwa/Library/Developer/Xcode/DerivedData/AzooKeyKanaKanjiConverter-gwqaeepzrrcgaudozfojheujabwm/Build/Products/Debug
xcodebuild -scheme CliTool -destination "platform=macOS,name=Any Mac"
sudo cp -f /Users/miwa/Library/Developer/Xcode/DerivedData/AzooKeyKanaKanjiConverter-gwqaeepzrrcgaudozfojheujabwm/Build/Products/Debug/CliTool /usr/local/bin/anco
