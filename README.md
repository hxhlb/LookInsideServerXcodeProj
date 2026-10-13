# LookInsideServer Xcode Project

`LookInsideServer.xcodeproj` is a small integration project for apps that want
LookInside available in debug builds without adding any source code.

## Background

LookInsideServer is a debug-only runtime. CocoaPods can model that cleanly in a
podspec by applying Debug-only build settings, so CocoaPods consumers do not need
this project.

Swift Package Manager has a different limitation: it can apply some build
settings conditionally by configuration, but it cannot make a target dependency
exist only for Debug and disappear for Release. A binary framework added through
SPM therefore remains part of the target dependency graph in Release as well.

This project exists as a lightweight Xcode-native workaround for that gap. Apps
depend on one stable `LookInsideServer.framework` product from this project. The
project then decides what that product contains for each build configuration.

The project always exposes a single framework product:

```text
LookInsideServer.framework
```

In Release builds this framework is an empty placeholder. In Debug builds a
build script downloads the signed LookInsideServer binary XCFramework, verifies
its checksum, selects the matching platform slice, and replaces the placeholder
framework with the real debug server framework.

## Integration

1. Add `LookInsideServer.xcodeproj` to your app workspace or drag it into your
   app project.
2. Open your app target settings.
3. Under **Frameworks, Libraries, and Embedded Content**, add
   `LookInsideServer.framework` from the `LookInsideServer` project.
4. Set the framework to **Embed & Sign**.
5. Build and run your app in Debug.

No `import` and no startup code are required. The debug server starts when the
framework is loaded by the app.

## Build Behavior

Debug builds:

- Download `LookInsideServer.xcframework.zip` from the configured release URL.
- Verify the SHA-256 checksum before using it.
- Pick the slice for the current platform:
  - `iphoneos` -> `ios-arm64`
  - `iphonesimulator` -> `ios-arm64_x86_64-simulator`
  - `macosx` -> `macos-arm64_x86_64`
  - Mac Catalyst -> `ios-arm64_x86_64-maccatalyst`
- Replace the generated placeholder `LookInsideServer.framework`.
- Re-sign the framework when Xcode enables code signing.

Release builds:

- Skip the download step.
- Keep the empty placeholder framework.
- Do not include the LookInside debug server binary.

## Artifact Configuration

The artifact URL and checksum live in:

```text
Scripts/materialize-lookinside-server.sh
```

When publishing a new LookInsideServer binary release, update both values in the
script.

## Troubleshooting

If Debug builds fail during the materialization step, check that the build
machine can reach GitHub Releases and that the checksum in the script matches
the downloaded zip.

If the app launches but LookInside cannot connect, confirm that the app target
embeds `LookInsideServer.framework` and that the build configuration is Debug.

## Sponsor

This project is sponsored by [AirBuild](https://air.build/).
