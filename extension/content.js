(() => {
  const music = location.hostname === "music.youtube.com";
  const sessionId = crypto.randomUUID();
  let sequence = 0;
  let hadMedia = false;
  let lastSent = 0;
  let stopped = false;
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
  const trackId = () => new URL(location.href).searchParams.get("v") || "";
  const advertisement = () => Boolean(document.querySelector("#movie_player.ad-showing, #movie_player.ad-interrupting"));
  const artwork = identifier => {
    if (music) {
      const image = document.querySelector("ytmusic-player-bar img");
      const candidate = image?.currentSrc || image?.src;
      try {
        const url = new URL(candidate);
        if (url.protocol === "https:" && ["lh3.googleusercontent.com", "lh4.googleusercontent.com", "lh3.ggpht.com", "i.ytimg.com"].includes(url.hostname)) return url.href;
      } catch {}
    }
    return "https://i.ytimg.com/vi/" + encodeURIComponent(identifier) + "/hqdefault.jpg";
  };
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
    const video = media();
    const identifier = trackId();
    let packet;
    if (!video || !identifier || video.readyState === 0) {
      if (!hadMedia) return;
      hadMedia = false;
      packet = { protocolVersion: 1, kind: "remove", sessionId };
    } else {
      hadMedia = true;
      const duration = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : null;
      const isAdvertisement = advertisement();
      packet = {
        protocolVersion: 1, kind: "snapshot", sessionId, sequence: ++sequence,
        sourceLabel: music ? "YouTube Music · Chrome" : "YouTube · Chrome",
        trackId: identifier,
        title: (music ? text("ytmusic-player-bar .title") : text("ytd-watch-metadata h1")) || document.title.replace(/ - YouTube(?: Music)?$/, "").slice(0, 500),
        artist: music ? text("ytmusic-player-bar .byline a") : text("ytd-watch-metadata #channel-name a"),
        artworkURL: artwork(identifier),
        ...captions(video),
        position: Math.max(0, Number.isFinite(video.currentTime) ? video.currentTime : 0),
        duration, playbackRate: video.playbackRate,
        state: video.ended ? "ended" : video.paused ? "paused" : video.seeking || video.readyState < 3 ? "buffering" : "playing",
        isAdvertisement,
        capabilities: {
          playPause: !isAdvertisement,
          previous: !isAdvertisement && Boolean(button("previous")),
          next: !isAdvertisement && Boolean(button("next")),
          seek: !isAdvertisement && duration !== null && video.seekable.length > 0
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
          if (!Number.isFinite(command.position) || !Number.isFinite(video.duration) || !video.seekable.length) throw new Error("Unseekable");
          video.currentTime = Math.min(video.duration, Math.max(0, command.position));
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

  for (const event of ["play", "pause", "playing", "waiting", "seeking", "seeked", "ratechange", "ended", "loadedmetadata"]) {
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
  sendSnapshot(true);
})();
