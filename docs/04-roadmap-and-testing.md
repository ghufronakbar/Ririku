# Roadmap dan pengujian

## Validasi v0.2.1 — 17 September 2026

Fixture JavaScript sementara lulus untuk perubahan caption, teks rolling, jeda, seek, pause, iklan, CC off, dan navigasi. Fixture Swift memeriksa judul bilingual, kredit artis sesudah judul, dan qualifier Live. Build native lulus. Ini bukan bukti sinkronisasi terhadap audio/video nyata.

Setelah reload extension dan refresh tab, masih perlu uji pengguna: Akuma no Ko pada kedua situs; Crying for Rain/Kawaki wo Ameku; CC otomatis; perubahan bahasa; seek saat pause; CC off; pergantian video; mode Song/Video YouTube Music. Periksa label Caption video dan kesamaan teks dengan CC. Subtitle baked-in tidak didukung. Timestamp LRCLIB tidak diperbaiki lewat tebakan offset global.

[Kembali ke indeks](../README.md)

## 1. Tahapan

| Tahap | Hasil | Syarat lanjut |
| --- | --- | --- |
| 0. Dokumentasi dan desain | Brief, arsitektur, state UI, mockup | Pengguna menyetujui arah visual |
| 1. Technical spike Chrome | Metadata, posisi, kontrol, reconnect | Data nyata teruji di YouTube dan YouTube Music |
| 2. Mesin lirik | Matching, cache, parser, clock, fallback | Pause/seek/ganti lagu tidak memakai lirik atau anchor lama |
| 3. Shell native | Panel AppKit, SwiftUI, motion, settings dasar | Tidak mengambil fokus; geometri notch benar |
| 4. Pemutar desktop | Adapter Apple Music dan Spotify | Kemampuan dan izin masing-masing terbukti |
| 5. Hardening lokal | Packaging lokal, logging, pengukuran resource | Skenario harian lolos tanpa masalah kritis |

Urutan dapat disesuaikan setelah spike. Tidak menjanjikan tenggat sebelum mengetahui kelayakan integrasi.

## 2. Checklist saat ini

- [x] Tujuan native dan fitur inti disepakati.
- [x] Chrome sebagai prioritas dan extension pendamping disetujui.
- [x] Dokumentasi awal dibuat.
- [x] Review mockup menghasilkan arahan Setup terpisah; pengguna meminta melanjutkan implementasi.
- [x] Versi macOS dan toolchain dicatat: macOS 15.7.2, arm64, Swift 6.1.2. Model layar belum dicatat.
- [ ] Integrasi pemutar dibuktikan.
- [x] Build debug/release berhasil; view native dirender melalui harness lokal. Bundle diluncurkan dan handshake host terhadap aplikasi yang berjalan berhasil. Pemasangan Chrome tetap belum selesai.

Shell native minimal dikerjakan bersama spike transport untuk memberi tempat pengujian sumber dan timing. Gate pemutar nyata belum dianggap selesai. Pencarian lirik otomatis serta adapter desktop tidak ikut dinyatakan selesai.

## 3. Kriteria penerimaan

- Judul, sumber, posisi, dan status yang ditampilkan berasal dari sesi yang benar.
- Play/pause/skip dikirim hanya ke sumber terpilih; command failure terlihat dan tidak meninggalkan state palsu.
- Setelah seek, baris terpilih sesuai snapshot terbaru; lirik tidak terus maju saat paused/buffering/stale.
- Respons pencarian lagu lama tidak pernah menimpa lagu yang baru.
- Lirik tanpa timestamp tidak diberi label synced.
- Iklan atau metadata ambigu tidak diam-diam dipasangkan dengan lirik lagu yang salah.
- Extension terputus/restart tidak memerlukan restart seluruh Mac untuk pulih.
- UI tidak mengambil fokus ketika pengguna mengetik di aplikasi lain.
- Setup dibuka melalui tindakan eksplisit, menggunakan jendela terpisah, dan tidak menduplikasi jendela saat dibuka ulang. Pemilih sumber tidak berada di pop-up musik.
- Preferensi tampilan diterapkan tanpa menabrak notch; menutup Setup tidak menghentikan playback. Persistensi pilihan diuji pada aplikasi native, bukan dianggap terbukti dari mockup.
- Klik ikon extension menampilkan status, bukan panel kosong; akses Setup membuka jendela native yang sama.
- Mode otomatis mengikuti pemutar yang baru mulai; heartbeat biasa tidak merebut pilihan. Mode manual tetap mengunci tab dan memulihkan sesi baru tab yang sama.
- Thumbnail ditampilkan jika tersedia; unduhan gambar dan respons lirik track lama tidak boleh menimpa track baru.
- Lirik otomatis tidak membutuhkan impor per lagu; cache mencegah request berulang, HTTP 429 dihormati, dan lirik tanpa timing tidak diberi label synced.
- Tidak ada network traffic yang tidak diperlukan selain pengambilan metadata/artwork/lirik yang dijelaskan.

Usulan target awal: UI memilih baris benar dalam ≤300 ms setelah snapshot seek valid diterima. Ini mengukur respons aplikasi, bukan jaminan ketepatan timestamp penyedia atau latensi end-to-end. Latensi pemutar-ke-panel dan drift sesi panjang dilaporkan terpisah; target akhir ditetapkan setelah baseline.

## 4. Matriks uji manual

| Area | Skenario |
| --- | --- |
| YouTube | Video musik, playlist, pause, seek, navigasi tanpa reload, judul nonmusik |
| YouTube Music | Ganti lagu, antrean, tab background, perbedaan versi rekaman |
| Browser lifecycle | Multi-tab, tab ditutup, refresh, Chrome restart, extension reconnect |
| Timing | Buffering, playback rate, seek cepat berulang, awal/akhir lagu |
| Iklan/live | Iklan sebelum/tengah konten, live stream, durasi unknown |
| Multi-source | Dua pemutar aktif, pilihan manual, sumber terpilih hilang |
| Lirik | Synced, plain text, instrumental, unavailable, offset, provider timeout |
| Desktop apps | Apple Music/Spotify terbuka/tertutup, izin ditolak/diberikan ulang |
| macOS | Sleep/wake, Spaces, fullscreen, perubahan resolusi, monitor eksternal |
| UI | Teks panjang, Unicode, Reduce Motion, keyboard, VoiceOver |

## 5. Rencana unit dan integration test

Parser timestamp; offset positif/negatif; interpolasi pause/rate/buffering; stale messages; revisi track; source arbitration; validasi command dan protokol; cancellation pencarian; cache key; dan capability-driven controls. Gunakan fixture deterministik, bukan request jaringan nyata dalam unit test.

## 6. Resource dan distribusi

Ukur CPU, memori, wakeups, network request, dan polling saat idle/playing/panel expanded. Tetapkan budget sesudah baseline pada Mac pengguna. Jangan mengklaim efisien sebelum ada hasil.

Sebelum penggunaan harian: dokumentasikan build, registrasi native host, pemasangan extension, izin Automation, uninstall, dan pemulihan koneksi. Jangan meminta izin Accessibility/Screen Recording tanpa kebutuhan yang dibuktikan.
