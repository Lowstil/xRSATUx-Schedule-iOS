// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UniSchedule",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "UniSchedule",
            targets: ["UniSchedule"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UniSchedule",
            path: "UniSchedule",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "UniScheduleTests",
            dependencies: ["UniSchedule"],
            path: "UniScheduleTests"
        )
    ]
)
