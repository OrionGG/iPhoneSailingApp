// Package.swift
// Swift package manifest for the SailTact app sources (open in Xcode for app target).
import PackageDescription

let package = Package(
    name: "SailTact",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "SailTact", targets: ["App"]),
    ],
    targets: [
        .target(
            name: "App",
            path: "Sources/App"
        ),
        .testTarget(
            name: "VMGTests",
            dependencies: ["App"],
            path: "Tests"
        )
    ]
)
