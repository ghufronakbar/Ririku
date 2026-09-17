(() => {
  const music = location.hostname === "music.youtube.com";
  const identifier = value => typeof value === "string" && /^[A-Za-z0-9_-]{11}$/.test(value) ? value : "";
  const text = (root, selector) => (root?.querySelector(selector)?.textContent || "").trim().slice(0, 500);
  const finite = value => typeof value === "number" && Number.isFinite(value) && value >= 0;
  let settledIdentity = "";
  let pendingIdentity = "";
  let pendingSince = 0;
  let settleTimer;

  const seconds = value => {
    const parts = value.trim().split(":");
    if (parts.length < 2 || parts.length > 3 || parts.some(part => !/^\d+$/.test(part))) return null;
    if (parts.slice(1).some(part => Number(part) >= 60)) return null;
    return parts.reduce((total, part) => total * 60 + Number(part), 0);
  };

  const read = () => {
    const player = document.querySelector("#movie_player");
    const video = player?.querySelector("video");
    if (!video || video.readyState === 0) return null;
    const api = music ? document.querySelector("ytmusic-player")?.playerApi || player : player;
    const data = api.getVideoData?.() || {};
    const details = api.getPlayerResponse?.()?.videoDetails || {};
    const bar = document.querySelector("ytmusic-player-bar");
    const selected = document.querySelector("ytmusic-player-queue-item[selected]");
    const selectedData = selected?.data?.playlistPanelVideoRenderer || selected?.data;
    const barDetails = bar?.data?.videoDetails || bar?.data;
    let linkedId = "";
    try {
      const link = bar?.querySelector(".title a[href*='watch'], a.title[href*='watch']");
      linkedId = identifier(new URL(link?.href).searchParams.get("v"));
    } catch {}
    const videoId = (music && (identifier(barDetails?.videoId) || identifier(selectedData?.videoId) || linkedId))
      || identifier(details.videoId) || identifier(data.video_id);
    if (!videoId) return null;
    const title = (music ? text(bar, ".title") : text(document, "ytd-watch-metadata h1"))
      || (typeof details.title === "string" ? details.title : typeof data.title === "string" ? data.title : "").slice(0, 500);
    const artist = (music ? text(bar, ".byline a") : text(document, "ytd-watch-metadata #channel-name a"))
      || (typeof details.author === "string" ? details.author : typeof data.author === "string" ? data.author : "").slice(0, 500);
    const apiPosition = api.getCurrentTime?.();
    const apiDuration = api.getDuration?.();
    let position = null;
    let duration = null;
    if (music) {
      const clocks = text(bar, ".time-info").split("/");
      if (clocks.length === 2) {
        position = seconds(clocks[0]);
        duration = seconds(clocks[1]);
      }
      if (!finite(position) || !finite(duration) || duration <= 0 || position > duration + 1) return null;
      const slider = bar?.querySelector("#progress-bar");
      const sliderPosition = Number(slider?.value ?? slider?.getAttribute("aria-valuenow"));
      const sliderDuration = Number(slider?.max ?? slider?.getAttribute("aria-valuemax"));
      if (finite(sliderPosition) && finite(sliderDuration) && Math.abs(sliderDuration - duration) <= 1
        && sliderPosition <= sliderDuration && Math.abs(sliderPosition - position) <= 1) {
        position = sliderPosition;
        duration = sliderDuration;
      } else if (finite(apiPosition) && finite(apiDuration) && Math.abs(apiDuration - duration) <= 1
        && apiPosition <= apiDuration && Math.abs(apiPosition - position) <= 1) {
        position = apiPosition;
        duration = apiDuration;
      }
    } else {
      position = finite(apiPosition) ? apiPosition : video.currentTime;
      duration = finite(apiDuration) && apiDuration > 0 ? apiDuration : video.duration;
    }
    if (!finite(position)) return null;
    if (!finite(duration) || duration <= 0) duration = null;
    return {
      api, apiPosition, apiDuration,
      metadata: { videoId, title, artist, position: Math.min(duration ?? position, position), duration,
        seekable: duration !== null && finite(apiPosition) && typeof api.seekTo === "function" }
    };
  };

  const identity = metadata => JSON.stringify([metadata.videoId, metadata.title, metadata.artist, Math.round(metadata.duration || 0)]);
  const publish = () => {
    let metadata = null;
    try {
      const result = read();
      if (result) {
        const key = identity(result.metadata);
        if (key !== settledIdentity) {
          if (key !== pendingIdentity) {
            pendingIdentity = key;
            pendingSince = performance.now();
            clearTimeout(settleTimer);
            settleTimer = setTimeout(publish, 160);
          }
          if (performance.now() - pendingSince >= 150) settledIdentity = key;
        }
        if (key === settledIdentity) metadata = result.metadata;
      } else {
        settledIdentity = "";
        pendingIdentity = "";
      }
    } catch {}
    window.postMessage({ type: "ririku-player-metadata-v1", metadata }, location.origin);
  };
  window.addEventListener("message", event => {
    if (event.source !== window || event.origin !== location.origin) return;
    if (event.data?.type === "ririku-request-metadata-v1") { publish(); return; }
    const request = event.data;
    if (request?.type !== "ririku-seek-request-v1" || typeof request.requestId !== "string" || request.requestId.length > 100) return;
    let ok = false;
    try {
      const current = read();
      const metadata = current?.metadata;
      if (metadata && identity(metadata) === settledIdentity && request.videoId === metadata.videoId
        && request.title === metadata.title && request.artist === metadata.artist
        && finite(request.position) && metadata.seekable && request.position <= metadata.duration) {
        const offset = current.apiPosition - metadata.position;
        const destination = offset + request.position;
        if (offset >= -1 && destination >= 0 && (!finite(current.apiDuration) || destination <= current.apiDuration)) {
          current.api.seekTo(destination, true);
          ok = true;
        }
      }
    } catch {}
    window.postMessage({ type: "ririku-seek-result-v1", requestId: request.requestId, ok }, location.origin);
    if (ok) publish();
  });
  for (const event of ["loadedmetadata", "playing", "durationchange", "emptied", "yt-navigate-finish", "ytmusic-navigate-finish", "yt-player-updated"]) {
    document.addEventListener(event, publish, true);
  }
  setInterval(publish, 500);
  publish();
})();
