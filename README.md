# Notch Box Mac

Aplikasi musik macOS pribadi: kontrol pemutar dan lirik tersinkron dalam panel native bergaya Dynamic Island.

**Status:** prototipe native lokal v0.2.5, 17 September 2026. Antarmuka tersedia dalam English, Bahasa Indonesia, dan 日本語: default mengikuti bahasa sistem yang didukung (fallback English) dan dapat diganti langsung di Setup. Transisi island kini mengunci tepi atas, pergantian lagu tidak auto-expand, status lirik kosong hanya ada di Setup dengan notifikasi miss 3 detik di island. Spectrum dekoratif dan preferensi Jepang pada timestamp ganda tersedia. Build, fixture, cache アイドル, serta render native diuji lokal; pengalaman Chrome/hover nyata tetap perlu uji pengguna.

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
| [Pengembangan dan pemasangan](docs/06-development.md) | Build aplikasi, pemasangan Chrome, pemakaian, batasan, dan uninstall |

## Cara membaca status

**Disepakati** berarti sudah dinyatakan atau disetujui pengguna. **Usulan** berarti desain awal yang masih bisa direvisi. **Perlu validasi** berarti kelayakan teknis belum terbukti. Target dukungan bukan klaim fitur sudah berjalan.

## Tahap sekarang

Dokumentasi → review mockup → persetujuan arah UI → prototipe integrasi Chrome → UI native → adapter pemutar desktop → pengujian harian.

Mockup menggunakan data fiktif dan hanya mensimulasikan interaksi. Implementasi aplikasi sekarang menggunakan SwiftUI/AppKit, bukan tampilan web. Mode demo native juga tidak memutar audio.

## Mulai lokal

**Update v0.2.5:** Setup → **Bahasa** memilih Ikuti sistem / English / Bahasa Indonesia / 日本語 tanpa restart. Bahasa sistem Mac ini saat ini diawali English, sehingga mode Ikuti sistem menampilkan English. Judul lagu, lirik, dan caption tidak diterjemahkan. Extension naik ke v0.2.5 agar popup mengikuti bahasa app; reload extension sekali. Dokumentasi proyek tetap berbahasa Indonesia.

**Update v0.2.4:** transisi tumbuh ke samping/bawah tanpa menggeser tepi atas. Spectrum dekoratif mereda saat pause/stop; tidak ada capture audio. Setup → Lirik menyediakan toggle **Utamakan Jepang pada timestamp ganda**, tanpa mengubah LRC mentah/cache. Baris bahasa lain pada timestamp berbeda tetap utuh; matikan toggle untuk semua varian simultan. Saat rilis v0.2.4, extension tetap v0.2.3; versi terbaru kini v0.2.5 dan perlu reload sekali seperti catatan di atas.

```sh
bash scripts/build-app.sh
open "build/Notch Box.app"
```

Gunakan **Setup → Demo lokal** untuk mencoba panel tanpa extension. Untuk musik nyata, ikuti [panduan pemasangan Chrome](docs/06-development.md). Default mengikuti pemutar aktif dan mencari lirik otomatis; pemilihan sumber manual tetap hanya di Setup. Lirik otomatis disimpan di cache lokal. Impor LRC adalah cadangan, bukan keharusan setiap lagu.

**Belum tersedia:** Apple Music/Spotify desktop, launch at login, dan distribusi ter-notarisasi. Ketersediaan/timing lirik bergantung pada kecocokan rekaman dan data penyedia, bukan jaminan setiap lagu. Jangan menganggap tiga sumber sudah didukung penuh hanya karena tercantum sebagai target produk.
