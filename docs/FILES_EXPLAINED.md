# Every file, in simple language

Swift words you'll see:
- **struct / class** = a labelled box that holds data (and the actions that work on it).
- **enum** = a fixed list of choices (like the 8 tabs).
- **View** = a piece of screen. SwiftUI draws it for you.
- **ObservableObject / @Published** = "tell the screen to redraw when this changes".
- **@EnvironmentObject** = "get the shared box from the app instead of passing it by hand".

## How the whole thing fits together

1. `LifeNotchApp` starts → `AppDelegate` hides the Dock icon and creates the notch window.
2. `NotchPanelController` owns the window and decides when it grows/shrinks.
3. `NotchRootView` draws the black shape and shows either the **compact bar** or the **expanded
   panel**. The expanded panel shows one **tab view** at a time.
4. Each tab talks to a **model** (the thing that remembers data), all created once in
   `AppEnvironment`.
5. Everything you save goes into small JSON files in
   `~/Library/Application Support/LifeNotch/`. Secrets (API keys) go in the Keychain.

---

## Top level

| File | What it is |
|---|---|
| `Package.swift` | The recipe Swift uses to build the app and the tests. Says "needs macOS 14". |
| `Resources/Info.plist` | The app's ID card: name, no Dock icon, the `lifenotch://` link type. It deliberately does **not** list camera, microphone, contacts, location, etc. |
| `Scripts/build_app.sh` | Builds a double-clickable `build/LifeNotch.app`. Only writes inside this project's `build/` folder. |
| `README.md` | Start here. |

## `Sources/LifeNotch/App/`: starting up

| File | What it does |
|---|---|
| `LifeNotchApp.swift` | The front door (`@main`). Has no window of its own, because the notch panel is made by the AppDelegate. |
| `AppDelegate.swift` | Runs at launch: hides the Dock icon, creates the panel, adds the ✨ menu-bar icon (Open/Close, Settings, Quit), and receives `lifenotch://` links. |
| `AppEnvironment.swift` | Creates **every** model once and hands them to all screens. When you add a feature, you add its model here. |

## `Sources/LifeNotch/Notch/`: the notch itself (build step 1)

| File | What it does |
|---|---|
| `NotchGeometry.swift` | Measures the camera notch on your screen using Apple's public screen info. On Macs without a notch it makes a slim pill instead. |
| `NotchShape.swift` | The outline of the black panel: curved-outwards ("concave") top corners that flow into the screen edge, normal rounded bottom corners. |
| `NotchState.swift` | Remembers "collapsed / preview / expanded", the chosen tab, and how big each state should be. |
| `NotchPanel.swift` | The see-through borderless window (`NotchPanel`), the view that notices your mouse entering/leaving, and a helper so the first click works. |
| `NotchPanelController.swift` | The conductor. Positions the window at top-centre, runs the spring animation (grow the window → animate the shape → shrink the window), hover-to-preview, click-outside-to-close, and the keyboard shortcuts (Esc, Option+letters, ⌘1–8). |
| `HotKeyManager.swift` | Registers the global Option+Space shortcut with Apple's public hot-key call (no special permission). |
| `NotchRootView.swift` | Draws the shape, theme background and glow; swaps compact bar ↔ expanded panel. Also the star-field for the Space theme. |
| `CompactBarView.swift` | The slim bar's left/right "chips" (assignment due, countdown, focus timer, unread count, best score, AI/browser icons, battery/Wi-Fi/time) and the hover "peek" row. |
| `ExpandedPanelView.swift` | The open panel: the 8 tab icons on both sides of the camera notch, and the chosen tab below. |
| `NotchAnimationView.swift` | The little pulse / racing lights / football bounce / waveform decoration. Still image if Reduce Motion is on. |

## `Sources/LifeNotch/Core/`: shared building blocks

| File | What it does |
|---|---|
| `Enums.swift` | All the "lists of choices": tabs, themes, search engines, AI modes, game kinds… |
| `Preferences.swift` | **All settings in one box.** Saved as JSON in UserDefaults. New settings added later get defaults automatically. |
| `AppSettings.swift` | The object screens read/change settings through. Also `.lnFont()` (text that follows your "Larger text" slider) and animation helpers. |
| `LocalStore.swift` | Reads/writes small JSON files in LifeNotch's own folder. "Wipe" only touches that folder. |
| `KeychainStore.swift` | Saves/reads secrets (API keys) in the macOS Keychain. |
| `ConsentGate.swift` | The "Allow once / Always allow / Don't allow" questions, the confirm dialogs, and the notification helper (asks macOS permission only when you switch a feature on). |
| `FileDialogs.swift` | The normal macOS Save/Open windows. LifeNotch can only touch files you pick there. |
| `NotesStore.swift` | Your study notes (AI answers, web pages, quick notes). |
| `SoundPlayer.swift` | Short built-in macOS sounds with a global mute. |
| `Countdown.swift` | Turns a date into "3d 4h" or "02:05". |
| `UIComponents.swift` | Cards, buttons, the *Demo Data* and *AI-generated* badges, theme and animation pickers. |
| `DataManagement.swift` | Export-everything / restore / "Reset app data". Never includes API keys. |

## `Sources/LifeNotch/AI/`: AI Search (steps 2–3)

| File | What it does |
|---|---|
| `AIModels.swift` | The data shapes: attachments, sources, chat messages, errors, and shared web helpers. |
| `AIPrompts.swift` | The hidden instructions sent with every question: short answer first, Verified vs Uncertain, never invent sources, homework = teach the method. **Edit these to change the AI's behaviour.** |
| `AnthropicClient.swift` | Talks to Claude's API with your key. Handles images, PDFs, web-search citations. |
| `OpenAIClient.swift` | Same idea for OpenAI. |
| `AIViewModel.swift` | The AI tab's memory: what you typed, mode, attachments, chat; and the "send" logic (asks consent before sending files). |
| `AttachmentLoader.swift` | Turns dropped files into safe attachments (shrinks images, limits sizes) and reads text out of images/PDFs **on your Mac** with Apple's Vision/PDFKit. |

## `Sources/LifeNotch/Browser/`: step 4

| File | What it does |
|---|---|
| `URLTools.swift` | "Is this a website or a search?" and the suspicious-link checker (downloads, look-alike names, number addresses). |
| `BrowserModel.swift` | Owns the WKWebView: loading, back/forward, zoom, Focus Reader, private mode, pop-up blocking, download warnings, Ask-AI-about-page, save-to-notes. Refuses web pages' camera/mic requests. |
| `BrowsingHistory.swift` | History list. Stays empty unless you switch it on. |
| `WebViewHost.swift` | The small bridge that lets SwiftUI show a WKWebView. |

## `Sources/LifeNotch/Assignments/` and `MacFun/`: step 5 and 8

| File | What it does |
|---|---|
| `Assignment.swift` | One assignment (subject, title, due, priority, notes, link, status) and "is it urgent?". |
| `AssignmentStore.swift` | The list, saving, sorting, completing, reminders (only if enabled), JSON/CSV export, JSON import. |
| `PomodoroModel.swift` | The focus timer. Works from an end time so it stays accurate. |
| `StreakStore.swift` | Study-streak days, current/longest streak. |
| `FunContent.swift` | Built-in quotes, F1/football facts, quiz questions, coding challenges (not live data). |
| `AmbientPlayer.swift` | Makes rain / café / white noise / racing sounds with maths (no files, no microphone). |
| `ClipboardMonitor.swift` | Optional clipboard history. Off by default; skips password-manager items. |
| `SystemStats.swift` | Battery, Wi-Fi status, storage, CPU, memory via public Apple APIs. |
| `CleanDeskModel.swift` | Read-only scan of Desktop/Downloads after you say yes. Never deletes or moves anything. |

## `Sources/LifeNotch/Sports/`: step 6

| File | What it does |
|---|---|
| `SportsModels.swift` | The shapes of sports data. Everything (demo or live) must produce these. |
| `SportsProviders.swift` | **Where data comes from.** Demo provider (labelled), live F1 (Jolpica), live football (football-data.org). Replace/add providers here. |
| `SportsModel.swift` | Fetches, keeps latest results, picks your favourites' fixtures, compact countdown, optional reminders (never for demo data). |

## `Sources/LifeNotch/Games/`: step 7

| File | What it does |
|---|---|
| `GameLogic.swift` | The rules (maths questions, word checking, penalty outcome), kept separate so they can be tested. |
| `GameScores.swift` | Saves best scores locally; formats the text for the compact bar. |
| `WordList.swift` | The school-friendly word list and the six-letter seeds. Add words here. |
| `GameKit.swift` | Shared helpers: keyboard catcher, big colour panel, "New best!" banner. |
| `ReactionGame.swift`, `F1LightsGame.swift`, `MemoryGame.swift`, `MathsGame.swift`, `PenaltyGame.swift`, `WordRushGame.swift` | The six games. |

## `Sources/LifeNotch/Messages/`: step 9

| File | What it does |
|---|---|
| `MessageHub.swift` | The notice list, favourites, Do Not Disturb/preview rules, opening the real Messages app, and the private link token. Does **not** read Messages. |
| `URLCommands.swift` | Checks and handles `lifenotch://` links (`notice` needs your token; `ask` needs the Safari option on and only pre-fills; `open` opens a tab). |
| `AppIntents.swift` | Shortcuts actions (open a tab, start focus, add assignment, add message notice). |

## `Sources/LifeNotch/Tabs/`: one file per screen

`AISearchView`, `BrowserView`, `MessagesView`, `AssignmentsView`, `SportsView`, `GamesView`,
`MacFunView` (+ `PomodoroView`) and `SettingsView` are the eight tabs. The `*SettingsCard.swift`
files are the groups inside Settings: AI key, Browser, Sports, Notifications, Backup, Privacy.

## `Tests/LifeNotchTests/`

Checks for the logic that doesn't need a screen: URL handling, link safety, assignment urgency, CSV
escaping, countdown text, streaks, team matching, maths questions, word rules, penalty outcomes.
Run with `swift test` on a Mac.

## `SafariExtension/`

An optional web extension: its button passes the page title, address and your selected text to
LifeNotch's AI question box (it never sends anything itself). See its own README.
