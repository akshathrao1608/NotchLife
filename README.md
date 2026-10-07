# LifeNotch

A Dynamic Island-style app for the MacBook camera notch. A slim black bar sits around the
notch showing small live info; hover to peek, click to open a full panel with 8 tabs:
**AI Search, Browser, Messages, Assignments, Sports, Mini Games, Mac Fun, Settings.**

Built with Swift + SwiftUI (AppKit for the window, WKWebView for the browser, App Intents for
Shortcuts). Everything is explained in simple language in
[`docs/FILES_EXPLAINED.md`](docs/FILES_EXPLAINED.md).

---

## Please read first: honest status

This code was written in a Linux sandbox that has **no Swift compiler and no Mac**, so it has
**never been built or run**. What was checked there:

| Checked | How |
|---|---|
| Swift syntax of all 77 Swift files (75 app + 2 test) | parsed with a Swift grammar (finds typos and unbalanced braces) |
| Built-in word list (every Word Rush seed is in the dictionary, enough hidden words) | script |
| Safari extension JSON/JS syntax | parsed |

What was **not** checked: type-checking, the AppKit/SwiftUI behaviour, the notch drawing, the
animations, sounds, WKWebView behaviour, or any network call to an AI/sports provider. Expect to
fix a handful of small compile errors the first time you build; Xcode will point at each line.
I'd also expect to tweak spacing and the notch alignment on your actual screen.

The unit tests in `Tests/` are written but have not been run either (`swift test` on your Mac).

---

## Requirements

- A Mac running **macOS 14 (Sonoma) or newer** (works on non-notch Macs too, as a slim pill bar).
- **Xcode 15 or newer** (free from the App Store), or just the Command Line Tools.

## How to run it (pick one)

**A. Easiest: Xcode**
1. Open Xcode, choose *File > Open…*, and select this project folder (or `Package.swift`).
2. Pick the **LifeNotch** scheme and press **Run** (▶).

**B. Make a real double-clickable app**
```bash
./Scripts/build_app.sh     # builds build/LifeNotch.app
open build/LifeNotch.app
```
*(First launch: if macOS complains, right-click the app and choose Open.)*

> Notifications only work from the real `LifeNotch.app` (option B), not from a plain Xcode
> "swift run". Everything else works either way.

LifeNotch has **no Dock icon**. Look for the small ✨ icon in the menu bar: it always lets you
open Settings or **Quit**.

## First-run checklist

1. Move your mouse to the notch: the bar grows (preview). Click it to open the panel.
2. Press **Option + Space** from any app to open/close; **Esc** closes.
3. Settings > Appearance: try the themes and animations.
4. (Optional) Add an AI key: Settings > "AI provider and API key". See below.

---

## What each tab does

| Tab | Highlights |
|---|---|
| **AI Search** | 7 modes (Explain simply, Homework help, Summarise, Find sources, Check my answer, Translate, Quiz me). Short answer first, then explanation, then **Verified** vs **Uncertain** sections. Drag/drop or attach screenshots, images, PDFs, text files. Sources appear as clickable links when web search is on. Copy, save to notes, share to Apple Notes, add to an assignment. Always labelled *AI-generated*. Homework mode teaches the method and only gives the full solution if you tick **Show full solution**. |
| **Browser** | Address bar: type a website or a search. WKWebView with back/forward/reload/stop, zoom, copy link, open in default browser, Focus Reader, pinned sites, optional history, private mode, pop-up blocking, download + suspicious-link warnings, Ask AI about this page, save to notes/assignments. |
| **Messages** | Safe hub (off by default). See [Messages](#messages-what-it-does-and-doesnt-do). |
| **Assignments** | Subject, title, due date/time, priority, notes, link/file, status. Sorted by due date, red warning inside 24 h, AI helpers (steps, explain, revision plan, practice questions, check my draft), JSON/CSV export. |
| **Sports** | F1: next race + countdown, latest podium, standings. Football: fixtures for your teams, live/recent scores, league table. Demo Data unless you choose a live source. |
| **Mini Games** | Reaction Time, Memory Match, Quick Maths, Penalty Shootout, F1 Reaction Lights, Word Rush. Keyboard + mouse, saved best scores, mute button. |
| **Mac Fun** | Pomodoro + study streak, daily quote/F1/football fact + Random Fun, quick launch, notes + optional clipboard history, system dashboard, Clean Desk checklist, ambient sounds, theme/animation picker. |
| **Settings** | Appearance, themes, animation speed, reduce motion, search engine, favourite teams/driver, AI key, privacy, backup/export, reset, accessibility. |

### Keyboard shortcuts

| Keys | What |
|---|---|
| Option + Space | open/close the notch from anywhere (you can change it in Settings) |
| Esc | close the panel |
| Option + A / B / S / G / T | AI / Browser / Sports / Games / Focus timer *(while the notch is open)* |
| ⌘1 … ⌘8 | switch tabs |

Option+A/B/S/G/T only work while the notch is open, on purpose: registering them globally would
steal those keys from every other app (Option+A types "å").

---

## Privacy and safety (how the rules were applied)

- **No permissions are requested up front.** The app does not use the camera, microphone,
  contacts, location, screen recording, Accessibility or Apple Events. Nothing like that is in
  `Info.plist`. Websites in the browser that ask for camera/mic are always refused.
- **Ask first.** Before sending a file to the AI, reading the clipboard, or looking inside
  Desktop/Downloads, you get a plain-language question: *Allow once / Always allow / Don't allow*.
  "Always allow" answers can be undone in Settings > Privacy.
- **Messages:** LifeNotch never reads the Messages app, its database, or other apps'
  notifications. See below.
- **Never deletes or changes things on its own.** Clean Desk only reads names/sizes/dates (after
  you press Scan). It never deletes, moves or renames anything. "Reset app data" only removes
  LifeNotch's own saved data, after two confirmations. No Terminal commands run automatically.
- **No private APIs.** Only documented Apple APIs are used. The global shortcut uses
  `RegisterEventHotKey` (no Accessibility permission needed). Screen/notch size uses
  `safeAreaInsets` and `auxiliaryTopLeftArea`.
- **You choose what is stored.** Browsing history, AI chat memory, clipboard history and message
  notices are all **off by default**. Settings > Privacy lists exactly what is stored and has a
  "Show data folder" button. Everything lives in `~/Library/Application Support/LifeNotch/`.
  Nothing is synced or uploaded; there is no iCloud or cloud-storage feature.
- **Screenshots and documents** are sent only to the AI provider you picked, only for the one
  question you press Send on, and are never saved by LifeNotch. Images are shrunk and re-encoded
  first, which also strips hidden photo data such as GPS location. LifeNotch has no cloud
  file-storage option at all, so there is nothing to enable.
- **Demo data is never disguised.** Every sports card shows an orange **Demo Data** badge, the
  compact-bar countdown turns orange, and no reminders are ever scheduled for demo events. If you
  pick a live source that fails, you see the error, not silent demo data.
- **Private mode** uses a throw-away WebKit data store: no history, and cookies/cache/form data are
  discarded when you leave private mode or quit.

## Adding your AI key (optional)

AI features need your own key; the rest of the app works without one.

1. Settings > **AI provider and API key**. Pick Anthropic (Claude) or OpenAI.
2. Press the link to your provider's key page, create a key, copy it.
3. Paste it into the box and press **Save key**. It goes into the **macOS Keychain**. It is never
   shown again, never in a file, never in backups. **Remove key** deletes it.
4. The model name is editable (defaults: `claude-sonnet-5-5` and `gpt-4.1`). If your account uses
   a different model, type its name there.

You pay your provider directly. Web search (the 🌐 button / *Find sources* mode) uses the
provider's own web-search tool; it must be available on your account.

## Sports data

| Source | Needs | Notes |
|---|---|---|
| **Demo Data** (default) | nothing | Made-up numbers, always labelled. |
| Live F1 | nothing | Free community API (`api.jolpi.ca`, Ergast-compatible). Sends a plain request, no personal data. |
| Live football | free key from football-data.org | Key stored in the Keychain. Without a key you get labelled Demo Data. |

The data source is a small interface: to use a different provider, write one struct that returns
the models in `Sports/SportsModels.swift` and select it in `SportsModel.makeF1Provider()` /
`makeFootballProvider()`. Nothing else changes.

## Messages: what it does and doesn't do

macOS does not let apps read other apps' notifications or the Messages database without very
invasive permissions, and LifeNotch deliberately never asks for them. So the hub works like this:

- It is **off** until you turn it on and confirm.
- It shows **notices that you send to it** from a Shortcut/automation you build (an App Intent
  "Add a Message Notice to LifeNotch"), or from a `lifenotch://notice?token=…` link. The link
  carries a private token stored in your Keychain, so a web page cannot fake notices.
- Previews are **off by default** (and when off, the preview text is not even stored).
  **Do Not Disturb** hides previews but keeps the unread count.
- You can open the Messages app (or a specific chat, using a phone number/email *you typed*) from
  the tab. No Contacts access is needed.

## Shortcuts (App Intents)

`Messages/AppIntents.swift` adds actions: *Open a LifeNotch Tab*, *Start Focus Timer*,
*Add an Assignment*, *Add a Message Notice*. Shortcuts only lists them when the app is built
with **Xcode** (it extracts them at build time), not with `build_app.sh`. The `lifenotch://`
links work either way.

## Optional Safari extension

See [`SafariExtension/README.md`](SafariExtension/README.md). It is not needed (the Browser tab has
the same button) and it is untested.

## Known limits / things to know

- **Wi-Fi name is not shown** (it would need the Location permission). The dashboard says
  connected / not connected.
- **Focus Reader** is LifeNotch's own simple article extractor (Safari's Reader is not available to
  apps). It works on article-style pages and says so when it can't find one.
- **Ambient sounds** are generated by code (no audio files), so they are simple impressions, not
  recordings.
- **Hover-to-preview and the notch alignment** depend on your display scaling; if the bar looks a
  few points off, the numbers to tweak are in `Notch/NotchGeometry.swift` and `NotchState.swift`.
- Games use `onKeyPress` for keys. If a game doesn't react to the keyboard, click it once first;
  the mouse always works.
- Hovering needs the app to be running (it has no Dock icon; use the menu-bar ✨ to quit).

## Project layout

```
Package.swift            how Swift builds the app
Resources/Info.plist     app identity (no Dock icon, lifenotch:// links)
Scripts/build_app.sh     makes build/LifeNotch.app
Sources/LifeNotch/
  App/          start-up, the object that holds everything
  Notch/        the floating panel, shape, animation, compact bar, tabs header
  Tabs/         one screen per tab (+ settings cards)
  AI/           AI clients, prompts, attachments
  Browser/      WKWebView model, URL safety, history
  Assignments/  assignment model + storage
  Sports/       sports models, providers, demo data
  Games/        6 games, scores, word list
  MacFun/       focus timer, streak, sounds, system stats, clean desk, clipboard
  Messages/     message hub, links, Shortcuts actions
  Core/         settings, storage, Keychain, permissions, shared UI pieces
Tests/          unit tests (swift test)
SafariExtension/ optional Safari extension
docs/           file-by-file explanation
```

## Build order followed

1. Notch shell + animation → 2. AI Search (text) → 3. Images/PDF → 4. Browser → 5. Assignments + Pomodoro
→ 6. Sports (demo) → 7. Mini games → 8. Mac Fun → 9. Messaging hub → 10. Safari extension.
The git history has one commit per step.
