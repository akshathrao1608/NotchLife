// swift-tools-version:5.9
//
// Package.swift = the "recipe" Swift uses to build LifeNotch.
// You can open this file in Xcode (File > Open) and press Run,
// or build a double-clickable app with Scripts/build_app.sh.
import PackageDescription

let package = Package(
    name: "LifeNotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LifeNotch", targets: ["LifeNotch"])
    ],
    targets: [
        .executableTarget(
            name: "LifeNotch",
            path: "Sources/LifeNotch"
        )
    ]
)
