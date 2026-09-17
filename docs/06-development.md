# Pengembangan dan pemasangan lokal

## Update v0.2.4

App native v0.2.4 tetap kompatibel dengan extension v0.2.3; tidak perlu reload lagi jika update sebelumnya sudah terpasang. Lagu baru tidak auto-expand; gunakan hover/klik/menu. Status pencarian ada di Setup, dengan notifikasi miss 3 detik di island. Spectrum dekoratif otomatis mengikuti state pemutar, tanpa izin capture audio.

Setup → Lirik → **Utamakan Jepang pada timestamp ganda** aktif secara default. Ini langsung berlaku pada cache lama, termasuk アイドル, tanpa pencarian ulang. Baris Inggris/Korea/dll pada waktu lain dan baris campuran tetap ada. Bila lirik asli memiliki vokal multibahasa bersamaan dengan timestamp persis sama, matikan toggle untuk mempertahankan semua varian. Raw/cache tidak diubah.

## Update v0.2.3

Reload extension di `chrome://extensions` dan refresh tab lama sekali. Versi ini menambahkan helper metadata MAIN world tanpa izin baru; tanpa reload helper belum aktif. Setelah itu, uji play lagu dari hasil pencarian YouTube Music tanpa refresh lagi. Getter internal masih perlu validasi di situs nyata.

Di **Setup → Tampilan**, atur lebar ringkas/terbuka, hide/show lirik, dan 1/2/3 baris. Setting visibility berlaku pada dua mode island. Ukuran minimum mengikuti notch fisik; tinggi mengikuti isi. Transisi panel ease-in/ease-out dapat dimatikan dan mengikuti Reduce Motion. Spectrum belum dianimasikan; pemilihan bahasa Jepang/romaji juga belum diubah.

## Update v0.2.2

Buka **Setup → Lirik → Sumber lirik**. Pilih Otomatis, LRCLIB/LRC saja, atau Subtitle saja. Scroll ke **Cari dan pilih versi lirik**, masukkan judul/artis atau alias, lalu Cari. Bandingkan durasi pemutar dengan kandidat dan klik Pakai; selisih >3 detik perlu pemeriksaan versi. Pilihan manual berlaku sampai app ditutup atau kembali ke hasil otomatis. Offset ±60 detik tersimpan per video, dengan tombol presisi 0,1 detik dan Reset; positif menunda, negatif memajukan. Tidak ada scaling timestamp otomatis.

App native v0.2.2 memakai extension v0.2.1 tanpa perubahan protokol baru, sehingga tidak membutuhkan reload extension lagi jika update caption sebelumnya sudah terpasang. Mode dan offset tersimpan setelah restart; offset global versi lama tidak diterapkan ke semua lagu. Query/cari manual mengirim metadata atau kata pencarian ke LRCLIB; mode Subtitle saja tidak menjalankan lookup LRCLIB.

## Update v0.2.1

Reload extension unpacked di `chrome://extensions`, lalu refresh tab YouTube/YouTube Music yang sudah terbuka. Aktifkan CC; app mengutamakan caption yang terbaca dengan label **Caption video**. Caption otomatis memakai jalur yang sama; app tidak membuat caption sendiri. Teks yang menyatu dalam gambar video tidak dapat dibaca. Tanpa CC, LRCLIB/LRC menjadi fallback dan timing penyedia belum tentu cocok. Impor LRC tidak wajib. Normalisasi baru menghasilkan query baru sehingga cache miss judul lama tidak menghalangi pencarian baru.

[Kembali ke indeks](../README.md)

## 1. Prasyarat dan status

Build awal: macOS 15.7.2 arm64, Swift 6.1.2, Xcode Command Line Tools. Target deployment macOS 14+. Build Intel dan macOS 14 aktual belum diuji. Tidak ada dependensi Swift/JavaScript pihak ketiga yang perlu diunduh.

Komponen yang ada:

| Komponen | Status |
| --- | --- |
| Panel native, Setup terpisah, preferensi visual | Diimplementasikan; render view diperiksa |
| Extension YouTube/YouTube Music | V0.2: popup status, akses Setup, reconnect, dan metadata gambar; perlu reload untuk uji situs |
| Native host dan Unix socket | Diimplementasikan; gunakan hasil verifikasi di bagian 6 |
| Lirik | Otomatis LRCLIB, matching/cancellation, cache disk, clock/offset; LRC manual cadangan |
| Artwork dan sumber | Thumbnail nyata, sumber otomatis atau manual pin, pemulihan sesi tab |
| Apple Music/Spotify | Belum diimplementasikan |
| Launch at login dan distribusi publik | Belum diimplementasikan |

## 2. Build dan jalankan

Jalankan dari root repository:

```sh
swift build
bash scripts/build-app.sh
open "build/Notch Box.app"
```

Skrip menghasilkan `build/Notch Box.app`, metadata bundle, serta signature ad-hoc lokal. Ini bukan notarization untuk distribusi publik. Keluar dari aplikasi sebelum mengganti bundle lewat build ulang.

Aplikasi menggunakan ikon waveform di menu bar, bukan ikon Dock. Setup terbuka pada peluncuran pertama. Selanjutnya pilih **waveform → Setup…**, atau gear di panel musik. Jendela Setup digunakan kembali, bukan dibuat berulang.

Untuk mencoba tanpa Chrome, aktifkan **Setup → Demo lokal (tanpa audio)**. Demo memakai lirik orisinal dan bukan bukti kontrol pemutar nyata. Nonaktifkan demo sebelum menguji browser.

## 3. Pasang extension dan native host

1. Buka `chrome://extensions` di Google Chrome.
2. Aktifkan **Developer mode**.
3. Pilih **Load unpacked**, lalu folder `extension` di repository ini.
4. Salin ID extension yang ditampilkan Chrome: 32 karakter a–p.
5. Daftarkan native host dengan ID tersebut:

```sh
/usr/bin/python3 scripts/install-host.py ID_EXTENSION_DARI_CHROME
```

6. Pastikan Notch Box terbuka. Muat ulang tab YouTube/YouTube Music yang sudah ada, lalu putar video/lagu.
7. Biarkan **Otomatis ikuti pemutar aktif** menyala. Jika ingin mengunci satu tab, matikan toggle tersebut lalu pilih **Pemutar aktif** di Setup.

### Update dari v0.1 ke v0.2

Di profil Chrome yang sudah memasang extension, buka `chrome://extensions`, klik **Reload** pada **Notch Box — Chrome Bridge**, lalu refresh tab YouTube/YouTube Music yang sudah terbuka. Periksa versi **0.2.0**. ID extension dan manifest native host tidak perlu diganti jika folder tidak dipindahkan.

Ini reload sekali untuk memuat kode development baru, bukan langkah yang perlu diulang setiap ganti lagu atau pindah YouTube/YouTube Music. Klik ikon extension sekarang membuka status koneksi dan tombol **Buka Setup aplikasi**; pilihan sumber tetap berada di jendela native.

Host manifest disimpan di `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/local.notchbox.bridge.json`. Skrip hanya mengizinkan extension ID yang diberikan, tidak semua extension. Tidak ada pendaftaran host otomatis sebelum ID pengguna diketahui.

Jika bundle dipindahkan, daftarkan ulang path tujuan:

```sh
/usr/bin/python3 scripts/install-host.py ID_EXTENSION_DARI_CHROME --app "/path/Notch Box.app"
```

Extension hanya berjalan pada `https://www.youtube.com/*` dan `https://music.youtube.com/*`, top frame. Tidak meminta cookies, history, Accessibility, Screen Recording, atau akses semua situs. Satu profile Chrome/native host aktif didukung dalam prototipe.

## 4. Menguji musik dan lirik

- Hover notch untuk membuka panel; klik dapat mempertahankan panel. Escape menutup panel yang menerima fokus.
- Tombol gear membuka Setup; pemilih sumber tidak ada di pop-up.
- Pause/play, skip, serta seek mengikuti kemampuan yang dilaporkan tab. Tombol tidak didukung dinonaktifkan.
- Default **Cari lirik otomatis** mengambil lirik LRCLIB berdasarkan judul, artis, dan durasi. Status membedakan mencari, sinkron, teks tanpa timing, instrumental, tidak ditemukan, dan koneksi gagal.
- **Cari ulang** meminta pencarian baru dan melepaskan override LRC manual untuk lagu aktif. Tetap menghormati cooldown penyedia.
- **Impor LRC cadangan…** tersedia bila lirik belum ada atau pengguna memiliki versi lebih tepat. Gunakan UTF-8 bertimestamp untuk rekaman yang benar. Berkas `samples/senja-demo.lrc` hanya untuk demo.
- Offset positif menunda lirik, negatif mempercepat. Offset manual saat ini global, bukan per lagu.
- Lirik otomatis disimpan sampai 30 hari, maksimum 300 berkas di `~/Library/Caches/local.notchbox.mac/Lyrics-v1`; hasil tidak ditemukan disimpan 30 menit. LRC manual tetap dalam memori sesi. Preferensi visual, mode sumber, mode pencarian, dan offset disimpan melalui UserDefaults.
- Metadata judul/artis/durasi dikirim ke LRCLIB saat pencarian aktif. Thumbnail diambil dari server gambar YouTube/Google yang diizinkan. Klien tidak mengirim cookies, kredensial, atau riwayat browsing.

Urutan smoke test nyata: play → pause → seek maju/mundur → next → buka tab kedua → pilih sumber di Setup → tutup tab → reload → reconnect. Ulangi pada YouTube dan YouTube Music. Cocokkan baris lirik dengan audio, jangan hanya melihat bahwa teks bergerak.

## 5. Batasan dan troubleshooting

- **Panel kosong:** pastikan demo mati dan extension sudah dimuat. Tombol **Buka Setup aplikasi** pada popup extension dapat membuka bundle yang tertutup. Reconnect latar belakang tidak menghidupkan aplikasi kembali setelah pengguna sengaja keluar.
- **Badge `!` di extension:** host belum terdaftar, app belum terbuka, atau koneksi terputus. Reconnect mengikuti heartbeat dengan backoff hingga 15 detik. Periksa ID dan path manifest.
- **Sumber setelah refresh:** mode otomatis memulihkan sumber tanpa memilih ulang. Mode manual memulihkan sesi baru tab yang sama; jika tab ditutup permanen, pilih sumber lain atau aktifkan mode otomatis.
- **Previous/next tidak tersedia:** tombol situs harus tersedia dan aktif; tidak dipalsukan menjadi skip beberapa detik.
- **Lirik meleset:** periksa versi lagu, seek, dan offset. LRC salah rekaman tidak bisa diperbaiki hanya dengan offset tetap.
- **Lirik belum ditemukan:** provider belum tentu memiliki rekaman yang cocok. Judul dekoratif dasar dinormalisasi, tetapi channel uploader yang berbeda dari artis, cover/remix/live, atau metadata ambigu dapat tetap tidak cocok. Jangan mengganti lirik dengan rekaman lain hanya demi menampilkan teks.
- **Hanya teks:** lirik ada tetapi tanpa timestamp yang valid; tampil sebagai teks dengan scroll manual, bukan sinkronisasi palsu.
- **Thumbnail placeholder:** muncul selama unduhan atau jika host/ukuran/format gambar ditolak atau jaringan gagal. Gambar gagal dicoba ulang setelah 30 detik saat sumber aktif.
- **Iklan:** deteksi berbasis DOM bersifat best effort; lirik/kontrol dihentikan ketika terdeteksi. Jangan menganggap semua format iklan sudah teruji.
- **Live stream:** durasi bisa tidak diketahui; seek dinonaktifkan.
- **Metadata YouTube biasa:** nama channel belum tentu nama artis; tidak dipakai sebagai bukti matching lirik otomatis.
- **Fullscreen/Spaces/monitor eksternal:** implementasi awal mengikuti layar bernotch pertama, lalu main screen sebagai fallback; masih perlu verifikasi perangkat nyata.
- **Perubahan UI YouTube:** selector DOM bisa berubah. Cek extension service worker melalui halaman extensions; jangan menyalin cookies atau kredensial ke log.

## 6. Verifikasi pengembangan

Perintah rutin:

```sh
swift build
bash scripts/build-app.sh
node --check extension/background.js
node --check extension/content.js
codesign --verify --deep --strict "build/Notch Box.app"
```

Pemeriksaan fixture terpisah digunakan selama pengerjaan untuk parser LRC, posisi/interpolasi, frame native messaging, source routing, serta render view SwiftUI. Harness sementara bukan suite test permanen dalam repository. Hasil ini tidak menggantikan pengujian Chrome dan audio nyata, VoiceOver, resource, maupun sleep/wake.

Hasil 17 September 2026:

- Build debug dan release berhasil; bundle lokal dihasilkan dan ditandatangani ad-hoc.
- Bundle diluncurkan melalui LaunchServices; proses aplikasi berjalan dan mengembalikan handshake kepada native host sungguhan. Signature bundle serta Info.plist lolos pemeriksaan.
- View player dan Setup dirender dari SwiftUI aktual dan diperiksa secara visual, bukan screenshot mockup web.
- Fixture core memeriksa timestamp/fraction/offset LRC, batas instrumental, pause/buffering/iklan, interpolasi, pesan parsial, dan batas ukuran frame.
- Fixture model memeriksa pemilihan sumber, penolakan sequence duplikat, routing command ke sesi/track yang tepat, tidak mengasumsikan playback berubah sebelum snapshot, serta disconnect.
- Fixture JavaScript memeriksa origin, routing per tab, acknowledgement, sesi lama, metadata, pause/seek, buffering, iklan, dan track lama. Ini DOM buatan, belum selector situs nyata.
- Native host sungguhan diuji dua arah melalui stdin/stdout → Unix socket → server bridge dengan fixture command.
- Installer diuji menggunakan HOME sementara; tidak mendaftarkan ID fiktif pada Chrome pengguna.

Tambahan hasil v0.2, 17 September 2026:

- Normalisasi judul Jepang `【Ado】 unravel 歌いました` menjadi query artis Ado/lagu unravel; penanda live/remix tetap dipertahankan.
- Format judul video `Artis “Lagu”` dipisahkan dari nama artis; label visual seperti official music video/anime special video dipisahkan, tetapi penanda versi audio live/remix tetap dipertahankan. Kecocokan durasi tetap diwajibkan.
- Uji jaringan langsung memakai klien Swift menemukan lirik bertimestamp untuk Ado/unravel dan YOASOBI/あの夢をなぞって, serta berhasil mengambil/decode thumbnail YouTube. Ini menguji ketersediaan provider, bukan menyatakan audio pengguna sudah sinkron sempurna.
- Fixture memeriksa cache lintas instance service, fallback exact plain text ke search synced, record rusak/null, Retry-After, mode sumber otomatis/manual, pemulihan sesi tab, dan pembatalan respons lirik lama.
- Fixture extension memeriksa status popup, kedua tombol, penolakan pengirim popup palsu, metadata artwork/fallback, routing command, handshake, serta reconnect.
- Perubahan extension memerlukan reload sekali pada profil pengguna. Akses otomatis ke profil Chrome tersebut tidak tersedia dalam sesi tool; uji end-to-end popup dan content script yang diperbarui tetap perlu dilakukan setelah reload.

## 7. Struktur kode

```text
Sources/NotchCore/      Playback, parser/matching lirik, framing, Unix socket
Sources/NotchBox/       SwiftUI/AppKit, Setup, coordinator, IPC, LRCLIB/artwork
Sources/NotchBoxHost/   Transport stdin/stdout Chrome ↔ Unix socket
extension/             Manifest V3, worker, content script, popup status
scripts/               Build bundle dan pendaftaran native host
samples/               LRC orisinal untuk demo
build/                 Bundle dan hasil render lokal, tidak masuk Git
```

## 8. Uninstall lokal

Keluar melalui menu **Keluar Notch Box**, hapus extension dari Chrome, lalu hapus hanya manifest `local.notchbox.bridge.json` pada direktori native host di atas dan bundle `build/Notch Box.app`. Jangan menghapus seluruh folder native host karena dapat dipakai aplikasi lain.

Untuk menghapus preferensi aplikasi secara opsional:

```sh
defaults delete local.notchbox.mac
```

Cache lirik dapat dihapus terpisah dari `~/Library/Caches/local.notchbox.mac/Lyrics-v1`; jangan menghapus folder cache aplikasi lain.

Socket dibersihkan saat app keluar normal. Direktori `/tmp/notchbox-<uid>` dapat tersisa; aplikasi memakai ulang direktori miliknya dan tidak menghapus data aplikasi lain.
