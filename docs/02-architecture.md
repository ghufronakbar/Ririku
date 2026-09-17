# Arsitektur awal

[Kembali ke indeks](../README.md)

Seluruh bagian dokumen ini adalah rancangan, belum implementasi. Detail API dan kelayakan adapter harus diverifikasi saat technical spike.

## 1. Komponen

```text
YouTube / YouTube Music
  ↕ Chrome content script
  ↕ extension service worker
  ↕ native messaging host
  ↕ local IPC (mekanisme belum dipilih)
Native macOS application
  ├─ Browser adapter
  ├─ Apple Music adapter (perlu validasi)
  ├─ Spotify adapter (perlu validasi)
  ├─ Playback coordinator → sumber terpilih
  ├─ Lyrics resolver → provider / cache / parser
  ├─ Lyrics clock → posisi aktif / offset
  └─ SwiftUI views + AppKit panel controller
```

Panel musik dan jendela Setup memiliki lifecycle terpisah. Sumber dipilih di jendela Setup, bukan pop-up notch. Usulan: preferences store bersama memasok pilihan sumber dan tampilan ke coordinator serta views, menerapkan preview langsung, dan menyimpan preferensi lokal pada aplikasi native. Membuka Setup kembali mengaktifkan jendela yang sudah ada, bukan membuat duplikat.

Native messaging host adalah komponen transport, bukan diasumsikan identik dengan GUI app. Registrasi host, framing pesan, batas ukuran, pembatasan extension ID, dan lifecycle perlu dibuktikan. Transport host-ke-app belum dipilih.

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
| connectionState | connected, stale, disconnected, permissionRequired |

Perintah membawa commandId, sourceId, sessionId, trackId/revision bila relevan, aksi, dan argumen. Respons mengembalikan acknowledgement/error. Jangan memperbarui playback permanen hanya berdasarkan klik; rekonsiliasi dengan snapshot aktual. Perintah seek wajib divalidasi terhadap durasi dan kemampuan sumber.

## 4. Pemilihan sumber

Usulan default: pilih sumber yang baru memulai playback bila belum ada pilihan manual. Setelah dipilih manual, pertahankan pilihan selama sesi tersedia. Jangan mengirim kontrol ke semua pemutar. Sumber hilang → tampilkan terputus dan tawarkan sumber lain; jangan diam-diam mengalihkan perintah yang sudah antre.

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

LRCLIB adalah kandidat provider, bukan dependensi yang telah divalidasi. Periksa dokumentasi, ketentuan penggunaan, attribution, rate limits, dan kebijakan caching sebelum integrasi.

Normalisasi metadata tanpa membuang versi rekaman penting → pencarian dengan judul/artis/durasi → evaluasi kecocokan → cache → parse timestamp → pilih baris aktif.

- Jangan otomatis memilih hasil dengan judul mirip jika versi/durasi tidak cocok.
- Cancel request saat lagu berubah; respons lambat hanya boleh diterapkan jika track/revision masih sesuai.
- Parser perlu menangani timestamp ganda, metadata LRC, offset, urutan tidak teratur, dan baris invalid.
- Simpan cache dengan identitas provider, versi pencocokan, dan identitas rekaman. Detail TTL/batas ukuran masih terbuka.
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
