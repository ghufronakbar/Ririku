# Arsitektur awal

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

Native messaging host adalah executable terpisah di bundle aplikasi. Registrasi host dibuat melalui skrip dengan allowlist satu extension ID. Prototipe memakai framing panjang UInt32 little-endian dan JSON, batas 256 KiB, serta Unix domain socket di direktori `/tmp/notchbox-<uid>` dengan mode 0700. Socket bermode 0600; kedua sisi memeriksa UID peer. Hanya satu host/profile Chrome aktif pada satu waktu. Lock file mencegah instance server kedua mengambil socket aktif.

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

Pipeline saat ini: debounce metadata 650 ms → normalisasi judul dekoratif tanpa menghapus live/remix → exact lookup judul/artis/durasi → pencarian terstruktur bila belum mendapat lirik sinkron → pemilihan hasil dengan judul/artis sama setelah normalisasi dan selisih durasi maksimal 3 detik → parse dan cache. Hasil tanpa durasi tidak dianggap cocok. Pencarian lanjutan diperlukan karena exact lookup kadang hanya mengembalikan plain text walaupun hasil sinkron tersedia pada record lain.

Cache memakai hash SHA-256 dari query terurut di `~/Library/Caches/local.notchbox.mac/Lyrics-v1`, maksimum 300 berkas; hasil ditemukan berlaku 30 hari, hasil kosong 30 menit. Plain text ditandai tidak sinkron dan tidak digulir mengikuti timer. Hasil instrumental ditampilkan sebagai status. Kesalahan jaringan dicoba kembali setelah 30 detik saat track masih aktif, tetap tunduk pada cooldown provider. Pergantian track/metadata membatalkan task; hasil lama tidak boleh menimpa track baru.

Impor LRC UTF-8 melalui Setup, maksimal 1 MB, tetap tersedia sebagai override manual selama sesi. **Cari ulang** kembali memakai provider untuk lagu aktif. Positive offset manual menunda lirik; offset metadata LRC diterapkan parser secara terpisah.

Artwork berasal dari elemen gambar player bar YouTube Music, dengan fallback thumbnail video YouTube. Native client hanya menerima HTTPS pada host gambar yang diizinkan, membatasi redirect, ukuran unduhan 2 MB, dimensi sumber 8192 px, dan downsample 256 px. Cache artwork dibatasi 40 gambar dalam memori. Placeholder hanya dipakai saat gambar belum tersedia/gagal.

Normalisasi metadata tanpa membuang versi rekaman penting → pencarian dengan judul/artis/durasi → evaluasi kecocokan → cache → parse timestamp → pilih baris aktif.

- Jangan otomatis memilih hasil dengan judul mirip jika versi/durasi tidak cocok.
- Cancel request saat lagu berubah; respons lambat hanya boleh diterapkan jika track/revision masih sesuai.
- Parser perlu menangani timestamp ganda, metadata LRC, offset, urutan tidak teratur, dan baris invalid.
- Cache v1 menggunakan query judul/artis/durasi; perubahan kebijakan pencocokan berikutnya harus menaikkan versi cache.
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
