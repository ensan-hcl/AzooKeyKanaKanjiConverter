swift build -c release -Xcxx -xobjective-c++
cp -f .build/release/CliTool /usr/local/bin/anco

# FIXME: Unfortunately, in order to use zenzai in anco, you will need to build CliTool with xcodebuild
#        It is highly desirable to make it work only with `swift build`
# xcodebuild -scheme CliTool -destination "platform=macOS,name=Any Mac" -configuration Release
