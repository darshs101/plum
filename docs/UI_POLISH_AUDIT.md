# Plum UI polish

Applied the better-ui skill to the native SwiftUI surfaces inspected below. Kept the cream/plum palette, SF Symbols, native forms and tab bar, and existing flat surface convention. No database or authentication behavior was changed.

## Concentric surfaces

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM, fixed | `PlumApp/Home/HomeView.swift:36`; `PlumApp/ExploreView.swift:119`; `PlumApp/Create/CreatePostView.swift:169`, `:331` | Feed outer radius 20 around radius-14 media with 14 inset; search outer radius 17 around radius-13 icon with 10 inset; composer outer radius 16 around radius-10 content with 14 inset | Feed 28; search 23; nested composer surfaces 24 | Outer radius equals inner radius plus padding, producing visually even corners. |

## Consistent actions and press feedback

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| MEDIUM, fixed | `PlumApp/Shared/PlumStyle.swift:11`; `PlumApp/Auth/WelcomeView.swift:37`; `PlumApp/Create/CreatePostView.swift:221` | Unrelated bordered, text-only, and custom submit treatments without shared press handling | Primary/secondary styles with radius 14, 50-point minimum height; enabled press scale 0.96 over 150 ms ease-out; disabled opacity 0.45 with no scale | Consistent action surfaces and interruptible press feedback. Reduce Motion uses opacity without movement. `isStatic` opts out of scale. Native Apple sign-in remains native. |

## Content image outlines

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| LOW, fixed | `PlumApp/Shared/PlumStyle.swift:32`; `PlumApp/Home/HomeView.swift:62`; `PlumApp/ProfileView.swift:54`; `PlumApp/Directory/DirectoryDetailView.swift:23`; `PlumApp/Create/CreatePostView.swift:179`; `PlumApp/Create/EditPostView.swift:47` | Photos had no consistent edge treatment | One physical pixel, inset one pixel, pure black at 10% in light appearance and white at 10% in dark appearance; overlay does not intercept touches | Image outlines define photo boundaries without a colored fringe or changing layout. |

## Icon states

| Severity | Location | Before | After | Why |
| --- | --- | --- | --- | --- |
| LOW, fixed | `PlumApp/Auth/WelcomeView.swift:36`; `PlumApp/Create/CreatePostView.swift:152` | Filled default symbols and a black photo action icon on a plum action surface | Outline variants with inherited button color; photo action explicitly plum | Outline defaults and consistent icon color. Rating stars still use fill to represent their selected value. Native tab rendering is preserved. |

## Verification

- Actual iOS application target: `BUILD SUCCEEDED`, `/tmp/plum-ui-polish-build.log`, producing `/tmp/plum-root-final/Build/Products/Debug-iphonesimulator/Plum.app`.
- Installed and launched `com.plum.app` on iPhone 18 Pro simulator `DE2DAAE8-4A9B-4BF3-B23A-0F056E92756F`.
- Visually inspected empty Home and composer screenshots, `/tmp/plum-ui-polish.png` and `/tmp/plum-ui-composer.png`. The active session was preserved; no account data was changed.
- Read the enabled, pressed, disabled, static, and Reduce Motion branches of the shared action style. Only scale and opacity change on press. Routine rows, typing, and tabs receive no added animation. No new entrance or exit animation was introduced.
- Not verified: live press/release timing or interrupted presses, runtime Reduce Motion switching, dark-mode image edges, welcome-screen runtime appearance, and populated feed/profile/directory photo edges. These have source inspection only. Browser animation replay is inapplicable to this native app.

Approve — inspected code and the Home/composer visual scope only. No HIGH finding remains in that scope; this is not full-app visual or v1 acceptance sign-off.
