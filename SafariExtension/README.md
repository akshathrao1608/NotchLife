# Optional Safari extension: "Ask AI about this page"

You do **not** need this to use LifeNotch. The built-in Browser tab already has an
"Ask AI about this page" button. This extension is only for people who want the same
button inside Safari.

## What it does (and doesn't)

- When you click its toolbar button, it reads the page **title**, **address** and the text
  **you selected**, and opens a `lifenotch://ask?...` link.
- LifeNotch checks the link and **only pre-fills the AI question box**. Nothing is sent to an
  AI provider until you press Send in LifeNotch.
- It asks for the smallest permission Safari offers (`activeTab`: only the page you are on,
  only when you click the button). It has no background script and runs nothing automatically.
- LifeNotch ignores these links unless you switch on
  **Settings > Privacy > "Allow the Safari extension to pre-fill the AI tab"**.

## How to install it (you run these steps yourself)

Safari extensions must live inside a Mac app made with Xcode.

1. Install Xcode from the App Store.
2. In Terminal, from the LifeNotch project folder, run Apple's converter:

   ```bash
   xcrun safari-web-extension-converter SafariExtension/Resources \
     --app-name "LifeNotch Safari Helper" \
     --bundle-identifier com.lifenotch.safarihelper \
     --macos-only
   ```

   It creates a small Xcode project and opens it.
3. Press **Run** in Xcode. A tiny helper app appears.
4. Open **Safari > Settings > Extensions**, tick **LifeNotch: Ask AI about this page**, and
   allow it for the sites you want.
5. In LifeNotch, switch on the Safari extension option in Settings > Privacy.

> Honest note: this extension was written without being able to run Safari here, so it is
> untested. Safari may ask "Open in LifeNotch?" the first time you click the button; that is
> normal for `lifenotch://` links.
