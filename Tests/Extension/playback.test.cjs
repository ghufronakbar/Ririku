const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');

function fixture(music = true, relativeAPI = false) {
  const current = { id: 'aaaaaaaaaaa', title: 'First', artist: 'Artist', position: 37, duration: 224, ready: true };
  const packets = [], messages = [], listeners = [], intervals = [], timers = new Map(), events = {}, seeks = [];
  let now = 1000, serial = 0, commandListener;
  const video = { readyState: 4, duration: 556, playbackRate: 1, paused: false, seeking: false, seekable: { length: 1 },
    get currentTime() { return (current.mediaOffset ?? 447) + current.position; },
    set currentTime(value) { throw new Error('Must not seek the raw media element'); }
  };
  const player = {
    querySelector: selector => selector === 'video' ? video : null,
    querySelectorAll: () => [],
    getVideoData: () => ({ video_id: 'aaaaaaaaaaa', title: 'Stale API title', author: 'Stale artist' }),
    getCurrentTime: () => relativeAPI ? current.position : video.currentTime,
    getDuration: () => relativeAPI ? current.duration : video.duration,
    seekTo: value => seeks.push(value)
  };
  const clock = seconds => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
  const bar = {
    get data() { return { videoId: current.id }; },
    querySelector: selector => {
      if (selector === '.title') return { textContent: current.title };
      if (selector === '.byline a') return { textContent: current.artist };
      if (selector === '.time-info') return { textContent: current.ready ? `${clock(current.position)} / ${clock(current.duration)}` : '' };
      if (selector === '#progress-bar') return { value: current.position, max: current.duration };
      return null;
    }
  };
  const win = { addEventListener: (_, listener) => listeners.push(listener), postMessage: data => messages.push(data) };
  const context = {
    window: win, location: { hostname: music ? 'music.youtube.com' : 'www.youtube.com', origin: music ? 'https://music.youtube.com' : 'https://www.youtube.com', href: 'https://music.youtube.com/watch?v=aaaaaaaaaaa' },
    crypto: { randomUUID: () => `fixture-${++serial}` }, URL, performance: { now: () => now },
    setTimeout: (callback, delay) => { const id = ++serial; timers.set(id, { callback, due: now + delay }); return id; },
    clearTimeout: id => timers.delete(id), setInterval: callback => { intervals.push(callback); return intervals.length; }, clearInterval() {},
    MutationObserver: class { observe() {} disconnect() {} },
    getComputedStyle: () => ({ visibility: 'visible' }),
    chrome: { runtime: { id: 'extension', sendMessage: async packet => packets.push(packet), onMessage: { addListener: listener => commandListener = listener } } },
    document: { title: 'Old title', addEventListener: (event, listener) => (events[event] ??= []).push(listener), querySelector: selector => {
      if (selector === '#movie_player') return player;
      if (selector === 'ytmusic-player') return { playerApi: player };
      if (selector === 'ytmusic-player-bar') return bar;
      if (selector === 'ytmusic-player-bar img') return { currentSrc: 'https://lh3.googleusercontent.com/previous-album', src: 'https://lh3.googleusercontent.com/previous-album' };
      if (selector === '#movie_player video' || selector === 'video') return video;
      if (selector === 'ytd-watch-metadata h1') return { textContent: current.title };
      if (selector === 'ytd-watch-metadata #channel-name a') return { textContent: current.artist };
      return null;
    } }
  };
  function flush() {
    let count = 0;
    while (messages.length) {
      assert.ok(++count < 1000);
      const data = messages.shift();
      for (const listener of listeners) listener({ source: win, origin: context.location.origin, data });
    }
  }
  function tick(amount = 200) {
    now += amount;
    intervals.forEach(callback => callback());
    flush();
    for (const [id, timer] of [...timers]) if (timer.due <= now && timers.delete(id)) { timer.callback(); flush(); }
  }
  vm.createContext(context);
  for (const file of ['player-state.js', 'content.js']) vm.runInContext(fs.readFileSync(`extension/${file}`, 'utf8'), context);
  flush(); tick();
  const latest = () => packets.filter(packet => packet.kind === 'snapshot').at(-1);
  async function seek(position, trackId = current.id) {
    let response;
    commandListener({ protocolVersion: 1, kind: 'command', action: 'seek', sessionId: latest().sessionId, trackId, position },
      { id: 'extension' }, result => response = result);
    flush();
    await Promise.resolve(); await Promise.resolve();
    return response;
  }
  return { current, packets, seeks, latest, tick, seek, context, video, listeners, win };
}

test('Music uses the song clock, not the growing media buffer', () => {
  const page = fixture();
  assert.equal(page.latest().position, 37);
  assert.equal(page.latest().duration, 224);
  page.video.duration = 670;
  page.current.position = 196;
  page.tick(500);
  assert.equal(page.latest().position, 196);
  assert.equal(page.latest().duration, 224);
});

test('New song updates identity, title and clock even with stale player data and URL', () => {
  const page = fixture();
  Object.assign(page.current, { id: 'bbbbbbbbbbb', title: 'Second', artist: 'New artist', duration: 186, position: 0 });
  page.context.location.href = 'https://music.youtube.com/search?q=next';
  page.tick();
  assert.equal(page.packets.at(-1).kind, 'remove');
  page.tick();
  assert.equal(page.latest().trackId, 'bbbbbbbbbbb');
  assert.equal(page.latest().title, 'Second');
  assert.equal(page.latest().artist, 'New artist');
  assert.equal(page.latest().duration, 186);
  assert.equal(page.latest().position, 0);
});

test('Missing Music UI clock fails closed rather than publishing accumulated duration', () => {
  const page = fixture();
  page.current.ready = false;
  page.tick();
  assert.equal(page.packets.at(-1).kind, 'remove');
});

test('Artwork follows the playing video even when the player bar retains the previous album', () => {
  const page = fixture();
  assert.equal(page.latest().artworkURL, 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg');
  Object.assign(page.current, { id: 'bbbbbbbbbbb', title: 'Sparkle', artist: 'RADWIMPS', position: 0, duration: 538 });
  page.tick();
  page.tick();
  assert.equal(page.latest().trackId, 'bbbbbbbbbbb');
  assert.equal(page.latest().artworkURL, 'https://i.ytimg.com/vi/bbbbbbbbbbb/hqdefault.jpg');
  page.tick(500);
  assert.equal(page.latest().artworkURL, 'https://i.ytimg.com/vi/bbbbbbbbbbb/hqdefault.jpg');
});

test('Autoplay screenshot regression: color stays at 0:23 / 3:13 and 0:56 / 3:13', () => {
  const page = fixture();
  Object.assign(page.current, { id: 'bbbbbbbbbbb', title: '色彩 - color', artist: 'yama',
    position: 23, duration: 193, mediaOffset: 213 });
  page.video.duration = 293;
  page.tick();
  assert.equal(page.packets.at(-1).kind, 'remove');
  page.tick();
  assert.equal(page.video.currentTime, 236);
  assert.equal(page.latest().trackId, 'bbbbbbbbbbb');
  assert.equal(page.latest().position, 23);
  assert.equal(page.latest().duration, 193);
  page.current.position = 56;
  page.video.duration = 352;
  page.tick(500);
  assert.equal(page.video.currentTime, 269);
  assert.equal(page.latest().position, 56);
  assert.equal(page.latest().duration, 193);
});

test('Seek is translated to the current song segment, never assigned to video.currentTime', async () => {
  const page = fixture();
  assert.equal((await page.seek(10)).ok, true);
  assert.deepEqual(page.seeks, [457]);
  assert.equal((await page.seek(300)).ok, false);
  assert.equal((await page.seek(10, 'oldoldold01')).ok, false);
  assert.deepEqual(page.seeks, [457]);
});

test('Relative player API seek does not add an accumulated offset', async () => {
  const page = fixture(true, true);
  assert.equal((await page.seek(10)).ok, true);
  assert.deepEqual(page.seeks, [10]);
});

test('Regular YouTube uses its player API clock and seek', async () => {
  const page = fixture(false, true);
  assert.equal(page.latest().position, 37);
  assert.equal(page.latest().duration, 224);
  assert.equal((await page.seek(15)).ok, true);
  assert.deepEqual(page.seeks, [15]);
});

test('Untrusted origins and malformed clock messages cannot update snapshots', () => {
  const page = fixture();
  const count = page.packets.length;
  for (const listener of page.listeners) listener({ source: {}, origin: 'https://other.example', data: { type: 'ririku-player-metadata-v1', metadata: null } });
  for (const listener of page.listeners) listener({ source: page.win, origin: page.context.location.origin,
    data: { type: 'ririku-player-metadata-v1', metadata: { videoId: 'aaaaaaaaaaa', title: 'Bad', artist: '', position: -1, duration: 224, seekable: true } } });
  assert.equal(page.packets.length, count);
});
