(() => {
  const publish = () => {
    let metadata = null;
    try {
      const player = document.querySelector("#movie_player");
      const video = player?.querySelector("video");
      const data = player?.getVideoData?.();
      if (video && video.readyState > 0 && /^[A-Za-z0-9_-]{11}$/.test(data?.video_id || "")) {
        metadata = {
          videoId: data.video_id,
          title: typeof data.title === "string" ? data.title.slice(0, 500) : "",
          artist: typeof data.author === "string" ? data.author.slice(0, 500) : ""
        };
      }
    } catch {}
    window.postMessage({ type: "notchbox-player-metadata-v1", metadata }, location.origin);
  };
  window.addEventListener("message", event => {
    if (event.source === window && event.origin === location.origin && event.data?.type === "notchbox-request-metadata-v1") publish();
  });
  for (const event of ["loadedmetadata", "playing", "durationchange", "emptied", "yt-navigate-finish", "ytmusic-navigate-finish", "yt-player-updated"]) {
    document.addEventListener(event, publish, true);
  }
  setInterval(publish, 1000);
  publish();
})();
