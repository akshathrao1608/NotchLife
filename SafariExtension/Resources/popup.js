// popup.js: runs when you click the extension's toolbar button.
// It reads three things from the page you are on: title, address and your selected text,
// then opens a lifenotch:// link. The LifeNotch app checks the link and only pre-fills its
// AI question box. It never sends anything by itself.

const MAX_SELECTION = 6000;
let info = null;

async function readPage() {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  const results = await browser.tabs.executeScript(tab.id, {
    code: "JSON.stringify({ title: document.title, url: location.href, selection: String(window.getSelection()) })"
  });
  return JSON.parse(results[0]);
}

function buildLink(page) {
  return "lifenotch://ask" +
    "?title=" + encodeURIComponent(page.title.slice(0, 200)) +
    "&url=" + encodeURIComponent(page.url.slice(0, 500)) +
    "&text=" + encodeURIComponent(page.selection.slice(0, MAX_SELECTION));
}

(async function () {
  const preview = document.getElementById("preview");
  try {
    info = await readPage();
    preview.textContent = info.title + "\n" + info.url + "\n\n" +
      (info.selection ? info.selection.slice(0, 400) : "(no text selected: LifeNotch will just get the title and address)");
  } catch (error) {
    preview.textContent = "Couldn't read this page. Try a normal web page.";
  }
})();

document.getElementById("ask").addEventListener("click", function () {
  if (!info) { return; }
  const link = document.createElement("a");
  link.href = buildLink(info);
  document.body.appendChild(link);
  link.click();
  window.close();
});
