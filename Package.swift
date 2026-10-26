// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TextRefiner",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TextRefiner", targets: ["TextRefiner"])],
    targets: [.executableTarget(name: "TextRefiner")]
)
