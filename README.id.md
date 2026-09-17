# Ririku

**Lirik tersinkron dan kontrol musik di notch Mac Anda.**

[English](README.md) · Bahasa Indonesia · [日本語](README.ja.md)

> Terjemahan dari README English untuk v0.3.1. Bila ada perbedaan, versi English yang berlaku.

Ririku (リリク, dari kata "lyric") adalah aplikasi macOS gratis dan open source yang menampilkan lagu dari YouTube atau YouTube Music di Google Chrome tepat di bawah notch, lengkap dengan putar/jeda, lompat lagu, seek, dan lirik tersinkron per baris. Ririku adalah aplikasi native SwiftUI/AppKit dengan extension Chrome pendamping yang kecil, tanpa akun, dan tanpa telemetry.

> **Status:** prototipe awal (v0.3.1). Rilis pertama belum diterbitkan, jadi untuk saat ini Ririku perlu [di-build dari source](docs/development/README.md). Apple Music dan Spotify direncanakan tetapi belum didukung.

## Fitur

- **Panel notch:** artwork, spectrum dekoratif, dan hingga tiga baris lirik di island ringkas; arahkan pointer atau klik untuk membuka info lagu, bar posisi, dan kontrol.
- **Lirik tersinkron:** dicari otomatis dari [LRCLIB](https://lrclib.net) berdasarkan judul, artis, dan durasi, lalu disimpan di cache Mac Anda. Anda juga bisa memakai caption video, memilih versi lirik lain, mengatur timing per lagu, atau mengimpor berkas `.lrc` sendiri.
- **Ramah lirik Jepang:** bila berkas lirik berisi baris Jepang dan romaji dengan timestamp sama, Ririku dapat menampilkan baris Jepangnya saja.
- **Mengikuti pemutar aktif:** berpindah ke tab Chrome yang mulai memutar, atau kunci satu tab secara manual.
- **Dapat disesuaikan:** lebar island, jumlah baris lirik, warna aksen, animasi, dan dukungan Reduce Motion.
- **Bahasa antarmuka:** English, Bahasa Indonesia, dan 日本語, mengikuti bahasa macOS atau dipilih di Setup.

## Kebutuhan

- macOS 14 Sonoma atau lebih baru. Dikembangkan di Apple silicon; Mac Intel belum diuji.
- MacBook dengan notch disarankan. Layar lain memakai layar utama, dan ini belum diuji penuh.
- Google Chrome dengan YouTube (`www.youtube.com`) atau YouTube Music (`music.youtube.com`). Browser Chromium lain belum didukung.

## Instalasi

Ririku gratis dan tidak di-notarize Apple (notarisasi memerlukan akun developer berbayar), sehingga macOS meminta konfirmasi saat pertama dibuka. [Panduan pengguna](docs/user-guide.id.md#instalasi) menjelaskan setiap langkah secara rinci.

1. **Unduh app.** Unduh `Ririku.zip` dari [Releases](https://github.com/ghufronakbar/Ririku/releases) setelah tersedia, ekstrak, lalu pindahkan **Ririku.app** ke folder **Applications**. Sebelum rilis pertama, [build dari source](docs/development/README.md).
2. **Izinkan dibuka.** Buka Ririku. Jika macOS memblokirnya, buka **System Settings → Privacy & Security**, gulir ke bawah, lalu klik **Open Anyway**.
3. **Hubungkan Chrome.** Ririku membuka **Setup**. Di **Koneksi Chrome**, ikuti empat langkah: **Daftarkan**, **Tampilkan di Finder**, muat folder tersebut dari `chrome://extensions` dengan **Developer mode** dan **Load unpacked**, lalu refresh tab YouTube.

Putar lagu di Chrome dan arahkan pointer ke notch.

## Memakai Ririku

- **Membuka panel:** arahkan pointer ke notch, klik island, atau pilih **Buka panel musik** dari ikon gelombang suara di menu bar. Tekan Esc untuk menutup.
- **Setup:** klik gear di panel terbuka atau pilih **Setup…** dari ikon menu bar.
- **Lirik tidak pas?** Di **Setup → Lirik**, atur offset untuk lagu ini, atau gunakan **Cari dan pilih versi lirik** untuk memilih versi dengan durasi yang cocok dengan pemutar.
- **Tidak sedang memutar musik?** Aktifkan **Setup → Prototipe → Demo lokal** untuk mencoba panel tanpa Chrome.

Lihat [panduan pengguna](docs/user-guide.id.md) untuk semua pengaturan, cara mengatasi masalah, memperbarui, dan uninstall.

## Privasi

Ririku tidak memakai akun dan tidak mengirim analitik. Saat pencarian lirik otomatis aktif, judul, artis, dan durasi lagu dikirim ke LRCLIB. Thumbnail diambil dari server gambar YouTube/Google. Extension hanya berjalan di YouTube dan YouTube Music dan membaca pemutar di halaman; extension tidak membaca cookies atau riwayat browsing. Lihat [Privasi](docs/user-guide.id.md#privasi) di panduan pengguna.

Lirik berasal dari LRCLIB; ketersediaan dan timing-nya tidak dijamin. Ririku hanya menyimpan lirik di cache lokal dan tidak mengunduh audio maupun video.

## Kontribusi

Laporan bug, terjemahan, dan kode sangat diterima. Mulai dari [CONTRIBUTING.md](CONTRIBUTING.md) dan [dokumentasi developer](docs/development/README.md) (English). Laporkan masalah keamanan secara privat sesuai [SECURITY.md](SECURITY.md). Catatan rilis ada di [CHANGELOG.md](CHANGELOG.md).

## Kontak

Dikelola oleh **lanstheprodigy** — GitHub [@ghufronakbar](https://github.com/ghufronakbar), X [@lansProdigy](https://x.com/lansProdigy), Instagram [@lanstheprodigy](https://instagram.com/lanstheprodigy).

Gunakan [issues](https://github.com/ghufronakbar/Ririku/issues) untuk bug dan ide, serta [SECURITY.md](SECURITY.md) untuk laporan keamanan.

## Lisensi

[MIT](LICENSE) © 2026 lanstheprodigy.

Ririku tidak berafiliasi dengan atau didukung oleh Apple, Google, YouTube, maupun LRCLIB. Nama produk adalah merek dagang pemiliknya masing-masing.
