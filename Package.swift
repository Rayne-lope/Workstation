// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "BeadsKanbanSpike",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "BeadsContract",
            targets: ["BeadsContract"]
        ),
        .library(
            name: "BeadsWorkspace",
            targets: ["BeadsWorkspace"]
        )
    ],
    targets: [
        .target(
            name: "BeadsContract"
        ),
        .target(
            name: "BeadsWorkspace",
            dependencies: ["BeadsContract"]
        ),
        .testTarget(
            name: "BeadsContractTests",
            dependencies: ["BeadsContract"]
        ),
        .testTarget(
            name: "BeadsWorkspaceTests",
            dependencies: ["BeadsWorkspace"]
        )
    ]
)
