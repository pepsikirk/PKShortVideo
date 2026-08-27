# Contributing to PKShortVideo

Thanks for helping maintain PKShortVideo. This repository is an Objective-C iOS library for short-video recording, playback, and chat video components. Please keep contributions focused and compatible with the existing public API.

## Development environment

- Minimum deployment target: iOS 12.0.
- Xcode 26.2 has been validated locally.
- GitHub Actions currently validates the project with Xcode 26.6 on macOS 26.
- The project uses Objective-C and ARC.

Camera and microphone behavior should be checked on a physical iOS device when possible. A simulator is suitable for build and test-target checks, but it cannot fully validate camera recording.

## Clone, open, and build the Demo

Clone the repository:

```bash
git clone https://github.com/pepsikirk/PKShortVideo.git
cd PKShortVideo
```

Open `PKShortVideo.xcodeproj` in Xcode:

```bash
open PKShortVideo.xcodeproj
```

Select the `PKShortVideo` scheme, choose a simulator or device, and run the project. Use a physical device to check camera, microphone, video recording, and permission behavior. A development team may be required when running on a physical device.

For a code-signing-free build suitable for local verification or CI:

```bash
xcodebuild \
  -project PKShortVideo.xcodeproj \
  -scheme PKShortVideo \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

## Run tests

Run the unit-test and UI-test targets separately. This is also how CI runs them, and avoids starting both XCTest runners at the same time:

```bash
xcodebuild test \
  -project PKShortVideo.xcodeproj \
  -scheme PKShortVideo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -destination-timeout 120 \
  -only-testing:PKShortVideoTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

```bash
xcodebuild test \
  -project PKShortVideo.xcodeproj \
  -scheme PKShortVideo \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -destination-timeout 120 \
  -only-testing:PKShortVideoUITests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

If `iPhone 17` is not installed, replace the destination with an available iPhone simulator. The current test targets include unit-test and app-launch smoke coverage; hardware camera and microphone behavior still needs device testing.

If you change `PKShortVideo.podspec`, also run:

```bash
pod lib lint PKShortVideo.podspec --allow-warnings --verbose
```

The legacy GPUImage/OpenGL ES and Objective-C block-capture code currently produces known warnings. `--allow-warnings` permits that existing warning set; lint errors still fail.

## Bug reports

Before opening an issue, check whether it has already been reported. Include enough information to reproduce the problem:

- PKShortVideo version or Git commit.
- iOS version.
- Xcode version.
- Device model or simulator name and runtime.
- Clear reproduction steps and the expected and actual results.
- A crash log or relevant console log, if available.
- A small sample project or video file, when it is necessary to reproduce the issue.

Please remove private data, user identifiers, and credentials from logs before posting them.

## Pull requests

- Keep one pull request focused on one problem whenever practical.
- Explain why the change is needed, not only what files were changed.
- Describe how you tested the change, including the simulator or device used.
- Reference the related issue when one exists, for example `Fixes #123`.
- Keep the public Objective-C API and existing behavior unless the change specifically requires an API change.
- Avoid unrelated formatting, dependency, or architecture changes.

## Code style

Follow the existing Objective-C naming, formatting, ARC, and ownership conventions in the surrounding code. Prefer a small change that fits the current design over a broad rewrite. The AVPlayer-based `PKPlayerView` is the recommended modern playback path, while the GPUImage/OpenGL ES path remains available for compatibility; do not remove or replace the legacy path without a concrete reason.
