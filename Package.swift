// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PKShortVideo",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "PKShortVideo",
            targets: ["PKShortVideo"]
        )
    ],
    targets: [
        .target(
            name: "PKShortVideo",
            path: "PKShortVideo",
            exclude: [".DS_Store"],
            resources: [
                .process("PKAsset")
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("Category"),
                .headerSearchPath("GPUImage"),
                .headerSearchPath("PKShortVideoPlayer"),
                .headerSearchPath("PKShortVideoWriter"),
                .define("COREVIDEO_SILENCE_GL_DEPRECATION", to: "1"),
                .define("GLES_SILENCE_DEPRECATION", to: "1")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("OpenGLES"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
