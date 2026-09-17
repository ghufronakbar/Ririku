const statusLabel = document.getElementById("status");
const sourceLabel = document.getElementById("sources");
let language = notchboxLanguage(null);

function applyLanguage(next) {
  language = notchboxLanguage(next);
  document.documentElement.lang = language;
  for (const element of document.querySelectorAll("[data-i18n]")) {
    element.textContent = notchboxText(language, element.dataset.i18n);
  }
}

async function refresh() {
  try {
    const status = await chrome.runtime.sendMessage({ kind: "status" });
    if (status?.language && status.language !== language) applyLanguage(status.language);
    statusLabel.textContent = status?.connected ? notchboxText(language, "connected") : status?.error || notchboxText(language, "connecting");
    sourceLabel.textContent = status?.sources ? notchboxText(language, "sources", { count: status.sources }) : notchboxText(language, "noSources");
  } catch { statusLabel.textContent = notchboxText(language, "extensionChanged"); }
}

for (const kind of ["openSetup", "reconnect"]) {
  document.getElementById(kind === "openSetup" ? "setup" : "reconnect").addEventListener("click", async () => {
    try {
      await chrome.runtime.sendMessage({ kind });
      statusLabel.textContent = notchboxText(language, kind === "openSetup" ? "openingSetup" : "tryingConnect");
    } catch { statusLabel.textContent = notchboxText(language, "sendFailed"); }
  });
}
applyLanguage(null);
refresh();
setInterval(refresh, 1000);
