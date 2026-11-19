// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-transcript",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Transcript", targets: ["Transcript"]),
        .library(name: "Transcript Dictation", targets: ["Transcript Dictation"]),
    ],
    traits: [
        .trait(name: "Dictation", description: "Transcript Dictation: a recording heard on the device by the system's dictation, as timed words")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-rational.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-rate.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-interval.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-ordinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-path.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-5646.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Transcript",
            dependencies: [
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "Rate", package: "swift-rate"),
                .product(name: "Interval", package: "swift-interval"),
                .product(name: "Ordinal", package: "swift-ordinal"),
            ]
        ),
        .target(
            name: "Transcript Dictation",
            dependencies: [
                .target(name: "Transcript"),
                .product(name: "Path", package: "swift-path", condition: .when(traits: ["Dictation"])),
                .product(name: "Path Foundation Integration", package: "swift-path", condition: .when(traits: ["Dictation"])),
                .product(name: "RFC 5646", package: "swift-rfc-5646", condition: .when(traits: ["Dictation"])),
            ]
        ),
        .testTarget(
            name: "Transcript Tests",
            dependencies: [
                .target(name: "Transcript")
            ]
        ),
        .testTarget(
            name: "Transcript Dictation Tests",
            dependencies: [
                .target(name: "Transcript"),
                .target(name: "Transcript Dictation"),
                .product(name: "Path", package: "swift-path"),
                .product(name: "RFC 5646", package: "swift-rfc-5646"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
