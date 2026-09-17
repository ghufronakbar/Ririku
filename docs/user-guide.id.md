# Panduan pengguna Ririku

[English](user-guide.md) · Bahasa Indonesia · [日本語](user-guide.ja.md)

> Terjemahan dari panduan English untuk Ririku v0.3.0. Bila ada perbedaan, versi English yang berlaku.

Panduan ini untuk siapa pun yang ingin memakai Ririku, tanpa perlu kemampuan pemrograman. Nama tombol ditulis sesuai antarmuka berbahasa Indonesia. Tombol macOS dan Chrome ditulis dalam English; di komputer Anda namanya mengikuti bahasa sistem atau Chrome.

- [Sebelum mulai](#sebelum-mulai)
- [Instalasi](#instalasi)
- [Memakai panel](#memakai-panel)
- [Setup](#setup)
- [Mendapatkan lirik yang lebih baik](#mendapatkan-lirik-yang-lebih-baik)
- [Memperbarui](#memperbarui)
- [Mengatasi masalah](#mengatasi-masalah)
- [Uninstall](#uninstall)
- [Privasi](#privasi)
- [Keterbatasan](#keterbatasan)

## Sebelum mulai

Yang dibutuhkan:

- Mac dengan **macOS 14 Sonoma atau lebih baru**. Ririku dikembangkan di Apple silicon; Mac Intel belum diuji.
- Idealnya MacBook dengan **notch**. Di layar lain panel muncul di bagian atas layar utama, dan ini belum diuji penuh.
- **Google Chrome** yang memutar musik di **YouTube** atau **YouTube Music**. Browser dan aplikasi lain (Safari, Brave, Apple Music, Spotify) belum didukung.

## Instalasi

### 1. Unduh Ririku

Unduh `Ririku.zip` dari [halaman Releases](https://github.com/ghufronakbar/Ririku/releases), lalu klik dua kali untuk mengekstraknya. Rilis pertama belum diterbitkan; sampai saat itu, Ririku hanya bisa [di-build dari source](development/README.md).

Pindahkan **Ririku.app** ke folder **Applications** **sebelum membukanya**. Jika dibuka langsung dari Downloads, macOS menjalankannya dari lokasi sementara dan Ririku tidak dapat terhubung ke Chrome.

### 2. Membuka Ririku pertama kali

Ririku gratis dan tidak di-notarize oleh Apple, karena notarisasi memerlukan akun developer Apple berbayar. Karena itu macOS memblokir peluncuran pertama. Kalimat persisnya berbeda antarversi macOS.

**macOS 15 Sequoia dan lebih baru**

1. Klik dua kali **Ririku** di Applications. macOS menyatakan tidak dapat memverifikasi app. Klik **Done** (jangan pindahkan ke Trash).
2. Buka **System Settings → Privacy & Security**, lalu gulir ke bagian **Security**.
3. Di samping pesan bahwa Ririku diblokir, klik **Open Anyway**, konfirmasi dengan kata sandi atau Touch ID, lalu klik **Open**.

**macOS 14 Sonoma**

1. Di Applications, Control-klik (atau klik kanan) **Ririku**, lalu pilih **Open**.
2. Klik **Open** pada dialog.

Langkah ini cukup sekali untuk setiap versi yang diunduh.

> **Lanjutan:** jika Anda memercayai unduhannya, Anda juga bisa menjalankan `xattr -dr com.apple.quarantine /Applications/Ririku.app` di Terminal.

Ririku tidak memiliki ikon Dock. App berada di menu bar sebagai ikon **gelombang suara**, dan jendela **Setup** terbuka saat pertama kali dijalankan.

### 3. Menghubungkan Chrome

Ririku membaca pemutar YouTube di Chrome melalui extension pendamping kecil. Di **Setup → Koneksi Chrome**, ikuti empat langkah berikut sekali saja. Setiap langkah menampilkan tanda centang hijau setelah selesai.

1. **Daftarkan koneksi Chrome** → klik **Daftarkan**. Ririku mengizinkan Chrome berkomunikasi dengan salinan app ini.
2. **Salin folder extension** → klik **Tampilkan di Finder**. Ririku menyalin extension ke `~/Library/Application Support/Ririku/Chrome Extension` dan menampilkannya di Finder.
3. **Muat extension di Chrome** → klik **Salin alamat**, tempel `chrome://extensions` di address bar Chrome, lalu tekan Return. Kemudian:
   - Aktifkan **Developer mode** (pojok kanan atas).
   - Klik **Load unpacked** dan pilih folder **Chrome Extension** dari langkah 2.
4. **Periksa koneksi** → refresh tab YouTube atau YouTube Music yang sudah terbuka. Langkah ini menjadi hijau dan menampilkan versi extension.

Putar sesuatu di Chrome, lalu arahkan pointer ke notch.

Biarkan **Developer mode** tetap aktif; Chrome memerlukannya untuk extension yang tidak berasal dari Chrome Web Store.

## Memakai panel

- **Island ringkas:** saat musik diputar, notch menampilkan artwork di kiri dan spectrum dekoratif di kanan. Baris lirik muncul di bawahnya bila lirik tersedia. Spectrum hanya animasi, mereda saat dijeda, dan tidak menganalisis audio.
- **Membuka:** arahkan pointer ke notch atau klik island. Bisa juga pilih **Buka panel musik** dari ikon menu bar.
- **Kontrol:** judul, artis, dan sumber; tombol gear membuka **Setup**; bar posisi; serta tombol sebelumnya, putar/jeda, dan berikutnya. Tombol yang tidak disediakan situs dinonaktifkan. Siaran langsung menampilkan **LIVE** dan tidak dapat di-seek.
- **Menutup:** jauhkan pointer atau tekan **Esc**.
- **Iklan:** saat YouTube menampilkan iklan, kontrol dinonaktifkan dan lirik dijeda.
- **Tanpa lirik:** island tetap ringkas dan sebentar menampilkan **Lirik belum ditemukan**. Detailnya ada di **Setup → Lirik**.

Pilih **Keluar Ririku** dari ikon menu bar untuk keluar.

## Setup

Buka Setup dari tombol gear di panel terbuka atau **Setup…** di ikon menu bar. Perubahan langsung berlaku.

### Bahasa

**Bahasa antarmuka:** **Ikuti sistem** (default), English, Bahasa Indonesia, atau 日本語. Ikuti sistem memakai bahasa pertama yang didukung dari **System Settings → General → Language & Region**, atau English bila tidak ada. Judul lagu, lirik, caption, serta pesan dari macOS atau situs tetap dalam bahasa aslinya.

### Koneksi Chrome

Empat langkah instalasi di atas. Kembali ke sini setelah memperbarui Ririku atau memindahkannya ke folder lain.

### Saat login

**Buka Ririku saat login** (nonaktif secara default): Ririku terbuka di latar belakang setelah Anda login, tanpa ikon Dock maupun jendela. macOS bisa meminta izin pada kali pertama; jika Setup menyatakan sedang menunggu persetujuan, klik **Buka pengaturan Login Items** lalu aktifkan Ririku di sana. Sakelar ini tidak tersedia selama Ririku berjalan dari lokasi sementara, jadi pindahkan dulu ke **Applications**. Anda juga bisa mematikannya di **System Settings → General → Login Items**.

### Sumber musik

- **Otomatis ikuti pemutar aktif** (aktif secara default): Ririku mengikuti tab Chrome yang mulai memutar.
- **Pemutar aktif:** matikan mode otomatis untuk mengunci satu tab. Ririku tersambung kembali ke tab yang sama setelah halaman di-refresh.

### Tampilan

- **Lebar island ringkas** (280–620 pt, default 360) dan **Lebar island terbuka** (360–720 pt, default 442). Panel tidak pernah lebih sempit dari notch. **Reset ukuran** mengembalikan default.
- **Warna aksen:** Peach, Lavender, atau Netral.
- **Transisi panel halus:** matikan agar ukuran panel berubah seketika. **Reduce Motion** macOS juga mematikan animasi dan spectrum.
- **Tampilkan lirik di island** dan **Jumlah baris lirik:** 1 (saat ini), 2 (saat ini + berikutnya), atau 3 (sebelum + saat ini + berikutnya).

### Lirik

- **Utamakan Jepang pada timestamp ganda** (aktif secara default): lihat [Lirik Jepang](#lirik-jepang).
- **Sumber lirik:**
  - **Otomatis · LRCLIB lalu caption:** lirik bertimestamp dari LRCLIB; bila tidak ditemukan dan caption video (CC) aktif, caption yang ditampilkan.
  - **LRCLIB / LRC saja:** tidak pernah menampilkan caption.
  - **Subtitle YouTube saja:** hanya menampilkan caption pemutar dan tidak menghubungi LRCLIB.
- **Cari LRCLIB otomatis saat lagu berganti** (aktif secara default).
- **Kembali ke hasil otomatis:** menghapus pilihan manual untuk lagu ini dan mencari ulang di LRCLIB.
- **Impor LRC…:** memakai berkas `.lrc` Anda (UTF-8, maksimal 1 MB) untuk lagu saat ini sampai Ririku ditutup.
- **Offset lagu ini** serta **Majukan/Tunda 0,1 dtk:** lihat [Memperbaiki timing](#memperbaiki-timing).
- **Cari dan pilih versi lirik:** lihat [Memilih versi lain](#memilih-versi-lain).

### Prototipe

**Demo lokal (tanpa audio)** menampilkan lagu contoh agar panel bisa dicoba tanpa Chrome. Matikan sebelum memakai musik sungguhan.

## Mendapatkan lirik yang lebih baik

Ririku mencari lirik di [LRCLIB](https://lrclib.net), database komunitas gratis, berdasarkan judul, artis, dan durasi lagu. Hasil hanya dipakai otomatis bila judul dan artis cocok serta selisih durasi paling banyak 3 detik. Lirik tidak dijamin tersedia untuk setiap lagu, dan timing bergantung pada rekaman yang dikirim kontributor.

### Memperbaiki timing

Jika semua baris lebih cepat atau lambat dengan selisih yang sama, gunakan **Offset lagu ini** di **Setup → Lirik**. Nilai positif menunda lirik; nilai negatif memajukannya. Offset disimpan per video, sehingga berlaku lagi saat lagu diputar berikutnya. Offset tidak berlaku untuk caption.

### Memilih versi lain

Jika lirik makin bergeser, berasal dari versi lain, atau tidak ditemukan, buka **Cari dan pilih versi lirik**. Ketik judul, artis, atau judul alternatif (misalnya judul Jepang atau English), lalu klik **Cari**. Hasil diurutkan menurut kedekatan durasi dengan pemutar. Selisih lebih dari 3 detik ditandai **cek versi** dan sering berarti intro, live, atau cover yang berbeda. Klik **Pakai** untuk memakai hasil. Pilihan berlaku sampai Ririku ditutup.

### Caption

Jika YouTube menyediakan caption, aktifkan **CC** di pemutar. Ririku dapat menampilkannya saat lirik bertimestamp tidak tersedia, atau selalu dengan **Subtitle YouTube saja**. Subtitle yang menyatu dengan gambar video tidak dapat dibaca.

### Lirik Jepang

Sebagian berkas LRCLIB berisi baris Jepang yang diikuti baris romaji dengan timestamp sama. Dengan **Utamakan Jepang pada timestamp ganda** aktif, Ririku menyembunyikan baris berhuruf Latin saja bila ada baris Jepang dengan timestamp persis sama. Baris pada waktu lain dan baris campuran tetap ditampilkan, dan tidak ada yang dihapus dari berkas. Matikan untuk melihat semua baris, misalnya pada duet dua bahasa.

## Memperbarui

1. Keluar dari Ririku melalui ikon menu bar.
2. Ganti **Ririku.app** di Applications dengan versi baru, lalu buka. Mungkin perlu **Open Anyway** lagi.
3. Di **Setup → Koneksi Chrome**, bila ada langkah yang tidak lagi hijau, klik **Tampilkan di Finder** untuk menyalin extension baru, lalu klik tombol **reload** extension di `chrome://extensions` dan refresh tab YouTube.

Jika Ririku dipindahkan ke folder lain, klik **Daftarkan ulang** pada langkah 1.

## Mengatasi masalah

**Tombol Daftarkan nonaktif atau muncul peringatan oranye.** Ririku berjalan dari lokasi sementara. Keluar, pindahkan **Ririku.app** ke Applications, lalu buka lagi.

**Langkah 4 menampilkan "Belum terhubung".**
- Pastikan Ririku berjalan (ikon di menu bar) dan Chrome terbuka.
- Di `chrome://extensions`, pastikan **Developer mode** aktif dan **Ririku — Chrome Bridge** menyala.
- Refresh tab YouTube atau YouTube Music, lalu putar lagu.
- Klik ikon extension di Chrome untuk melihat statusnya; **Coba sambungkan sekarang** mencoba ulang, dan **Buka Setup aplikasi** membuka Ririku.
- Muat hanya satu salinan extension. Hapus duplikat di `chrome://extensions`.
- Hanya satu profil Chrome yang dapat terhubung pada satu waktu.

**Ikon extension menampilkan "!".** Extension tidak dapat menjangkau Ririku. Buka Ririku dan selesaikan **Setup → Koneksi Chrome**.

**"Terdaftar untuk salinan Ririku lain".** App dipindahkan atau salinan lain yang didaftarkan. Klik **Daftarkan ulang**.

**Extension usang.** Klik **Tampilkan di Finder** pada langkah 2, lalu tombol reload extension di `chrome://extensions`.

**Lirik belum ditemukan.** LRCLIB mungkin belum memiliki lagu tersebut, atau judul video tidak sama dengan nama lagu. Coba [Memilih versi lain](#memilih-versi-lain), caption, atau **Impor LRC…**.

**Lirik tampil sebagai teks biasa tanpa baris aktif.** Hanya lirik tanpa timing yang ditemukan. Coba versi lain.

**Tombol sebelumnya atau berikutnya nonaktif.** Halaman tidak menyediakan tombol tersebut, misalnya video tunggal tanpa playlist.

**"Aplikasi Ririku lain sudah berjalan".** Keluar dari salinan Ririku yang lain.

**YouTube berubah dan ada fitur yang berhenti bekerja.** Ririku membaca halaman YouTube yang dapat berubah sewaktu-waktu. Silakan [buat issue](https://github.com/ghufronakbar/Ririku/issues).

## Uninstall

1. Keluar dari Ririku melalui ikon menu bar.
2. Di `chrome://extensions`, hapus **Ririku — Chrome Bridge**.
3. Pindahkan **Ririku.app** ke Trash.
4. Opsional, hapus datanya. Di Finder pilih **Go → Go to Folder…** lalu hapus hanya item berikut:
   - `~/Library/Application Support/Ririku`
   - `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/io.github.lanstheprodigy.ririku.bridge.json`
   - `~/Library/Caches/io.github.lanstheprodigy.ririku`
   - `~/Library/Preferences/io.github.lanstheprodigy.ririku.plist` (atau jalankan `defaults delete io.github.lanstheprodigy.ririku` di Terminal)

## Privasi

- **Tanpa akun dan tanpa analitik.** Ririku tidak mengumpulkan data penggunaan.
- **LRCLIB:** saat pencarian otomatis aktif, judul, artis, dan durasi lagu dikirim ke `lrclib.net`. **Cari** mengirim teks yang Anda ketik. Mode **Subtitle YouTube saja** tidak menghubungi LRCLIB.
- **Artwork:** thumbnail diunduh dari server gambar YouTube/Google.
- **Extension Chrome:** hanya berjalan di `www.youtube.com` dan `music.youtube.com` dan hanya memakai izin `nativeMessaging`. Extension membaca status pemutar, judul, artis, alamat artwork, dan caption yang terlihat di halaman, lalu mengirimkannya hanya ke app Ririku di Mac Anda. Extension tidak membaca cookies, kata sandi, atau riwayat browsing.
- **Tersimpan di Mac Anda:** lirik yang ditemukan disimpan 30 hari (maksimal 300 berkas) dan hasil "tidak ditemukan" 30 menit di `~/Library/Caches/io.github.lanstheprodigy.ririku`. Pengaturan dan offset per lagu disimpan di preferensi Ririku; offset mencakup ID video lagu yang pernah Anda sesuaikan.

## Keterbatasan

- Hanya YouTube dan YouTube Music di Google Chrome; Apple Music, Spotify, Safari, dan browser lain belum didukung.
- Extension dipasang dengan **Load unpacked** dan tidak memperbarui dirinya sendiri.
- Tidak di-notarize Apple, sehingga peluncuran pertama perlu konfirmasi.
- Ketersediaan dan timing lirik bergantung pada LRCLIB.
- Perubahan halaman YouTube dapat mengganggu deteksi sampai Ririku diperbarui.
