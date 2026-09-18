(() => {
  const music = location.hostname === "music.youtube.com";
  const sessionId = crypto.randomUUID();
  let sequence = 0;
  let hadMedia = false;
  let lastSent = 0;
  let stopped = false;
  let playerMetadata = null;
  let metadataReceivedAt = 0;
  let metadataSupported = false;
  const pendingSeeks = new Map();
  let lastIdentifier = "";
  let metadataBar = null;
  let metadataUpdate = null;
  const metadataObserver = new MutationObserver(() => {
    if (metadataUpdate !== null) return;
    metadataUpdate = setTimeout(() => {
      metadataUpdate = null;
      window.postMessage({ type: "ririku-request-metadata-v1" }, location.origin);
      sendSnapshot(true);
    }, 80);
  });
  window.addEventListener("message", event => {
    if (event.source === window && event.origin === location.origin && event.data?.type === "ririku-seek-result-v1") {
      const pending = pendingSeeks.get(event.data.requestId);
      if (pending) { pendingSeeks.delete(event.data.requestId); pending(event.data.ok === true); }
      return;
    }
    if (event.source !== window || event.origin !== location.origin || event.data?.type !== "ririku-player-metadata-v1") return;
    const value = event.data.metadata;
    if (value !== null && (!value || typeof value.videoId !== "string" || !/^[A-Za-z0-9_-]{11}$/.test(value.videoId)
      || typeof value.title !== "string" || value.title.length > 500 || typeof value.artist !== "string" || value.artist.length > 500
      || !Number.isFinite(value.position) || value.position < 0
      || (value.duration !== null && (!Number.isFinite(value.duration) || value.duration <= 0 || value.position > value.duration))
      || typeof value.seekable !== "boolean")) return;
    metadataSupported = true;
    const changed = JSON.stringify(playerMetadata) !== JSON.stringify(value);
    playerMetadata = value;
    metadataReceivedAt = performance.now();
    if (changed) sendSnapshot(true);
  });
  let captionPlayer = null;
  let captionUpdate = null;
  let captionSuppressed = false;
  const captionObserver = new MutationObserver(records => {
    if (!records.some(record => {
      const element = record.target.nodeType === 1 ? record.target : record.target.parentElement;
      return element?.closest?.(".ytp-caption-window-container, .ytp-subtitles-button") ||
        [...record.addedNodes, ...record.removedNodes].some(node => node.nodeType === 1 &&
          (node.matches?.(".ytp-caption-window-container") || node.querySelector?.(".ytp-caption-segment")));
    })) return;
    captionSuppressed = false;
    if (captionUpdate !== null) return;
    captionUpdate = setTimeout(() => { captionUpdate = null; sendSnapshot(true); }, 40);
  });
  const captions = video => {
    const player = document.querySelector("#movie_player");
    if (player !== captionPlayer) {
      captionObserver.disconnect();
      captionPlayer = player;
      if (player) captionObserver.observe(player, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["aria-pressed", "style", "class"] });
    }
    const control = music
      ? document.querySelector("ytmusic-player-bar .subtitle-button, ytmusic-player-bar .subtitles-button, ytmusic-player-bar [aria-label*='caption' i], ytmusic-player-bar [aria-label*='subtitle' i]") || player?.querySelector(".ytp-subtitles-button")
      : player?.querySelector(".ytp-subtitles-button");
    const segments = [...(player?.querySelectorAll(".ytp-caption-segment") || [])].filter(element =>
      element.getClientRects().length && getComputedStyle(element).visibility !== "hidden");
    const pressed = control?.getAttribute("aria-pressed");
    const enabled = pressed === "true" || (pressed !== "false" && segments.length > 0);
    if (!enabled || video.seeking || captionSuppressed || advertisement()) return { captionEnabled: enabled, captionText: "" };
    return { captionEnabled: true, captionText: segments.map(element => element.textContent.trim()).filter(Boolean).join("\n").slice(0, 1000) };
  };

  const media = () => document.querySelector("#movie_player video") || document.querySelector("video");
  const text = selector => (document.querySelector(selector)?.textContent || "").trim().slice(0, 500);
  const freshMetadata = () => performance.now() - metadataReceivedAt < 2500 ? playerMetadata : null;
  const trackId = () => {
    if (freshMetadata()) return freshMetadata().videoId;
    if (music) {
      const titleLink = document.querySelector("ytmusic-player-bar .title a[href*='watch'], ytmusic-player-bar a.title[href*='watch']");
      try {
        const identifier = new URL(titleLink?.href).searchParams.get("v");
        if (/^[A-Za-z0-9_-]{11}$/.test(identifier || "")) return identifier;
      } catch {}
    }
    return new URL(location.href).searchParams.get("v") || "";
  };
  const advertisement = () => Boolean(document.querySelector("#movie_player.ad-showing, #movie_player.ad-interrupting"));
  const artwork = identifier => "https://i.ytimg.com/vi/" + encodeURIComponent(identifier) + "/hqdefault.jpg";
  const button = action => {
    const selector = music
      ? action === "previous" ? "ytmusic-player-bar .previous-button" : "ytmusic-player-bar .next-button"
      : action === "previous" ? ".ytp-prev-button" : ".ytp-next-button";
    const element = document.querySelector(selector);
    return element && !element.disabled && element.getAttribute("aria-disabled") !== "true" && element.getClientRects().length ? element : null;
  };

  async function sendSnapshot(force = false) {
    if (stopped || (!force && performance.now() - lastSent < 100)) return;
    lastSent = performance.now();
    const bar = document.querySelector(music ? "ytmusic-player-bar" : "ytd-watch-metadata");
    if (bar !== metadataBar) {
      metadataObserver.disconnect();
      metadataBar = bar;
      if (bar) metadataObserver.observe(bar, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["href", "title", "src"] });
    }
    const video = media();
    const clock = freshMetadata();
    const identifier = trackId();
    if (identifier !== lastIdentifier) {
      if (lastIdentifier) captionSuppressed = true;
      lastIdentifier = identifier;
    }
    let packet;
    if (!video || !identifier || video.readyState === 0 || ((music || metadataSupported) && !clock)) {
      if (!hadMedia) return;
      hadMedia = false;
      packet = { protocolVersion: 1, kind: "remove", sessionId };
    } else {
      hadMedia = true;
      const duration = clock ? clock.duration : Number.isFinite(video.duration) && video.duration > 0 ? video.duration : null;
      const isAdvertisement = advertisement();
      packet = {
        protocolVersion: 1, kind: "snapshot", sessionId, sequence: ++sequence,
        sourceLabel: music ? "YouTube Music · Chrome" : "YouTube · Chrome",
        trackId: identifier,
        title: freshMetadata()?.title || (music ? text("ytmusic-player-bar .title") : text("ytd-watch-metadata h1")) || document.title.replace(/ - YouTube(?: Music)?$/, "").slice(0, 500),
        artist: freshMetadata()?.artist || (music ? text("ytmusic-player-bar .byline a") : text("ytd-watch-metadata #channel-name a")),
        artworkURL: artwork(identifier),
        ...captions(video),
        position: clock ? Math.min(duration ?? Infinity, clock.position + (video.paused || video.seeking || video.readyState < 3 ? 0 : Math.min(0.5, (performance.now() - metadataReceivedAt) / 1000) * video.playbackRate))
          : Math.max(0, Number.isFinite(video.currentTime) ? video.currentTime : 0),
        duration, playbackRate: video.playbackRate,
        state: video.ended ? "ended" : video.paused ? "paused" : video.seeking || video.readyState < 3 ? "buffering" : "playing",
        isAdvertisement,
        capabilities: {
          playPause: !isAdvertisement,
          previous: !isAdvertisement && Boolean(button("previous")),
          next: !isAdvertisement && Boolean(button("next")),
          seek: !isAdvertisement && Boolean(clock?.seekable)
        }
      };
    }
    try { await chrome.runtime.sendMessage(packet); }
    catch {
      if (!chrome.runtime.id) { stopped = true; clearInterval(heartbeat); }
    }
  }

  chrome.runtime.onMessage.addListener((command, sender, respond) => {
    if (sender.id !== chrome.runtime.id || command?.protocolVersion !== 1 || command.kind !== "command") return;
    const video = media();
    if (!video || command.sessionId !== sessionId || command.trackId !== trackId() || advertisement()) {
      respond({ ok: false });
      return;
    }
    (async () => {
      try {
        if (command.action === "toggle") {
          if (video.paused) await video.play(); else video.pause();
        } else if (command.action === "seek") {
          const clock = freshMetadata();
          if (!clock?.seekable || !Number.isFinite(command.position) || command.position < 0 || command.position > clock.duration) throw new Error("Unseekable");
          const requestId = crypto.randomUUID();
          const ok = await new Promise(resolve => {
            const timeout = setTimeout(() => { pendingSeeks.delete(requestId); resolve(false); }, 1500);
            pendingSeeks.set(requestId, success => { clearTimeout(timeout); resolve(success); });
            window.postMessage({ type: "ririku-seek-request-v1", requestId, videoId: clock.videoId,
              title: clock.title, artist: clock.artist, position: command.position }, location.origin);
          });
          if (!ok) throw new Error("Seek rejected");
        } else if (["previous", "next"].includes(command.action)) {
          const target = button(command.action);
          if (!target) throw new Error("Unavailable");
          target.click();
        } else { throw new Error("Unsupported"); }
        respond({ ok: true });
        await sendSnapshot(true);
      } catch { respond({ ok: false }); }
    })();
    return true;
  });

  for (const event of ["play", "pause", "playing", "waiting", "seeking", "seeked", "ratechange", "ended", "loadedmetadata", "durationchange", "emptied"]) {
    document.addEventListener(event, () => {
      if (event === "seeking" || event === "loadedmetadata") captionSuppressed = true;
      sendSnapshot(true);
    }, true);
  }
  for (const event of ["yt-navigate-start", "ytmusic-navigate-start"]) {
    document.addEventListener(event, () => { captionSuppressed = true; sendSnapshot(true); });
  }
  document.addEventListener("yt-navigate-finish", () => sendSnapshot(true));
  document.addEventListener("ytmusic-navigate-finish", () => sendSnapshot(true));
  document.addEventListener("visibilitychange", () => sendSnapshot(true));
  const heartbeat = setInterval(() => sendSnapshot(), 1000);
  window.postMessage({ type: "ririku-request-metadata-v1" }, location.origin);
  sendSnapshot(true);
})();
