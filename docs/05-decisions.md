# Catatan keputusan

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

## 2. Usulan, belum persetujuan final

- SwiftUI + AppKit sebagai stack native.
- Native Messaging dan IPC lokal sebagai jalur penghubung browser.
- Automation lokal untuk pemutar desktop bila kemampuan aplikasi memadai.
- LRCLIB sebagai kandidat provider lirik.
- Compact + satu baris lirik + expanded saat hover/klik.
- Kontrol seek, cache, dan offset sebagai detail versi awal; lokasi source picker sudah diputuskan di Setup.
- Detail penyesuaian visual: ukuran panel, aksen, dan animasi; penerapan langsung dan penyimpanan preferensi lokal.
- Distribusi lokal dahulu; nama Notch Box Mac sementara.

## 3. Pertanyaan terbuka

| Pertanyaan | Kapan dituntaskan |
| --- | --- |
| Layout, warna, ukuran, dan motion cocok? | Review mockup |
| Baris lirik selalu terlihat atau opsional/default tersembunyi? | Review mockup |
| Versi macOS, jenis chip, geometri notch, monitor eksternal? | Sebelum shell native |
| Kemampuan scripting Apple Music dan Spotify lokal? | Spike adapter |
| Provider lirik, ketentuan penggunaan, dan caching? | Sebelum integrasi provider |
| IPC, host registration, dan pemasangan extension lokal? | Spike Chrome |
| Fullscreen, Spaces, dan layar tanpa notch? | Pengujian panel native |
| Signing/distribusi untuk perangkat lain? | Setelah penggunaan lokal stabil |

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
