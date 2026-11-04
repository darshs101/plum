# Plum

Plum is a dish-first social food journal for Atlanta, built with SwiftUI.

## Run locally

The checked-in `Package.swift` builds the Foundation-only domain layer on machines with Swift:

```sh
swift build
```

The iPhone UI needs Xcode 16+ because it uses SwiftUI and targets iOS 17. Generate an Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
open Plum.xcodeproj
```

The first working version uses local sample data. Supabase integration, live authentication, photo upload, notifications, and moderation tooling are planned backend work rather than hard-coded into the client.
