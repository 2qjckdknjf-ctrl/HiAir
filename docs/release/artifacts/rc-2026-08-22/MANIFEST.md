# Release artifact manifest — RC 2026-08-22

**Status:** simulator / unsigned release artifacts only (no store signing credentials in this worktree).

| Field | Value |
|-------|-------|
| Git SHA | `e73c3c5739c73e2205a9c2b952291dc6fc83805f` |
| Branch | `cursor/store-ready-hardening-2026-08-22` |
| iOS build | 213 (simulator Debug) |
| Android versionCode | 189 |
| Android targetSdk | 36 |

## Toolchain

| Tool | Version |
|------|---------|
| Xcode | Xcode 26.6 |
| iOS SDK | 26.5 |
| JDK | openjdk version "17.0.14" 2025-01-21 |
| Python (backend tests) | Python 3.14.4 |

## Artifacts

| `/Users/alex/Projects/HIAir-store-ready/mobile/android/app/build/outputs/bundle/release/app-release.aab` | Android release | `5040803de49c71d463990722d80ca4c64a36c08a6a56091a144d51885396f50a` |
| `/Users/alex/Library/Developer/Xcode/DerivedData/HiAir-fpjtpkemefdifidhwgqigzmweavq/Build/Products/Debug-iphonesimulator/HiAir.app` | iOS simulator .app bundle | `` |

## Reproduce

```bash
# Backend
cd backend && . .venv/bin/activate && pytest

# iOS simulator
cd mobile/ios && xcodebuild -project HiAir.xcodeproj -scheme HiAir -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test

# Android release (unsigned if no keystore)
export JAVA_HOME=/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home
cd mobile/android && ./gradlew assembleRelease bundleRelease
```
