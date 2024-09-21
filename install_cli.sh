swift build -c release -Xcxx -xobjective-c++
cp -f .build/release/CliTool /usr/local/bin/anco

# FIXME: Unfortunately, in order to use zenzai in anco, you will need to build CliTool with xcodebuild
#        It is highly desirable to make it work only with `swift build`
# For Xcode 16 or later
# xcodebuild -scheme CliTool -destination "platform=macOS,name=My Mac" -configuration Release 
# For Xcode 15 or former
# xcodebuild -scheme CliTool -destination "platform=macOS,name=Any Mac" -configuration Release
