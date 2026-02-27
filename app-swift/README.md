# Ctx Swift App Scaffold

This folder contains Swift source scaffolding for the menu bar app wrapper.

## Next setup steps
1. Create an AppKit or SwiftUI macOS app target in Xcode at `app-swift/`.
2. Add files from `app-swift/Ctx/` to the target.
3. Bundle `ctx-core` at `Ctx.app/Contents/MacOS/ctx-core` in build phase.
4. Ensure Automation entitlements/plist usage descriptions are configured for Safari scripting.
