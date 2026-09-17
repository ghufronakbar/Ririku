# Notch Box Mac

Aplikasi musik macOS pribadi: kontrol pemutar dan lirik tersinkron dalam panel native bergaya Dynamic Island.

**Status:** perencanaan dan eksplorasi desain, 17 September 2026. Belum ada aplikasi native, extension, atau integrasi pemutar yang diimplementasikan. Nama proyek masih sementara.

## Arah proyek

- Native: Swift, SwiftUI, dan AppKit; tanpa Electron atau WebView sebagai UI utama.
- Prioritas pertama: YouTube dan YouTube Music di Google Chrome.
- Target berikutnya: Apple Music dan Spotify desktop, bukan versi web keduanya.
- Extension Chrome pendamping telah disetujui untuk menjembatani pemutar browser.
- Tombol Setup membuka jendela pengaturan terpisah untuk sumber musik dan penyesuaian visual; pemilih sumber tidak berada di pop-up notch.
- Fokus pada kontrol musik, lirik per baris, dan animasi yang halus; bukan kumpulan utilitas desktop.
- Referensi pengalaman: Dynamic Lyrics.app dan NotchBox.app. Tidak menyalin aset atau implementasi aplikasi tersebut.

## Peta dokumentasi

| Dokumen | Isi |
| --- | --- |
| [Product brief](docs/01-product-brief.md) | Tujuan, cakupan, kebutuhan, dan batasan |
| [Arsitektur](docs/02-architecture.md) | Komponen, kontrak data, sinkronisasi, dan keamanan |
| [Spesifikasi UI](docs/03-ui-spec.md) | State panel, layout, animasi, dan aksesibilitas |
| [Roadmap dan pengujian](docs/04-roadmap-and-testing.md) | Tahapan, kriteria penerimaan, dan skenario uji |
| [Catatan keputusan](docs/05-decisions.md) | Keputusan disepakati, usulan, dan pertanyaan terbuka |

## Cara membaca status

**Disepakati** berarti sudah dinyatakan atau disetujui pengguna. **Usulan** berarti desain awal yang masih bisa direvisi. **Perlu validasi** berarti kelayakan teknis belum terbukti. Target dukungan bukan klaim fitur sudah berjalan.

## Tahap sekarang

Dokumentasi → review mockup → persetujuan arah UI → prototipe integrasi Chrome → UI native → adapter pemutar desktop → pengujian harian.

Mockup menggunakan data fiktif dan hanya mensimulasikan interaksi. Mockup bukan implementasi aplikasi berbasis web dan tidak membuktikan sinkronisasi musik sesungguhnya. Belum ada perintah build/run untuk aplikasi.
