// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LittleA",
    platforms: [.iOS(.v16)],
    products: [
      .library(name: "LittleA", targets: ["LittleA"]),
      .library(name: "LittleAUI", targets: ["LittleAUI"])
    ],
    targets: [
        .binaryTarget(name: "LittleAFFI", path: "LittleAFFI.xcframework"),
        .target(
            name: "LittleA",
            dependencies: ["LittleAFFI"],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("iconv"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration")
            ]
            ),
            .target(
              name: "LittleAUI",
              dependencies: ["LittleA", "LittleAFFI"]
        )
    ]
)
