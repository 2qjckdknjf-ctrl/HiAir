# HiAir Release Artifacts Manifest

Generated at (UTC): 2026-04-26T21:20:43.033958+00:00

| Artifact | Exists | Path | Size (bytes) | SHA256 |
|---|---|---|---:|---|
| Android AAB | yes | `/Users/alex/Projects/HIAir/mobile/android/app/build/outputs/bundle/release/app-release.aab` | 4525283 | `964d10679969ffdb71b1678e77d5f502a9d79d3aa88124b109aa8bf7cfc6642d` |
| Android debug APK | yes | `/Users/alex/Projects/HIAir/mobile/android/app/build/outputs/apk/debug/app-debug.apk` | 6419152 | `4f42f174fef84e02d637e68c887032089a130f5544a61e52a1cc6921487a66fa` |
| iOS xcarchive | yes | `/Users/alex/Projects/HIAir/mobile/ios/build/HiAir.xcarchive` | 4383224 | `d2d551632cd6fe3fff9fab83db213dba58cefbdaf64e0d1a1d8e2c5733a54bd4` |
| iOS IPA | yes | `/Users/alex/Projects/HIAir/mobile/ios/build/HiAir.ipa` | 441863 | `843a8e957abb672484e6410235b356dcf08311ac17b543bbcd50bcc126a4bbc7` |

Use this file as upload evidence for TestFlight/Internal Test.

## Closed Beta RC policy
- iOS IPA: present (export completed outside repo with signing credentials).
- `--rc` mode: mandatory artifacts are Android AAB + iOS xcarchive only (same gate as `--strict`). Missing IPA does not fail the generator.