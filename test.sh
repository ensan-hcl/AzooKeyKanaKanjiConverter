wget https://dl.google.com/android/repository/android-ndk-r27-linux.zip
unzip android-ndk-r27-linux.zip

wget https://github.com/finagolfin/swift-android-sdk/releases/download/5.10/swift-5.10-android-24-sdk.tar.xz
tar Jxfv swift-5.10-android-24-sdk.tar.xz

ln -sf /usr/bin/clang swift-5.10-android-24-sdk/usr/lib/swift/clang

wget https://download.swift.org/swift-5.10.1-release/ubuntu2204/swift-5.10.1-RELEASE/swift-5.10.1-RELEASE-ubuntu22.04.tar.gz
tar -zxvf swift-5.10.1-RELEASE-ubuntu22.04.tar.gz

swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/swift build --build-tests --destination swift-android-sdk/android-aarch64.json -Xlinker -rpath -Xlinker swift-5.10-android-24-sdk/usr/lib/aarch64-linux-android
swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/swift build --build-tests --destination swift-android-sdk/android-x86_64.json -Xlinker -rpath -Xlinker swift-5.10-android-24-sdk/usr/lib/x86_64-linux-android

C:\Users\fukuda\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe push "D:\AzooKeyKanaKanjiConverter\swift-5.10-android-24-sdk.tar.xz" /data/local/tmp
C:\Users\fukuda\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe push "D:\AzooKeyKanaKanjiConverter\.build\aarch64-unknown-linux-android24\debug\AzooKeyKanakanjiConverterPackageTests.xctest" /data/local/tmp
C:\Users\fukuda\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe push "D:\AzooKeyKanaKanjiConverter\.build\x86_64-unknown-linux-android24\debug\AzooKeyKanakanjiConverterPackageTests.xctest" /data/local/tmp

../swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/swift build -j 1 --build-tests --destination ../swift-android-sdk/android-x86_64.json -Xlinker -rpath -Xlinker ../swift-5.10-android-24-sdk/usr/lib/x86_64-linux-android --verbose

C:\Users\fukuda\AppData\Local\Microsoft\WinGet\Packages\Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe\platform-tools\adb.exe push "D:\AzooKeyKanaKanjiConverter\swift-collections\.build\debug\swift-collectionsPackageTests.xctest" /data/local/tmp
