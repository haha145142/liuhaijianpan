# liuhaijianpan

This repository will host the merged iOS custom keyboard project based on:

- JevJarvis-liuhai-IOS (style & interaction baseline)
- goutou-keyboard-ios (reply/AI capability)

Planned steps
1. Add merged source files and modules in a feature branch `merge/goutou-integration`.
2. Add a GitHub Actions workflow to build an unsigned .ipa (macOS runner, xcodebuild).
3. Provide integration notes and a checklist of files to modify (KeyboardViewController, Network/AI client, PromptManager, Entitlements/App Group, Info.plist).

I will create the feature branch and add CI/workflow files after this initial commit.
