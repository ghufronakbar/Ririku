const statusLabel = document.getElementById("status");
const sourceLabel = document.getElementById("sources");
let language = ririkuLanguage(null);

function applyLanguage(next) {
  language = ririkuLanguage(next);
  document.documentElement.lang = language;
  for (const element of document.querySelectorAll("[data-i18n]")) {
    element.textContent = ririkuText(language, element.dataset.i18n);
  }
}

async function refresh() {
  try {
    const status = await chrome.runtime.sendMessage({ kind: "status" });
    if (status?.language && status.language !== language) applyLanguage(status.language);
    statusLabel.textContent = status?.connected ? ririkuText(language, "connected") : status?.error || ririkuText(language, "connecting");
    sourceLabel.textContent = status?.sources ? ririkuText(language, "sources", { count: status.sources }) : ririkuText(language, "noSources");
  } catch { statusLabel.textContent = ririkuText(language, "extensionChanged"); }
}

for (const kind of ["openSetup", "reconnect"]) {
  document.getElementById(kind === "openSetup" ? "setup" : "reconnect").addEventListener("click", async () => {
    try {
      await chrome.runtime.sendMessage({ kind });
      statusLabel.textContent = ririkuText(language, kind === "openSetup" ? "openingSetup" : "tryingConnect");
    } catch { statusLabel.textContent = ririkuText(language, "sendFailed"); }
  });
}
applyLanguage(null);
refresh();
setInterval(refresh, 1000);
