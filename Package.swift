// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macfuseGui",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "macfuseGui", targets: ["macfuseGui"])
    ],
    targets: [
        .executableTarget(
            name: "macfuseGui",
            path: "macfuseGui",
            exclude: ["Resources"],
            sources: [
                "App",
                "MenuBar",
                "Models",
                "Services",
                "ViewModels",
                "Views"
            ]
        ),
        .testTarget(
            name: "macfuseGuiTests",
            dependencies: ["macfuseGui"],
            path: "macfuseGuiTests"
        )
    ]
)
