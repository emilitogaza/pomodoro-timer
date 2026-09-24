// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "Pomodoro", path: "Sources")]
)
