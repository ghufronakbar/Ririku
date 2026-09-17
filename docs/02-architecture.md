# Arsitektur awal

## Identitas v0.3.0

Nama app dan identifier diganti ke Ririku sebelum rilis open source: bundle `io.github.lanstheprodigy.ririku` (juga domain UserDefaults dan folder cache `~/Library/Caches/io.github.lanstheprodigy.ririku/Lyrics-v2`), native host `io.github.lanstheprodigy.ririku.bridge`, socket `/tmp/ririku-<uid>`, target SwiftPM `Ririku`/`RirikuHost`/`RirikuCore`, User-Agent `Ririku/<versi> (https://github.com/lanstheprodigy/ririku)`, serta pesan MAIN world extension `ririku-request-metadata-v1`/`ririku-player-metadata-v1`. Tidak ada migrasi dari identifier `local.notchbox.*`; data lama tidak dibaca. Protokol bridge (`protocolVersion` 1) tidak berubah, tetapi extension v0.2.x tidak cocok dengan app v0.3.0 karena nama native host dan tipe pesan metadata berbeda.

## Pemasangan Chrome tanpa Terminal v0.3.0

Manifest extension memuat field `key` (kunci publik RSA) sehingga ID unpacked selalu `bmmbkmngcmjoihlcmehlnfpedhoefofi`. Kunci privat tidak disimpan dan tidak dibutuhkan karena extension tidak diterbitkan ke Chrome Web Store. `build-app.sh` menyalin folder `extension` ke `Contents/Resources/ChromeExtension`. `ChromeSetup` di app menulis manifest native host (izin 0600, `path` ke `RirikuHost` dalam bundle yang sedang berjalan, `allowed_origins` hanya ID tersebut) dan menyalin extension ke `~/Library/Application Support/Ririku/Chrome Extension` melalui folder staging lalu `replaceItemAt`. Kedua aksi hanya terjadi saat tombol Setup diklik. Status host dibaca dari berkas: belum terdaftar, terdaftar untuk salinan lain (path berbeda), terdaftar, tidak tersedia di luar bundle, atau diblokir saat App Translocation (`/AppTranslocation/` pada path bundle), karena path sementara akan hilang setelah app ditutup.

Setelah terhubung ke native host, extension mengirim `{"kind":"extension","version":…}` setelah `openSetup` tertunda (agar peluncuran app dari popup tetap valid). App memvalidasi format versi numerik, menyimpannya sampai disconnect, dan membandingkannya dengan versi extension bawaan untuk menandai extension usang. App lama mengabaikan pesan ini.

Batasan keamanan: kunci publik bersifat publik, sehingga extension unpacked lain dapat meniru ID yang sama bila pengguna sendiri memasangnya. Native host hanya meneruskan snapshot tidak tepercaya dan perintah pemutar terbatas; ini sama dengan risiko ID berbasis path sebelumnya dan tetap memerlukan pemasangan manual oleh pengguna.

## Lokalisasi v0.2.5

Teks sumber UI ditulis dalam English dan sekaligus menjadi key. Terjemahan berada di `Localization/{en,id,ja}.lproj/Localizable.strings` (format `.strings`, karena Command Line Tools tidak menyediakan `xcstringstool` untuk String Catalog). `build-app.sh` menyalin folder `.lproj` ke `Contents/Resources` serta menulis `CFBundleDevelopmentRegion=en` dan `CFBundleLocalizations`. Resource SwiftPM/`Bundle.module` sengaja tidak dipakai: pada spike, accessor mencari bundle di root `.app` (fatal error bila tidak ada), sedangkan bundle di root membuat `codesign --strict` gagal.

Preferensi `interfaceLanguage` (`system`, `en`, `id`, `ja`) tersimpan di UserDefaults. Mode sistem memakai `Bundle.preferredLocalizations(from:forPreferences:)` terhadap `Locale.preferredLanguages`; tanpa bahasa cocok hasilnya English. `Localizer` membaca langsung sub-bundle `<kode>.lproj`, sehingga penggantian bahasa tidak memerlukan restart; `String(localized:locale:)` tidak dipakai karena parameter locale hanya memengaruhi format, bukan pemilihan terjemahan. Key yang tidak ditemukan tampil sebagai teks English.

Status dan error yang disimpan model (`lyricMessages`, `lyricNames`, `lyricSearchStatus`, `commandError`, `bridgeError`, notifikasi lirik) berupa `UIText` (key + argumen) dan diterjemahkan saat render, agar status lama ikut berganti bahasa. `BridgeError.system` membawa key English + argumen; `errorDescription` tetap English untuk log native host. Error dari framework sistem tetap memakai teks sistem. Angka offset/selisih diformat dengan locale bahasa UI. Judul lagu, artis, label layanan dari extension, lirik, dan caption ditampilkan apa adanya.

Menu bar dan judul jendela Setup diperbarui saat bahasa berubah. Bridge menyertakan `language` (kode efektif) pada `hello` dan mengirim pesan `preferences` saat bahasa berubah. Extension v0.2.5 memakai `i18n.js` bersama untuk popup/judul action: bahasa app bila terhubung, lalu bahasa UI Chrome, lalu English. Nama dan deskripsi manifest memakai `_locales` Chrome sehingga mengikuti bahasa Chrome, bukan app. Extension lama mengabaikan field/pesan baru; app baru tetap kompatibel dengan protokol lama. `scripts/check-localization.py` memastikan setiap key di kode tersedia pada id/ja dengan jumlah placeholder sama dan dijalankan oleh `build-app.sh`.

## Pembaruan v0.2.4

Resize menggunakan satu interpolator frame native (`IslandMotion`) dengan kurva smoothstep/ease-in-out 0,32 detik. Setiap frame menghitung `origin.y = target.maxY - height`, sehingga tepi atas konstan. Timer 60 Hz hanya hidup selama resize dan dibatalkan setelah selesai/retarget; NSHostingView tidak menentukan ukuran jendela dan animasi layout implisit root SwiftUI dihapus. Reduce Motion/toggle nonaktif memakai frame akhir langsung. Auto-popup pada track change dihapus; hover/klik/menu tetap membuka panel.

`hasIslandLyrics` memisahkan konten dari status lookup. Geometri menghilangkan area lirik jika tidak ada konten/notifikasi. Status detail tetap di Setup; lookup miss memunculkan notice 3 detik maksimal sekali per identitas lagu per sesi, bukan saat jaringan gagal. Notice dibatalkan ketika lagu/sumber berubah dan tidak memicu expanded. Caption aktif tetap memiliki area cue, termasuk jeda, agar tidak resize setiap kata hilang.

Spectrum dekoratif memakai lima band sintetis dan TimelineView maksimal 24 Hz saat playing dengan animasi aktif; tidak membaca/merekam audio. Pause/ended/buffering/iklan menuju tinggi 2 pt dalam 0,28 detik, timeline periodik berhenti. Toggle animasi/Reduce Motion menghasilkan bar statis.

LRC raw tetap diparse/disimpan tanpa perubahan. Lapisan display default mengutamakan Jepang: pada track dengan kana, baris Latin-only yang waktunya persis sama dengan baris kana/kanji tidak ditampilkan. Tidak membuang baris Latin pada timestamp lain, teks campuran dalam satu baris, atau aksara lain. Ini preferensi display, bukan bukti dua baris bermakna sama. Toggle off mengembalikan semua raw cues; diperlukan bila vokal multilingual simultan harus terlihat. Hasil display dicache dalam memori dan invalidasi saat lirik/preferensi berubah.

## Pembaruan UI/identitas v0.2.3

Geometri panel dihitung terpusat oleh model: lebar ringkas/terbuka, tinggi fisik notch, jumlah baris, visibility lirik, serta pesan error. Frame target yang sama tidak memulai ulang animasi. AppKit memakai ease-in/ease-out 0,32 detik; opacity/layout SwiftUI memakai durasi sama. Toggle animasi dan Reduce Motion tetap dihormati. `showLyrics` kini berlaku pada kedua mode; jumlah baris serta lebar ringkas/terbuka tersimpan di UserDefaults.

Extension menambahkan `player-state.js` di MAIN world, hanya membaca video ID/judul/artis dari getter pemutar, tanpa capture audio/cookies/token/request jaringan. Pesan dibatasi, diperiksa origin/window serta tipe/panjang oleh isolated content script. Data halaman tetap tidak tepercaya; MAIN script tidak memiliki akses native messaging. Getter pemutar bukan kontrak publik yang dijamin stabil: bila tidak tersedia, fallback ke link judul player bar lalu URL. Data getter kedaluwarsa setelah 2,5 detik. Event media, heartbeat dan observer metadata menangani player/bar yang diganti atau URL search yang tidak mengikuti lagu. Lagu baru ketika state masih `playing` dianggap aktivitas baru untuk pemilihan sumber; heartbeat lagu sama tidak merebut sumber dan manual pin tetap dihormati.

## Pemilihan lirik v0.2.2

Preferensi `lyricSource` tersimpan lokal: `auto` mengutamakan LRC bertimestamp lalu caption, `lrclib` tidak menampilkan caption, `caption` menyembunyikan LRC/plain text dan menghentikan pencarian LRCLIB. Impor LRC merupakan override lokal pada mode non-caption. Pencarian manual memakai `/api/search?q=...` melalui klien HTTP, pembatasan ukuran, dan throttle yang sama. Hasil diurutkan menurut selisih durasi absolut; durasi tidak diketahui terakhir. Kandidat otomatis tetap harus cocok judul/artis dan selisih ≤3 detik, mengutamakan kandidat bertimestamp lalu durasi terdekat. Pencarian alternatif kini dijalankan juga setelah exact match untuk membandingkan kandidat. Cache query menggunakan `Lyrics-v2` agar hasil keputusan lama tidak tertahan.

Offset disimpan di UserDefaults menurut identitas video, dibatasi ±60 detik dan finite; nilai positif menunda. Video ID sama pada YouTube dan YouTube Music berbagi offset. Offset global lama tidak disalin ke semua lagu. Pemilihan hasil manual disimpan dalam memori hingga app ditutup, tidak tertimpa lookup otomatis; tombol kembali ke hasil otomatis menghapus override. Hasil pencarian yang selesai setelah lagu berubah diabaikan/dibatalkan. Durasi bukan faktor scaling waktu; clock playback tetap sumber waktu utama.

## Caption v0.2.1

Snapshot memiliki `captionEnabled` dan `captionText` opsional (batas 4 KB). Extension membaca caption DOM terlihat, mengirim perubahan dengan coalescing 40 ms dan heartbeat cadangan. Seek/navigation menahan teks lama sampai perubahan caption berikutnya; iklan mengosongkan teks. Native mengutamakan caption aktif, termasuk jeda jika status CC terbaca aktif. Offset LRC tidak diterapkan pada caption. Jika kontrol CC tidak mengekspos status yang dikenali, deteksi memakai segmen terlihat; jeda dapat kembali ke LRCLIB dan perlu validasi situs nyata. Tidak memakai transcript privat, cookies, OCR, atau speech-to-text.

[Kembali ke indeks](../README.md)

Dokumen ini memuat rancangan target dan status prototipe. Per 17 September 2026, shell native, adapter browser, IPC, parser/clock LRC, pemilihan sumber otomatis, artwork, serta pencarian/cache LRCLIB telah diimplementasikan. Dukungan pemutar desktop tetap belum ada; v0.2 masih perlu verifikasi end-to-end pada extension yang di-reload.

## 1. Komponen

```text
YouTube / YouTube Music
  ↕ Chrome content script
  ↕ extension service worker
  ↕ native messaging host
  ↕ Unix domain socket lokal
Native macOS application
  ├─ Browser adapter
  ├─ Apple Music adapter (perlu validasi)
  ├─ Spotify adapter (perlu validasi)
  ├─ Playback coordinator → sumber terpilih
  ├─ Lyrics resolver → provider / cache / parser
  ├─ Lyrics clock → posisi aktif / offset
  └─ SwiftUI views + AppKit panel controller
```

Panel musik dan jendela Setup memiliki lifecycle terpisah. Kebijakan sumber diatur di Setup, bukan pop-up notch. Preferences store bersama memasok pilihan sumber dan tampilan ke coordinator serta views. Membuka Setup kembali mengaktifkan jendela yang sudah ada. Popup extension hanya menampilkan status/reconnect dan membuka Setup native melalui pesan `openSetup`; tidak menjadi UI musik utama.

Native messaging host adalah executable terpisah di bundle aplikasi. Registrasi host dibuat melalui skrip dengan allowlist satu extension ID. Prototipe memakai framing panjang UInt32 little-endian dan JSON, batas 256 KiB, serta Unix domain socket di direktori `/tmp/ririku-<uid>` dengan mode 0700. Socket bermode 0600; kedua sisi memeriksa UID peer. Hanya satu host/profile Chrome aktif pada satu waktu. Lock file mencegah instance server kedua mengambil socket aktif.

Implementasi awal mencakup handshake, pembatasan framing, sumber per tab/sesi, acknowledgement perintah, pemulihan koneksi lewat heartbeat, dan penolakan snapshot dengan urutan lama. Ini bukan audit keamanan penuh.

## 2. Adapter pemutar

Setiap adapter menyediakan snapshot playback, status koneksi, daftar kemampuan, serta pengiriman perintah. UI tidak memanggil browser atau automation langsung.

- Browser: observasi elemen media dan metadata halaman; navigasi halaman, buffering, playback rate, iklan, dan perubahan DOM perlu diuji.
- Apple Music/Spotify: evaluasi scripting dictionary aplikasi terpasang dan izin Automation sebelum memilih integrasi lokal. Jangan menjanjikan event real-time, artwork, atau seek sebelum diuji.
- Tidak mengandalkan private API sebagai fondasi awal. Jangan menganggap metadata Now Playing publik merupakan pembaca universal semua pemutar.

## 3. Kontrak data konseptual

| Field | Makna |
| --- | --- |
| protocolVersion, sequence | Versi protokol dan urutan pesan untuk menolak data lama |
| sourceId, sessionId | Aplikasi/tab serta sesi koneksi; bukan hanya nama layanan |
| trackId, revision | Identitas konten dan revisi metadata |
| title, artist, album | Metadata opsional; unknown bukan string kosong yang dianggap valid |
| duration, position | Detik; duration dapat unknown untuk live stream |
| playbackState | playing, paused, buffering, ended, unknown |
| playbackRate | Kecepatan aktual |
| observedAt, receivedAt | Waktu observasi dan penerimaan; basis clock harus didefinisikan |
| isAdvertisement | true, false, atau unknown; jangan menganggap deteksi selalu andal |
| capabilities | canPlayPause, canPrevious, canNext, canSeek |
| artworkURL | URL HTTPS thumbnail opsional; host native membatasi tujuan unduhan |
| connectionState | connected, stale, disconnected, permissionRequired |

Perintah membawa commandId, sourceId, sessionId, trackId/revision bila relevan, aksi, dan argumen. Respons mengembalikan acknowledgement/error. Jangan memperbarui playback permanen hanya berdasarkan klik; rekonsiliasi dengan snapshot aktual. Perintah seek wajib divalidasi terhadap durasi dan kemampuan sumber.

## 4. Pemilihan sumber

Default v0.2 mengikuti sumber yang baru mulai memutar. Heartbeat pemutar yang terus berjalan tidak merebut pilihan. Jika sumber hilang, pilih sumber segar lain dengan prioritas playing. Dalam mode manual, pilihan dikunci; sesi baru pada tab yang sama dipulihkan otomatis, tetapi tidak diganti ke tab lain tanpa izin. Pergantian sumber membatalkan command pending; command tetap membawa identitas sesi/track. Kebijakan otomatis tersimpan, ID tab/sesi tidak disimpan lintas restart.

## 5. Sinkronisasi

1. Snapshot pemutar menjadi otoritas posisi, bukan timer UI.
2. Saat playing, interpolasikan posisi dari anchor dan waktu monotonic lokal dengan playbackRate.
3. Jangan mengurangkan timestamp dari proses berbeda tanpa mendefinisikan basis clock. Awali dengan anchor waktu penerimaan lokal, ukur latensi transport, lalu evaluasi kebutuhan kompensasi.
4. Saat paused/buffering/disconnected, hentikan prediksi maju.
5. Seek, pergantian sumber, atau perubahan track membatalkan anchor lama dan langsung memilih baris baru.
6. Pilih timestamp terakhir yang tidak melebihi posisi efektif. Sebelum baris pertama, tampilkan jeda instrumental atau tanpa lirik.
7. Terapkan offset dengan konvensi eksplisit: posisi efektif = posisi playback − offset. Offset positif menunda pergantian lirik.
8. Koreksi drift menggunakan snapshot baru; frekuensi sampling dan batas stale ditentukan melalui pengukuran, bukan polling agresif tanpa dasar.

## 6. Pipeline lirik

LRCLIB dipakai sebagai provider v0.2. Dokumentasi API resmi diperiksa pada 17 September 2026: klien menyertakan User-Agent berisi nama/versi/link proyek, menjalankan request berurutan, jeda 350 ms, dan menghormati `Retry-After` pada HTTP 429. Tidak ada API key atau unggahan lirik. Attribution LRCLIB ditampilkan di Setup. Integrasi ini tidak menganggap lisensi kode server sebagai lisensi seluruh konten lirik; distribusi publik tetap memerlukan review tersendiri.

Pipeline saat ini: debounce metadata 650 ms → normalisasi judul dekoratif tanpa menghapus live/remix → exact lookup judul/artis/durasi → pencarian terstruktur judul/artis (selalu dijalankan kecuali exact lookup mengembalikan record instrumental; kegagalannya diabaikan bila sudah ada kandidat) → pemilihan hasil dengan judul/artis sama setelah normalisasi dan selisih durasi maksimal 3 detik, mengutamakan bertimestamp lalu durasi terdekat → parse dan cache. Hasil tanpa durasi tidak dianggap cocok. Pencarian lanjutan diperlukan karena exact lookup kadang hanya mengembalikan plain text walaupun hasil sinkron tersedia pada record lain.

Cache memakai hash SHA-256 dari query terurut di `~/Library/Caches/io.github.lanstheprodigy.ririku/Lyrics-v2` (sejak v0.2.2; folder `Lyrics-v1` versi lama tidak dibaca atau dipangkas), maksimum 300 berkas; hasil ditemukan berlaku 30 hari, hasil kosong 30 menit. Plain text ditandai tidak sinkron dan tidak digulir mengikuti timer. Hasil instrumental ditampilkan sebagai status. Kesalahan jaringan dicoba kembali setelah 30 detik saat track masih aktif, tetap tunduk pada cooldown provider. Pergantian track/metadata membatalkan task; hasil lama tidak boleh menimpa track baru.

Impor LRC UTF-8 melalui Setup, maksimal 1 MB, tetap tersedia sebagai override manual selama sesi. **Kembali ke hasil otomatis** melepaskan override manual dan meminta ulang provider untuk lagu aktif dengan melewati pembacaan cache (`force`), lalu menulis hasil baru ke cache. Positive offset manual menunda lirik; offset metadata LRC diterapkan parser secara terpisah.

Artwork berasal dari elemen gambar player bar YouTube Music, dengan fallback thumbnail video YouTube. Native client hanya menerima HTTPS pada host gambar yang diizinkan, membatasi redirect, ukuran unduhan 2 MB, dimensi sumber 8192 px, dan downsample 256 px. Cache artwork dibatasi 40 gambar dalam memori. Placeholder hanya dipakai saat gambar belum tersedia/gagal.

Normalisasi metadata tanpa membuang versi rekaman penting → pencarian dengan judul/artis/durasi → evaluasi kecocokan → cache → parse timestamp → pilih baris aktif.

- Jangan otomatis memilih hasil dengan judul mirip jika versi/durasi tidak cocok.
- Cancel request saat lagu berubah; respons lambat hanya boleh diterapkan jika track/revision masih sesuai.
- Parser perlu menangani timestamp ganda, metadata LRC, offset, urutan tidak teratur, dan baris invalid.
- Cache `Lyrics-v2` menggunakan query judul/artis/durasi; perubahan kebijakan pencocokan berikutnya harus menaikkan versi cache. Normalisasi judul yang berubah menghasilkan key baru, tetapi perubahan aturan pemilihan kandidat tidak.
- Pisahkan status loading, synced, plainText, unavailable, mismatch, offline, dan error.

## 7. Keamanan dan lifecycle

- Batasi akses extension ke YouTube dan YouTube Music; akses subframe/all-sites harus dibenarkan jika ternyata diperlukan.
- Allowlist extension ID pada host; validasi tipe/ukuran pesan dan whitelist command.
- Jangan meneruskan string dari halaman sebagai shell command atau AppleScript mentah.
- IPC lokal harus memvalidasi peer; jangan membuka HTTP listener publik.
- Artwork URL dianggap input tidak tepercaya; batasi skema, ukuran, timeout, dan perilaku redirect.
- Reconnect, heartbeat/staleness, sleep/wake, restart browser, dan service worker termination wajib diuji.
- Log development tidak menyimpan riwayat lagu/URL lengkap secara default; kredensial tidak pernah dicatat.

## 8. Referensi untuk validasi berikutnya

Dokumen resmi yang perlu diperiksa saat implementasi: Chrome Extensions Content Scripts dan Native Messaging; Apple AppKit panel/window behavior dan Automation; scripting dictionary pemutar lokal; dokumentasi API LRCLIB. Referensi ini adalah daftar pekerjaan validasi, bukan klaim sudah diuji pada Mac pengguna.
