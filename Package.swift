// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ZipReader",
    products: [
        .library(name: "ZipReader", targets: ["ZipReader"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZipReader",
            dependencies: [
                "CMinizip",
                "CShims",
            ]),
        .target(
            name: "CShims",
            dependencies: []
        ),
        .systemLibrary(
            name: "CMinizip",
            pkgConfig: "minizip"),
    ]
)
