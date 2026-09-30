# ReviewGate: a written "definition of reviewable" for iOS pull requests

A small Swift library that decides whether a pull request is ready for a human, from the diff and the evidence attached to it. Companion code for the Medium article "A Checklist Passed 10 of 12 Pull Requests. Four Agent-Written PRs Weren't Reviewable." ([read it on Medium](https://medium.com/@er.rajatlakhina/a-checklist-passed-10-of-12-pull-requests-four-agent-written-prs-werent-reviewable-75cd40e65a3f)).

The point is one distinction: **evidence that is present** versus **evidence that is about this diff**. A checklist that only asks "is there a screenshot?" waves through a screenshot of the wrong screen.

## What it does

`RiskClassifier` reads changed paths and added lines and decides which of five surfaces a PR touches: `ui`, `concurrency`, `entitlements`, `hotPath`, `assumptions`. `ReviewGate.evaluate` then requires one kind of evidence per surface and marks each finding `satisfied`, `missing`, or `vacuous`.

```swift
let report = ReviewGate.evaluate(packet)          // PullRequestPacket → ReadinessReport
report.verdict                                    // .reviewable / .notReviewable
report.blocking.map(\.reason)                     // itemised, human-readable
```

| Surface | Triggered by | Evidence that counts |
|---|---|---|
| ui | `*View.swift`, `/Views/`, SwiftUI/UIKit lines | screenshot or snapshot diff whose `covers` names a changed view |
| concurrency | `@MainActor`, `actor`, `nonisolated`, `Task {`, … in added lines | isolation note ≥ 40 chars that names a changed type |
| entitlements | `.entitlements`, `Info.plist`, `PrivacyInfo.xcprivacy` | note ≥ 40 chars that names the changed file |
| hotPath | configurable path prefixes | benchmark with a baseline, a candidate, and ≥ 5 runs |
| assumptions | agent-authored PR touching ≥ 3 files | at least one real assumption (not "none" / "n/a") |

Every threshold lives in `ReviewPolicy`. The library is the rule set only: a hook or CI job would need a small runner that builds a `PullRequestPacket` (it is `Codable`) from the diff. Note that the "names the changed file/type" checks are case-sensitive substring matches on the file stem, so they raise the price of vague evidence and can still be gamed.

## Results on the bundled fixtures

Twelve **constructed** pull requests (`Fixtures.swift`), each built to exercise one branch. They are not data from a real team.

| Gate | Reach a person |
|---|---|
| Nothing gated | 12 / 12 |
| Presence-only checklist | 10 / 12 |
| ReviewGate | 6 / 12 |

Across the twelve: 2 missing findings, 6 vacuous findings, and 104 minutes of reviewer discovery blocked at the default policy weights (`ReviewPolicy.discoveryMinutes`, which are weights you set from your own history, not measurements). All of these numbers are asserted in `testBatchSummaryNumbers`.

## Run it

```
git clone https://github.com/rajatslakhina/review-readiness-gate-article-demo
cd review-readiness-gate-article-demo
open Demo.xcodeproj      # pick an iPhone Simulator, Build & Run (untested; see Verification status)
swift test               # 14 tests
```

`Demo.xcodeproj` consumes the library through a local package reference; there is no second repo to fetch.

## Verification status

- `swift build` and `swift test` (14 tests, 0 failures) were run on Swift 6.1.3 on Linux. `ReviewGateView` is guarded by `#if canImport(SwiftUI)`, so the SwiftUI screen was **not** compiled there.
- `Demo.xcodeproj/project.pbxproj` was hand-written and checked for brace/paren balance and dangling object ids. It has **not** been opened in Xcode.
- **The app was not run on a Simulator, and there is no screenshot of it.** The run that produced this repo was unattended and had no approval to drive Xcode. The images in `Article/` are generated diagrams, not screenshots.

Article: https://medium.com/@er.rajatlakhina/a-checklist-passed-10-of-12-pull-requests-four-agent-written-prs-werent-reviewable-75cd40e65a3f
