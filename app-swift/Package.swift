// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ctx",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Ctx", targets: ["CtxApp"])
    ],
    targets: [
        .executableTarget(
            name: "CtxApp",
            path: "Sources/CtxApp"
        )
    ]
)
