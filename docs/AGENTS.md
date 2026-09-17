# Panduan agen

Panduan ini berlaku untuk seluruh repository melalui symlink `AGENTS.md` di root. Edit sumber panduan di `docs/AGENTS.md`; pertahankan symlink relatif agar tetap bekerja setelah repository dipindahkan atau di-clone.

## Konteks wajib

Sebelum mengubah proyek, baca `README.md` dan dokumentasi berikut (path relatif terhadap root repository):

- `docs/01-product-brief.md`: tujuan, cakupan, dan batasan produk.
- `docs/02-architecture.md`: rancangan komponen dan integrasi pemutar.
- `docs/03-ui-spec.md`: perilaku panel, Setup, dan aksesibilitas.
- `docs/04-roadmap-and-testing.md`: tahapan implementasi dan validasi.
- `docs/05-decisions.md`: keputusan disepakati, usulan, dan pertanyaan terbuka.
- `docs/06-development.md`: build, pemasangan, perintah verifikasi, dan batasan prototipe.
- `docs/07-spectrum-and-lyrics-investigation.md`: analisis spectrum dan bahasa lirik.

## Aturan pengerjaan

- Bedakan keputusan disepakati, usulan, dan hal yang perlu validasi. Jangan menganggap rancangan atau mockup sebagai fitur yang sudah diimplementasikan.
- Pertahankan arah aplikasi macOS native; jangan mengganti UI utama dengan Electron atau WebView.
- Prioritaskan YouTube dan YouTube Music di Chrome sebelum adapter Apple Music dan Spotify desktop.
- Jaga pop-up notch tetap fokus pada musik dan lirik. Pemilih sumber serta penyesuaian visual berada di jendela Setup terpisah.
- Ikuti urutan roadmap dan persetujuan arah UI sebelum implementasi terkait.
- Hindari fitur di luar cakupan serta akses data atau izin yang tidak diperlukan.
- Saat keputusan berubah, perbarui dokumen terdampak dan catat tanggal serta alasan di `docs/05-decisions.md`.
- Gunakan bahasa Indonesia untuk dokumentasi, mengikuti gaya dokumen yang sudah ada.

## Validasi

- Gunakan kriteria dan skenario di `docs/04-roadmap-and-testing.md` sesuai perubahan.
- Jangan mengklaim build, pengujian, integrasi, atau efisiensi berhasil tanpa bukti. Laporkan apa yang dijalankan dan keterbatasannya.
- Untuk perubahan kode, jalankan perintah verifikasi rutin yang relevan di `docs/06-development.md` bagian 6, termasuk `scripts/check-localization.py` bila teks UI berubah. Belum ada suite test permanen; harness/fixture sementara harus dilaporkan sebagai bukti terbatas.
- Untuk perubahan dokumentasi, periksa konsistensi antar-dokumen, kesesuaian klaim dengan kode, dan tautan relatif. Saat menambah catatan versi, revisi juga bagian isi yang menjadi usang.
