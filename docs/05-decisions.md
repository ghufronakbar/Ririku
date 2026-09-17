# Catatan keputusan

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
