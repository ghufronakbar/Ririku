importScripts("i18n.js");

const hostName = "io.github.lanstheprodigy.ririku.bridge";
const sources = new Map();
let nativePort = null;
let retryAfter = 0;
let failures = 0;
let connected = false;
let reconnectTimer;
let pendingSetup = false;
let language = null;
let lastError = { key: "waitingNative" };

function trustedSender(sender) {
  if (!Number.isInteger(sender.tab?.id) || sender.frameId !== 0) return false;
  try {
    const url = new URL(sender.url);
    return url.protocol === "https:" && ["www.youtube.com", "music.youtube.com"].includes(url.hostname);
  } catch { return false; }
}

function updateTitle() {
  chrome.action.setTitle({ title: ririkuText(language, connected ? "titleConnected" : "titleDisconnected") });
}

function postNative(message) {
  if (!nativePort) return false;
  try { nativePort.postMessage(message); return true; }
  catch { return false; }
}

function connectHost() {
  if (nativePort || Date.now() < retryAfter) return;
  const port = chrome.runtime.connectNative(hostName);
  nativePort = port;
  connected = false;
  port.onDisconnect.addListener(() => {
    const error = chrome.runtime.lastError?.message;
    if (nativePort !== port) return;
    nativePort = null;
    connected = false;
    lastError = error ? { text: error } : { key: "disconnected" };
    failures = Math.min(failures + 1, 4);
    retryAfter = Date.now() + Math.min(15000, 1000 * 2 ** failures);
    chrome.action.setBadgeText({ text: "!" });
    updateTitle();
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connectHost, Math.max(0, retryAfter - Date.now()));
  });
  port.onMessage.addListener(async command => {
    if (command?.protocolVersion === 1 && ["hello", "preferences"].includes(command.kind) &&
        ["en", "id", "ja"].includes(command.language)) {
      language = command.language;
    }
    if (command?.protocolVersion === 1 && command.kind === "preferences") {
      updateTitle();
      return;
    }
    if (command?.protocolVersion === 1 && command.kind === "hello") {
      failures = 0;
      connected = true;
      lastError = null;
      chrome.action.setBadgeText({ text: "" });
      updateTitle();
      if (pendingSetup) {
        pendingSetup = false;
        postNative({ protocolVersion: 1, kind: "openSetup" });
      }
      return;
    }
    if (command?.protocolVersion !== 1 || command.kind !== "command" ||
        typeof command.commandId !== "string" || command.commandId.length > 100 ||
        !["toggle", "previous", "next", "seek"].includes(command.action)) return;
    const source = sources.get(command.sourceId);
    const ack = { protocolVersion: 1, kind: "ack", commandId: command.commandId, ok: false };
    if (!source || Date.now() - source.updatedAt > 5000 ||
        source.snapshot.sessionId !== command.sessionId || source.snapshot.trackId !== command.trackId) {
      postNative(ack);
      return;
    }
    try {
      const result = await chrome.tabs.sendMessage(source.tabId, command, { frameId: 0 });
      ack.ok = result?.ok === true;
    } catch { ack.ok = false; }
    postNative(ack);
  });
  if (pendingSetup) postNative({ protocolVersion: 1, kind: "openSetup" });
  postNative({ protocolVersion: 1, kind: "extension", version: chrome.runtime.getManifest().version });
  for (const source of sources.values()) {
    if (Date.now() - source.updatedAt < 5000) postNative(source.snapshot);
  }
}

chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (!sender.tab && sender.id === chrome.runtime.id && sender.url === chrome.runtime.getURL("popup.html")) {
    if (message?.kind === "status") {
      connectHost();
      const error = lastError?.text ?? (lastError ? ririkuText(language, lastError.key) : "");
      respond({ connected, error, language: ririkuLanguage(language), sources: [...sources.values()].filter(source => Date.now() - source.updatedAt < 5000).length });
    } else if (message?.kind === "reconnect" || message?.kind === "openSetup") {
      if (message.kind === "openSetup") {
        if (connected) postNative({ protocolVersion: 1, kind: "openSetup" });
        else {
          pendingSetup = true;
          if (nativePort) postNative({ protocolVersion: 1, kind: "openSetup" });
        }
      }
      retryAfter = 0;
      clearTimeout(reconnectTimer);
      connectHost();
      respond({ ok: true });
    }
    return;
  }
  if (!trustedSender(sender) || message?.protocolVersion !== 1 ||
      typeof message.sessionId !== "string" || message.sessionId.length > 100) return;
  const sourceId = "tab:" + sender.tab.id;
  if (message.kind === "remove") {
    const previous = sources.get(sourceId);
    if (previous?.snapshot.sessionId === message.sessionId) {
      sources.delete(sourceId);
      postNative({ protocolVersion: 1, kind: "remove", sourceId, sessionId: message.sessionId });
    }
    respond({ ok: true });
    return;
  }
  if (message.kind !== "snapshot" || JSON.stringify(message).length > 16000) return;
  const snapshot = { ...message, sourceId };
  const previous = sources.get(sourceId);
  if (previous && previous.snapshot.sessionId !== snapshot.sessionId) {
    postNative({ protocolVersion: 1, kind: "remove", sourceId, sessionId: previous.snapshot.sessionId });
  }
  sources.set(sourceId, { snapshot, tabId: sender.tab.id, updatedAt: Date.now() });
  connectHost();
  postNative(snapshot);
  respond({ ok: true });
});

chrome.tabs.onRemoved.addListener(tabId => {
  const sourceId = "tab:" + tabId;
  const source = sources.get(sourceId);
  if (!source) return;
  sources.delete(sourceId);
  postNative({ protocolVersion: 1, kind: "remove", sourceId, sessionId: source.snapshot.sessionId });
});
