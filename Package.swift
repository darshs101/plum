// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Plum",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PlumDomain", targets: ["PlumDomain"])
    ],
    targets: [.target(name: "PlumDomain")]
)
