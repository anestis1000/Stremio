// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NativeTorrent", platforms: [.iOS(.v26)], products: [.library(name: "NativeTorrent", targets: ["TorrentLink"])], targets: [
    .binaryTarget(name: "NativeTorrent", path: "NativeTorrent.xcframework"),
    .target(name: "TorrentLink", dependencies: ["NativeTorrent"], linkerSettings: [.linkedLibrary("c++"), .linkedLibrary("z"), .linkedFramework("Security"), .linkedFramework("SystemConfiguration"), .linkedFramework("CFNetwork")])
])
