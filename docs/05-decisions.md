# Catatan keputusan

## Revisi v0.3.0 — 17 September 2026

Pengguna memutuskan menyiapkan proyek sebagai open source. Nama **Notch Box** ditinggalkan karena sudah dipakai app NotchBox di Mac App Store dengan fitur musik di notch; kandidat **Ririkku** ditolak karena `ririkku.com` adalah pemutar musik berlirik Jepang. Nama **Ririku** dipilih karena pencarian web tidak menemukan app musik/lirik dengan nama tersebut (bukan pemeriksaan merek resmi). Lisensi MIT dipilih karena sederhana dan tidak ada dependensi pihak ketiga. Akun `lanstheprodigy` menjadi pemilik repository dan pemegang hak cipta; email pada histori commit boleh tetap publik. Distribusi harus gratis: tanpa Apple Developer Program/notarisasi dan tanpa Chrome Web Store, sehingga app dirilis ber-signature ad-hoc dan extension dipasang lewat Load unpacked dengan tutorial. Pengaturan lama tidak dimigrasi. Pilihan teknis agen: identifier reverse-DNS `io.github.lanstheprodigy.ririku`, versi dinaikkan ke 0.3.0 karena identifier berubah. Rencana lanjutan (usulan, belum dikerjakan): ID extension tetap melalui `key` manifest agar app dapat mendaftarkan native host tanpa Terminal, dokumentasi English sebagai bahasa utama dengan terjemahan id/ja untuk README dan panduan pengguna, file komunitas, serta CI/rilis GitHub. Dokumen terdampak: README, 01, 02, 04, 05, 06.

## Koreksi dokumentasi — 17 September 2026

Bukan keputusan produk baru. Pemeriksaan dokumen terhadap kode menemukan bagian isi yang tertinggal dari catatan versi: path cache `Lyrics-v1` (kode memakai `Lyrics-v2` sejak v0.2.2), offset disebut global (kode per lagu sejak v0.2.2), nama tombol **Cari ulang**/**Impor LRC cadangan…**, alur pencarian LRCLIB, pop-up ganti lagu dan motion spring pada spesifikasi UI, aturan validasi agen yang masih menganggap proyek hanya dokumentasi, serta status usulan/pertanyaan terbuka yang sudah terjawab. Pengguna menyetujui koreksi. Nama tombol **Kembali ke hasil otomatis** dipertahankan; perilakunya (meminta ulang LRCLIB tanpa cache) dijelaskan di dokumen. Tidak ada perubahan kode; folder `Lyrics-v1` dan key `lyricOffset` lama hanya didokumentasikan, tidak dihapus otomatis. Dokumen terdampak: README, 02, 03, 05, 06, AGENTS.

## Revisi v0.2.5 — 17 September 2026

Pengguna meminta UI multi-bahasa (English, Bahasa Indonesia, 日本語) dengan default English atau bahasa sistem bila didukung. Setelah riset kelayakan tanpa perubahan kode, pengguna memilih opsi 2: ikuti sistem + pemilih bahasa di Setup yang langsung berlaku. Alternatif hanya-ikuti-sistem ditolak karena tidak dapat diganti dari app; pemilih dengan restart ditolak karena kurang nyaman. Pilihan teknis agen: `.strings` dengan key English (String Catalog butuh Xcode), `.lproj` disalin skrip build alih-alih `Bundle.module`, lookup sub-bundle untuk penggantian tanpa restart, status model sebagai key + argumen, serta bahasa app diteruskan ke popup extension lewat bridge. Dokumentasi proyek tetap berbahasa Indonesia sesuai panduan agen. Dokumen terdampak: README, 01, 02, 03, 04, 06.

## Revisi v0.2.4 — 17 September 2026

Disetujui pengguna: top-sticky resize, tanpa auto-expand lagu baru, status lookup tidak permanen di island, spectrum dekoratif, serta perbaikan cue Jepang untuk アイドル. Timer resize terikat durasi dan diakhiri setelah selesai, menggantikan kombinasi animasi frame/layout sebelumnya. Notice miss dipilih 3 detik. Spectrum tidak memakai capture/izin baru. Preferensi cue Jepang dapat dimatikan; tidak menjanjikan deteksi romaji versus vokal Inggris simultan secara semantik. Raw LRC dan cache tidak ditulis ulang.

## Revisi v0.2.3 — 17 September 2026

Pengaturan baris/visibility/ukuran dan transisi popup diterapkan sesuai permintaan. Larangan sementara animasi ditafsirkan untuk spectrum yang sedang dibahas; ikon spectrum tidak diubah. Metadata pemutar ditambahkan untuk mengatasi ketergantungan identitas lagu pada URL SPA. Preferensi bahasa アイドル tidak diubah: inspeksi cache membuktikan record Jepang+romaji bertimestamp sama; penjelasan dan tradeoff dicatat di dokumen 07, menunggu arahan pengguna.

## Revisi v0.2.2 — 17 September 2026

Pengguna menyetujui pemilih sumber lirik di Setup, offset, dan pemilihan kandidat yang mendekati durasi pemutar. Otomatis kini LRCLIB-first, menggantikan prioritas caption v0.2.1; pengguna dapat mengunci salah satu sumber. Daftar manual mengurutkan kandidat menurut selisih durasi, sedangkan lookup otomatis tetap konservatif (judul/artis/±3 detik). Offset diterapkan per video, bukan global. Durasi digunakan untuk matching, bukan scaling otomatis yang bisa merusak timing ketika ada intro/outro atau versi rekaman berbeda. Kandidat manual berlaku selama sesi app; persistensi pilihan merupakan pekerjaan lanjutan.

## Revisi v0.2.1 — 17 September 2026

Laporan pengguna menunjukkan timestamp LRCLIB tidak selalu cocok dengan video dan judul bilingual menghalangi matching. Implementasi kini mengutamakan caption DOM aktif, termasuk caption otomatis jika ditampilkan pemutar. Normalisasi judul diperbaiki tanpa menebak semua alias Inggris/Jepang. LRCLIB tetap fallback, bukan jaminan alignment audio. Tidak menambahkan OCR/transkripsi. Integrasi Chrome nyata masih perlu validasi setelah upgrade extension.

[Kembali ke indeks](../README.md)

Dicatat 17 September 2026. Dokumen ini membedakan persetujuan pengguna dari rekomendasi teknis.

## 1. Disepakati

| ID | Keputusan | Alasan |
| --- | --- | --- |
| D-001 | Aplikasi macOS native dan sederhana | Penggunaan pribadi, tidak ingin aplikasi kompleks |
| D-002 | Fokus kontrol musik, lirik sinkron, dan UI/animasi Dynamic Island | Kebutuhan inti pengguna |
| D-003 | Target Chrome YouTube/Music, Apple Music, Spotify | Cakupan pemutar yang diminta |
| D-004 | Chrome menjadi prioritas pertama | Pemutar sehari-hari pengguna |
| D-005 | Extension Chrome pendamping diperbolehkan | Disetujui setelah diskusi integrasi |
| D-006 | Dokumentasi Markdown sebelum review mockup dan implementasi | Permintaan pengguna pada tahap ini |
| D-007 | Visual adjustable melalui tombol Setup yang membuka jendela terpisah | Arahan pengguna, 17 September 2026 |
| D-008 | Pemilih sumber berada di jendela Setup, bukan pop-up notch | Menjaga pop-up fokus pada musik dan lirik; 17 September 2026 |
| D-009 | Melanjutkan dari review mockup ke implementasi prototipe | Instruksi pengguna “lanjutkan”, 17 September 2026; bukan persetujuan semua detail teknis berikutnya |
| D-010 | Lirik otomatis, thumbnail nyata, koneksi/pemilihan sumber otomatis, serta respons klik extension | Permintaan setelah uji pengguna, 17 September 2026; impor LRC menjadi cadangan |
| D-011 | Antarmuka English, Bahasa Indonesia, 日本語; ikuti bahasa sistem dengan fallback English dan pemilih langsung di Setup | Permintaan pengguna dan pilihan opsi 2 setelah riset, 17 September 2026 |
| D-012 | Proyek open source dengan nama Ririku, lisensi MIT, pemilik `lanstheprodigy` | Keputusan pengguna setelah pemeriksaan nama, 17 September 2026 |
| D-013 | Distribusi gratis: rilis GitHub ber-signature ad-hoc tanpa notarisasi, extension via Load unpacked dengan tutorial, tanpa migrasi pengaturan lama | Keputusan pengguna, 17 September 2026 |
| D-014 | Dokumentasi berbahasa utama English, dengan bahasa lain untuk pengguna | Permintaan pengguna, 17 September 2026; struktur detail masih usulan |

## 2. Usulan, belum persetujuan final

Status diperbarui 17 September 2026. **Diimplementasikan** berarti sudah ada di prototipe sebagai pilihan teknis, bukan otomatis disepakati pengguna.

| Usulan | Status sekarang |
| --- | --- |
| SwiftUI + AppKit sebagai stack native | Diimplementasikan; tetap pilihan teknis, belum persetujuan final |
| Native Messaging dan IPC lokal sebagai jalur penghubung browser | Diimplementasikan (native host + Unix socket); uji Chrome nyata end-to-end masih perlu |
| Automation lokal untuk pemutar desktop bila kemampuan aplikasi memadai | Belum dikerjakan |
| LRCLIB sebagai kandidat provider lirik | Diimplementasikan sejak v0.2; pemilih sumber lirik di Setup disetujui pengguna (v0.2.2). Review lisensi konten untuk distribusi publik belum |
| Compact + satu baris lirik + expanded saat hover/klik | Diganti permintaan pengguna v0.2.3: tampil/sembunyi lirik dan 1/2/3 baris pada kedua mode; expanded tetap lewat hover/klik/menu |
| Kontrol seek, cache, dan offset | Seek dan cache diimplementasikan; offset per lagu disetujui pengguna (v0.2.2) |
| Detail penyesuaian visual: ukuran panel, aksen, dan animasi | Lebar adjustable diminta pengguna (v0.2.3); aksen dan toggle animasi diimplementasikan sebagai pilihan teknis |
| Distribusi lokal dahulu; nama Notch Box Mac sementara | Diganti D-012/D-013: nama Ririku, distribusi gratis open source |

## 3. Pertanyaan terbuka

| Pertanyaan | Kapan dituntaskan | Status per 17 September 2026 |
| --- | --- | --- |
| Layout, warna, ukuran, dan motion cocok? | Review mockup | Sebagian: revisi pengguna v0.2.3–v0.2.4 (ukuran adjustable, top-sticky, tanpa auto-expand). Penilaian harian di layar nyata masih terbuka |
| Baris lirik selalu terlihat atau opsional/default tersembunyi? | Review mockup | Terjawab v0.2.3: dapat disembunyikan, default tampil 3 baris |
| Versi macOS, jenis chip, geometri notch, monitor eksternal? | Sebelum shell native | Sebagian: macOS 15.7.2 arm64 dicatat, geometri notch dibaca runtime. Model layar dan monitor eksternal belum |
| Kemampuan scripting Apple Music dan Spotify lokal? | Spike adapter | Terbuka |
| Provider lirik, ketentuan penggunaan, dan caching? | Sebelum integrasi provider | Sebagian: LRCLIB diintegrasikan setelah dokumentasi API diperiksa, cache lokal diterapkan. Lisensi konten untuk distribusi publik terbuka |
| IPC, host registration, dan pemasangan extension lokal? | Spike Chrome | Diimplementasikan dan diuji dengan fixture/native host lokal; uji popup dan situs nyata setelah reload tetap perlu |
| Fullscreen, Spaces, dan layar tanpa notch? | Pengujian panel native | Terbuka; fallback main screen belum diverifikasi |
| Signing/distribusi untuk perangkat lain? | Setelah penggunaan lokal stabil | Diputuskan D-013: ad-hoc tanpa notarisasi; pengalaman Gatekeeper pada rilis nyata perlu validasi |

## 4. Aturan pembaruan

Saat keputusan berubah, catat tanggal, alasan, serta dokumen terdampak. Jangan menaikkan usulan menjadi disepakati hanya karena sudah divisualisasikan. Setelah fitur dibuat, perbarui status dan sertakan hasil pengujiannya; keberhasilan mockup tidak membuktikan integrasi native.

## 5. Pilihan implementasi prototipe — 17 September 2026

Pilihan teknis agen, dapat direvisi, bukan keputusan produk tambahan yang diasumsikan disetujui:

- Swift Package Manager dan macOS 14+ agar dapat dibangun memakai Command Line Tools yang tersedia; paket menghasilkan app dan host terpisah.
- Unix domain socket dengan pemeriksaan UID untuk transport host-ke-app, tanpa HTTP listener atau layanan cloud.
- Shell native minimal dikerjakan bersama spike Chrome agar sumber dan timing bisa diamati langsung; gate integrasi situs nyata tetap belum selesai.
- Impor LRC lokal mendahului pencarian daring untuk memisahkan verifikasi clock dari masalah matching/ketentuan provider.
- Heartbeat browser 1 detik dan snapshot event playback; status dianggap stale setelah 5 detik. Ini baseline prototipe, belum hasil optimasi resource.
- Target Apple Music dan Spotify tetap di roadmap dan ditandai belum tersedia di Setup.

## 6. Revisi v0.2 — 17 September 2026

- Kebijakan sumber pertama/manual-only diganti otomatis mengikuti pemutar yang mulai memainkan musik; manual pin tetap tersedia dan memulihkan sesi tab yang sama.
- LRCLIB kini diintegrasikan setelah dokumentasi API diperiksa. Identifikasi klien, throttling, cooldown, pencocokan konservatif, dan cache lokal diterapkan.
- Impor LRC bukan lagi alur utama. Plain text tetap diberi label tidak sinkron; tidak ada janji setiap lagu memiliki timestamp akurat.
- Popup extension menampilkan status dan tombol Setup/reconnect. Membuka aplikasi yang sedang tertutup hanya dilakukan lewat klik **Buka Setup**, bukan menghidupkannya kembali tanpa henti setelah pengguna memilih Keluar.
- Thumbnail diambil dari host gambar YouTube/Google yang dibatasi. Metadata judul/artis/durasi dikirim ke LRCLIB saat pencarian otomatis aktif; pengungkapan privasi di Setup diperbarui.
- Upgrade extension unpacked memerlukan reload satu kali dan refresh tab lama. Ini langkah update development, bukan kewajiban menyambung setiap lagu.
