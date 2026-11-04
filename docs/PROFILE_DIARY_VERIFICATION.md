# Profile diary tabs and post dates

User-requested changes are reflected in the saved product specification.

| Requirement | Implementation | Acceptance |
| --- | --- | --- |
| Visit date becomes the displayed post date | `PostCalendarDate` encodes calendar days without UTC conversion; `LivePost.displayDate` uses visit date or creation date; feed/detail/diary share one date rendering | Simulator displays January 2, 2020 with no Visited prefix. Four domain regressions pass for UTC+14, UTC-8, leap/backdated days and invalid dates |
| Two icon tabs below profile counts | Grid and bookmark controls with selected underline and accessibility labels; diary grid and collection cards/creation remain separate | Simulator switches tabs, verifies collections are hidden on the grid tab and Saved Places appears on the bookmark tab; PHOTO DIARY heading absent |
| Scroll through own and other visible profile diaries | Profile grid opens `ProfileDiaryView` at the tapped post; one vertical lazy stack reuses all post actions, auto-loads pages and preserves access checks | Real two-account simulator flow opens the selected entry, scrolls upward to a newer entry, reaches entry 01 beyond the first 30, then signs into an approved follower and scrolls the owner's private diary |

## Evidence

- `/tmp/PlumProfileDiary3.xcresult`: 1 live simulator acceptance test passed, 0 failures (182.647 seconds). Fixtures were 32 new private posts plus an existing isolated post, so the owner flow crossed the 30-post page boundary.
- `/tmp/plum-date-domain-tests.log`: `swift test` passed 4 domain tests, 0 failures. These package checks are separate from the iOS app.
- `/tmp/plum-diary-final-build.log`: actual iOS application target reports `BUILD SUCCEEDED`; output `/tmp/plum-root-final/Build/Products/Debug-iphonesimulator/Plum.app` (`com.plum.app`).
- Inspected the selected-entry screenshot under `/tmp/plum-diary-attachments2` and final diary evidence under `/tmp/plum-diary-final-attachments`. `/tmp/plum-profile-tabs-final.png` shows the user's original profile with icon tabs directly beneath counts. Final thumbnail sizing constrains each photo to its own grid cell.
- The initial-position failure was corrected using `ScrollViewReader` after the first lazy layout. An inherited container accessibility identifier that masked child controls was removed before the final passing run.

`PostDetailView` supports a shared embedded layout for diary entries while retaining standalone post navigation elsewhere. Deleting an embedded post removes that entry rather than closing the whole diary. Pull-to-refresh refreshes existing card data; pagination has stable ordering, duplicate protection, and retry/loading states. Those source paths compile; delete-during-scroll and pull-to-refresh were not separately automated in this pass.

The final app is installed and launched on the original iPhone 18 Pro simulator, with the user's session preserved. UI tests used the separate QA simulator. Only isolated diary posts and their restaurant were soft-removed afterward; records remain preserved and the test restaurant is excluded from discovery. No schema migration was required.
