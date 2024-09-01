// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: [SwiftSetting] = []

let package = Package(
    name: "AzooKeyKanakanjiConverter",
    platforms: [.iOS(.v14), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftUtils",
            targets: ["SwiftUtils"]
        ),
        /// デフォルト辞書データを含むバージョンの辞書モジュール
        .library(
            name: "KanaKanjiConverterModuleWithDefaultDictionary",
            targets: ["KanaKanjiConverterModuleWithDefaultDictionary"]
        ),
        /// 辞書データを含まないバージョンの辞書モジュール
        .library(
            name: "KanaKanjiConverterModule",
            targets: ["KanaKanjiConverterModule"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
        // local package
        .package(url: "https://github.com/ensan-hcl/llama.cpp", branch: "b5cc30f"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftUtils",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            resources: [],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "KanaKanjiConverterModule",
            dependencies: [
                "SwiftUtils",
                .product(name: "llama", package: "llama.cpp"),
                .product(name: "Collections", package: "swift-collections")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "KanaKanjiConverterModuleWithDefaultDictionary",
            dependencies: [
                "KanaKanjiConverterModule"
            ],
            exclude: [
                "azooKey_dictionary_storage/README.md",
                "azooKey_dictionary_storage/LICENSE",
            ],
            resources: [
                .copy("azooKey_dictionary_storage/Dictionary"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "CliTool",
            dependencies: [
                "KanaKanjiConverterModuleWithDefaultDictionary",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftUtilsTests",
            dependencies: ["SwiftUtils"],
            resources: [],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "KanaKanjiConverterModuleTests",
            dependencies: ["KanaKanjiConverterModule"],
            resources: [
                .copy("DictionaryMock")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "KanaKanjiConverterModuleWithDefaultDictionaryTests",
            dependencies: [
                "KanaKanjiConverterModuleWithDefaultDictionary",
                .product(name: "Collections", package: "swift-collections")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
