# LifeNotch plugins and scripting

## Plugins (the "SDK")

A plugin is **one JSON file** in `~/Library/Application Support/LifeNotch/Plugins/`
(Plugins tab > "Open plugins folder" creates the folder with an example).
Plugins contain **data only**: they cannot contain or run code, so a plugin can't harm your Mac.

```json
{
  "name": "Study toolkit",
  "icon": "graduationcap.fill",
  "description": "Links, snippets and AI prompts.",
  "author": "You",
  "links":    [ { "title": "Khan Academy", "url": "https://www.khanacademy.org" } ],
  "snippets": [ { "title": "Email sign-off", "text": "Kind regards," } ],
  "prompts":  [ { "title": "Quiz me", "prompt": "Quiz me with 5 questions on this topic:" } ]
}
```

- `links`: only `http` / `https` addresses; they open in your default browser.
- `snippets`: a button copies the text to the clipboard.
- `prompts`: a button puts the text in the AI tab. **Nothing is sent** until you press Send.
- Only `name` is required. `icon` is an SF Symbol name.

## Scripting

LifeNotch can be driven from Terminal, AppleScript, Shortcuts or any script with links:

```bash
open "lifenotch://open?tab=todo"
open "lifenotch://activity?id=build&title=Build&progress=0.4&symbol=hammer.fill&detail=Compiling"
open "lifenotch://activity?id=build&action=end"
open "lifenotch://timer?minutes=10"
open "lifenotch://todo?title=Buy%20milk"
```

In AppleScript: `open location "lifenotch://timer?minutes=10"`.
Shortcuts actions: *Open a LifeNotch Tab, Start Focus Timer, Add an Assignment, Add a Message Notice,
Start / End a LifeNotch Live Activity* (these appear when built with Xcode).

The `activity`, `timer` and `todo` links only show or add harmless local items. Turn them off in
Live Activities > "Allow links and Shortcuts to start activities".
