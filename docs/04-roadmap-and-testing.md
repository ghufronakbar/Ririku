# Roadmap dan pengujian

## Validasi v0.3.0 — 17 September 2026

Rename ke Ririku: `check-localization.py` (131 key × id/ja), `bash scripts/build-app.sh`, dan `codesign --verify --deep --strict build/Ririku.app` berhasil; Info.plist berisi `io.github.lanstheprodigy.ririku`, executable `Ririku`, dan versi 0.3.0 (build 4). `node --check` semua skrip extension serta validasi JSON manifest lulus. `install-host.py` dengan HOME sementara menulis `io.github.lanstheprodigy.ririku.bridge.json` yang menunjuk `RirikuHost` dan tetap menolak ID tidak valid. Fixture Node extension dan harness Swift dalam bundle `.app` (bahasa, `UIText`, render/demo) diulang terhadap sumber yang sudah di-rename dan lulus. Pencarian teks tidak menemukan identifier lama di kode, skrip, extension, maupun terjemahan.

Belum diuji: app Ririku dengan Chrome sungguhan setelah registrasi ulang native host dan reload extension v0.3.0, rilis GitHub yang diunduh (Gatekeeper/Open Anyway), serta ketersediaan nama di luar pencarian web.

## Validasi v0.2.5 — 17 September 2026

Riset sebelum implementasi memakai paket percobaan terpisah: `.app` dengan `.lproj` di `Contents/Resources` memilih en/id/ja sesuai urutan bahasa sistem dan kembali ke English untuk fr/de; `Bundle.module` gagal di dalam `.app` atau membuat codesign gagal bila ditaruh di root; `String(localized:locale:)` tidak mengganti bahasa, sedangkan sub-bundle `.lproj` dan `LocalizedStringResource.locale` berhasil.

Hasil implementasi: `swift build`, `bash scripts/build-app.sh`, `codesign --verify --deep --strict`, `plutil -lint` untuk ketiga `.strings`, `node --check` semua skrip extension, dan validasi JSON manifest/`_locales` berhasil. `check-localization.py` melaporkan 131 key lengkap untuk id dan ja. Harness sementara dalam bundle `.app` lulus untuk default `system`, resolusi sistem (en-ID→en, id-ID→id, ja-JP→ja, fr/de→en, zh-Hans+ja→ja), penggantian langsung en→id→ja, callback bahasa, persistensi dan pemulihan preferensi, status `UIText` tersimpan yang ikut berganti bahasa, `BridgeError` berargumen, argumen verbatim, fallback key, serta label demo. Render SwiftUI aktual Setup (seluruh section) dan panel expanded dalam ketiga bahasa diperiksa visual tanpa teks terpotong. Fixture Node dengan mock Chrome lulus untuk fallback bahasa Chrome, `hello`/`preferences` dari app, penolakan kode tidak valid, judul action, pesan disconnect, app lama tanpa field bahasa, dan kesamaan key antarbahasa.

Belum diuji: pertukaran `hello`/`preferences` melalui socket dan native host sungguhan (app pengguna sedang berjalan sehingga lock socket tidak diganggu), popup di Chrome setelah reload extension v0.2.5, perubahan bahasa sistem saat app berjalan (mode sistem dihitung saat start/pergantian preferensi; buka ulang app bila perlu), VoiceOver dalam tiga bahasa, daftar bahasa per-app di System Settings untuk app menu bar, dan review penutur asli untuk terjemahan Jepang.

## Validasi v0.2.4 — 17 September 2026

Fixture lulus: 122 sampel frame expand/collapse mempertahankan top edge/center; NSWindow aktual juga mempertahankan top edge saat resize; baris multilingual beda timestamp, teks campuran Jepang+Inggris, serta aksara Korea/China tidak dibuang; toggle off mengembalikan raw cues. Cache アイドル record 2116394 dibaca tanpa diubah dan pada posisi 31 detik memilih baris Jepang.

Model fixture lulus untuk loading tanpa area status, notice miss 3 detik, pencegahan notifikasi berulang, pembatalan notice saat lagu berubah, pergantian lagu tidak mengubah expanded, dan invalidasi cache preferensi. Render native playing/paused/empty berhasil; gambar paused menunjukkan bar datar dan gambar empty menunjukkan header saja. Ini bukan benchmark performa atau bukti motion sempurna pada layar pengguna. Uji lanjutan: hover cepat berulang/retarget, pergantian layar, Reduce Motion, stop/disconnect, serta lagu multilingual dengan vokal simultan (toggle preferensi off bila ingin semua cue).

## Validasi v0.2.3 — 17 September 2026

Fixture lokal lulus: 1/2/3 baris dan batas awal/akhir; hide/show mengubah geometri; lebar dibatasi layar; preferensi tersimpan; playing→playing dengan track baru mengikuti sumber, heartbeat lama tidak merebutnya, manual pin tetap berlaku. Render native mode ringkas 1/2/3 dan terbuka dengan/tanpa lirik berhasil; gambar ringkas 2 baris dan terbuka 3 baris diperiksa visual.

Fixture JavaScript gabungan MAIN/isolated lulus untuk identitas getter mengalahkan URL lama, play dari halaman search tanpa `v`, video/bar diganti, caption awal dan setelah transisi, seek/CC off, command untuk track lama ditolak, serta validasi asal/payload. Uji ini bukan verifikasi DOM/live player Chrome. Pengguna perlu reload extension v0.2.3 lalu refresh tab sekali, kemudian mencoba search→play berulang, autoplay, mode Music/Video, background tab, dan pergantian playlist tanpa refresh. Kelancaran hover/pop-up serta Reduce Motion perlu diuji di layar nyata; tidak ada hasil benchmark CPU/baterai spectrum.

## Validasi v0.2.2 — 17 September 2026

Build Swift dan fixture sementara lulus: urutan kandidat durasi terdekat, durasi null terakhir, penolakan klip 4 detik untuk pemutar 241 detik, normalisasi artis `- Topic`, lookup otomatis, ketiga mode sumber, tidak ada request pencarian pada mode caption, offset per lagu/persistensi/batas finite, identitas lintas YouTube/Music, serta pembatalan pencarian saat lagu berubah. Setup native berhasil dirender dan diperiksa; Form dapat di-scroll untuk kontrol di bawah layar. Fixture tidak membuktikan timing terhadap audio nyata.

Uji pengguna berikutnya: pilih kandidat 4:03 untuk pemutar sekitar 4:01 dibanding versi 3:44/0:04; pastikan artis/versi cocok; uji offset positif/negatif, berganti lagu lalu kembali, restart app, ketiga mode termasuk Music tanpa CC, serta pencarian alias judul. Pilihan kandidat manual belum persisten setelah restart, sedangkan mode/offset sudah tersimpan. Jangan mengklaim durasi sama menjamin timestamp akurat.

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
