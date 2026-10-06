# Panduan pengguna Ririku

[English](user-guide.md) · Bahasa Indonesia · [日本語](user-guide.ja.md)

> Terjemahan dari panduan English untuk Ririku v0.4.0. Bila ada perbedaan, versi English yang berlaku.

Panduan ini untuk siapa pun yang ingin memakai Ririku, tanpa perlu kemampuan pemrograman. Nama tombol ditulis sesuai antarmuka berbahasa Indonesia. Tombol macOS dan browser ditulis dalam English; di komputer Anda namanya mengikuti bahasa sistem atau browser.

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
- **Browser Chromium** — Chrome, Brave, Edge, Vivaldi, Opera, Chromium, atau Arc — yang memutar musik di **YouTube** atau **YouTube Music**. Baru Chrome yang diuji; yang lain memakai extension yang sama tetapi belum terverifikasi. Alternatifnya, gunakan Spotify desktop atau app Music (Apple Music) dengan izin Automation macOS. Safari dan Firefox belum didukung.

## Instalasi

### 1. Unduh Ririku

Unduh `Ririku-<versi>.zip` dari [halaman Releases](https://github.com/ghufronakbar/Ririku/releases), lalu klik dua kali untuk mengekstraknya. Anda juga bisa [build dari source](development/README.md).

Pindahkan **Ririku.app** ke folder **Applications** **sebelum membukanya**. Jika dibuka langsung dari Downloads, macOS menjalankannya dari lokasi sementara dan Ririku tidak dapat terhubung ke browser.

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

Secara default Ririku tidak memiliki ikon Dock dan berada di menu bar sebagai ikon **gelombang suara**; keduanya bisa diubah di **Setup → Umum**. Jendela **Setup** terbuka saat pertama kali dijalankan.

### 3. Menghubungkan browser

Ririku membaca pemutar YouTube di browser melalui extension pendamping kecil. Di **Setup → Koneksi browser**, ikuti empat langkah berikut sekali saja. Setiap langkah menampilkan tanda centang hijau setelah selesai.

1. **Daftarkan koneksi browser** → klik **Daftarkan**. Ririku mengizinkan setiap browser Chromium yang ditemukan di Mac Anda berkomunikasi dengan salinan app ini, dan menyebut namanya di bawah langkah tersebut.
2. **Salin folder extension** → klik **Tampilkan di Finder**. Ririku menyalin extension ke `~/Library/Application Support/Ririku/Chrome Extension` dan menampilkannya di Finder.
3. **Muat extension di browser** → klik **Salin alamat** (bila ada beberapa browser, pilih satu dari menu), tempel alamat itu di address bar browser tersebut, lalu tekan Return. Kemudian:
   - Aktifkan **Developer mode** (pojok kanan atas).
   - Klik **Load unpacked** dan pilih folder **Chrome Extension** dari langkah 2.
4. **Periksa koneksi** → refresh tab YouTube atau YouTube Music yang sudah terbuka. Langkah ini menjadi hijau dan menampilkan nama browser serta versi extension.

Putar sesuatu di browser tersebut, lalu arahkan pointer ke notch.

Biarkan **Developer mode** tetap aktif; browser memerlukannya untuk extension yang tidak berasal dari toko resminya. Nama folder extension tetap “Chrome Extension” di semua browser, karena extension-nya sama.

## Memakai panel

Artwork menggunakan thumbnail YouTube dari video yang sedang diputar, sehingga bisa berbeda dari sampul album di YouTube Music. Ini mencegah gambar lagu sebelumnya dari player bar tetap ditampilkan.

- **Island ringkas:** secara default island berukuran tepat seperti notch Mac Anda, jadi tersembunyi di balik housing kamera; perlebar di **Setup → Tampilan** untuk melihat artwork di kiri dan spectrum dekoratif di kanan. Baris lirik muncul di bawah notch saat musik diputar. Spectrum hanya animasi, mereda saat dijeda, dan tidak menganalisis audio.
- **Membuka:** arahkan pointer ke notch atau klik island. Bisa juga pilih **Buka panel musik** dari ikon menu bar, atau tekan shortcut yang Anda rekam di **Setup → Keyboard**.
- **Tab dan widget:** panel terbuka menampilkan satu halaman widget. **Beranda** dimulai dengan kontrol musik dan widget **Sistem** (penggunaan prosesor, memori, dan disk). Tombol gear di kanan notch membuka **Setup**; jika ada lebih dari satu halaman, ikon tab muncul di kiri notch. Panel terbuka di halaman yang terakhir Anda pakai. Atur halaman di **Setup → Tata letak**.
- **Timer dan pemberitahuan:** selama tidak ada musik yang diputar, timer yang berjalan menampilkan ikon dan waktunya di samping notch. Saat timer selesai atau mulai mengisi daya, pemberitahuan singkat muncul di bawah notch sekitar tiga detik; panel tetap tertutup.
- **Tray:** seret file ke notch untuk membuka panel di tab **Tray**, lalu lepas di sana. Klik file untuk membukanya, seret keluar ke app atau folder lain, atau Control-klik untuk **Tampilkan di Finder**, **Kirim dengan AirDrop**, dan **Hapus dari Tray**. Lepas file di kartu **AirDrop** untuk mengirimnya, atau klik kartu itu untuk mengirim seluruh isi Tray.
- **Clipboard:** jika riwayat clipboard aktif, tab **Clipboard** menampilkan yang Anda salin. Klik sebuah item untuk menaruhnya kembali di clipboard, lalu paste di tempat yang Anda mau.
- **Terjemahkan:** jika Terjemahkan aktif, tab **Terjemahkan** menerjemahkan teks yang Anda ketik atau tempel, 0,6 detik setelah Anda berhenti mengetik atau saat Anda menekan Return. Bahasa sumber dideteksi kecuali Anda memilihnya; tombol panah menukar bahasa. Klik tombol salin untuk menyalin terjemahan.
- **Kalender dan Kamera:** widget Kalender menampilkan acara hari ini yang belum selesai; klik untuk membuka app Calendar. Klik widget Kamera untuk memakai kamera sebagai cermin; kamera mati saat panel tertutup atau Anda berpindah tab.
- **Kontrol musik:** judul, artis, dan sumber; bar posisi; serta tombol sebelumnya, putar/jeda, dan berikutnya. Tombol yang tidak disediakan situs dinonaktifkan. Siaran langsung menampilkan **LIVE** dan tidak dapat di-seek.
- **Menutup:** jauhkan pointer, tekan **Esc**, atau tekan shortcut sekali lagi.
- **Saat dijeda:** artwork dan spectrum tetap tampil, sedangkan lirik keluar dari island sehingga island menyusut kembali seukuran notch. Panel terbuka tetap menampilkannya.
- **Iklan:** saat YouTube menampilkan iklan, kontrol dinonaktifkan dan lirik dijeda.
- **Tanpa lirik:** island tetap ringkas dan sebentar menampilkan **Lirik belum ditemukan**. Detailnya ada di **Setup → Lirik**.

Pilih **Keluar Ririku** dari ikon menu bar untuk keluar.

## Setup

Buka Setup dari tombol gear di panel terbuka atau **Setup…** di ikon menu bar. Pilih halaman di sidebar; selama belum ada browser atau pemutar desktop yang disiapkan, Setup terbuka di **Koneksi browser**. Perubahan langsung berlaku.

### Umum

**Saat login → Buka Ririku saat login** (nonaktif secara default): Ririku terbuka di latar belakang setelah Anda login, tanpa jendela. macOS bisa meminta izin pada kali pertama; jika Setup menyatakan sedang menunggu persetujuan, klik **Buka pengaturan Login Items** lalu aktifkan Ririku di sana. Sakelar ini tidak tersedia selama Ririku berjalan dari lokasi sementara, jadi pindahkan dulu ke **Applications**. Anda juga bisa mematikannya di **System Settings → General → Login Items**.

**Ikon:** **Tampilkan di Dock** (nonaktif secara default) dan **Tampilkan di menu bar** (aktif secara default). Jika ikon Dock aktif, mengkliknya membuka Setup, dan Ririku menampilkan menunya (Tentang, Setup, Edit, Jendela) di menu bar saat sedang di depan. Jika kedua ikon disembunyikan, buka Ririku lagi dari Finder, Launchpad, atau Spotlight, atau klik tombol gear di panel terbuka, untuk kembali ke Setup.

**Panel:**

- **Tampilkan panel di:** **Otomatis** (default) memakai layar dengan notch, atau layar utama bila tidak ada. Anda juga bisa memilih layar berdasarkan namanya; di layar tanpa notch, panel berada di tengah atas. Selama layar pilihan tidak terhubung, panel ditempatkan otomatis.
- **Jeda sebelum membuka** (0–1 dtk, default 0,15 dtk) dan **Jeda sebelum menutup** (0,1–2 dtk, default 0,35 dtk): berapa lama pointer berada di notch sebelum panel terbuka, dan berapa lama pointer menjauh sebelum panel tertutup. Mengklik island langsung membukanya.
- **Umpan balik haptik saat pointer mencapai notch** (nonaktif secara default): ketukan ringan saat pointer mencapai notch yang tertutup, meski hanya lewat menuju menu bar. Butuh trackpad Force Touch dengan **Force Click and haptic feedback** aktif di **System Settings → Trackpad** (Setup menyediakan **Buka pengaturan Trackpad**); bila opsi itu mati, macOS meredam haptik dari semua app. macOS juga hanya memainkannya selama jari menyentuh trackpad, jadi ketukan muncul saat pointer tiba, bukan saat panel terbuka.

### Tutorial

Tur singkat tentang panel dan Setup. Setiap langkah punya tombol yang membuka halaman yang dibahas.

### Bahasa

**Bahasa antarmuka:** **Ikuti sistem** (default), English, Bahasa Indonesia, atau 日本語. Ikuti sistem memakai bahasa pertama yang didukung dari **System Settings → General → Language & Region**, atau English bila tidak ada. Judul lagu, lirik, caption, serta pesan dari macOS atau situs tetap dalam bahasa aslinya.

### Keyboard

**Buka atau tutup panel:** mati sampai Anda merekam shortcut. Klik **Rekam shortcut** lalu tekan kombinasi dengan Command, Option, atau Control, misalnya ⌥⌘N; Esc membatalkan dan **Hapus** menghilangkannya. Shortcut bekerja dari app mana pun dan tidak butuh izin Accessibility. Jika macOS menolak kombinasi karena dipakai app lain, Setup memberi tahu; pilih kombinasi lain. Bila dibuka dengan shortcut, panel tetap terbuka sampai pointer menyentuhnya; tekan shortcut lagi atau Esc untuk menutup.

### Tata letak

Pratinjau langsung panel terbuka selalu ada di bagian atas; klik ikon tab di dalamnya untuk melihat halaman lain. Di bawahnya, setiap halaman memiliki:

- **Nama halaman** (kosong berarti Beranda, Halaman 2, dan seterusnya) dan **Ikon** untuk bar tab. Menu **…** di samping nama halaman memindahkan halaman ke kiri atau kanan atau menghapusnya; satu halaman selalu tersisa.
- Widget-widgetnya dari kiri ke kanan, masing-masing **Kecil** (satu unit) atau **Lebar** (dua unit). Menu **…** di samping widget memindahkannya ke kiri, ke kanan, atau ke halaman lain, atau menghapusnya.
- **Tambah widget** menampilkan widget yang belum ada di halaman mana pun; setiap widget hanya bisa berada di satu halaman.

Alat seperti Tray dan Clipboard memenuhi tabnya sendiri: bisa dipindah dan disembunyikan lewat **Tampilkan di panel**, tetapi tidak bisa dihapus. Tab Clipboard muncul selama riwayat clipboard aktif, dan tab Terjemahkan selama Terjemahkan aktif.

**Tambah halaman** menambah halaman hingga delapan, dan **Kembalikan ke tata letak bawaan** memulihkan Beranda dengan widget musik dan sistem, serta Tray; tab Clipboard dan Terjemahkan tetap ada selama aktif. Halaman yang butuh ruang lebih dari **Lebar island terbuka** akan terbuka lebih lebar, hingga selebar layar.

Widget dan pengaturannya dijelaskan di [Widget](#widget).

### Widget

Pengaturan untuk widget; letak tampilnya dipilih di **Setup → Tata letak**. Di panel, widget hanya menampilkan dan dioperasikan: memulai timer, menghitung, membuka app.

- **Musik** (lebar: lagu, lirik, bar posisi, dan kontrol; kecil: artwork, judul, dan kontrol) dan **Sistem** (penggunaan prosesor, memori, dan disk; versi lebar juga menampilkan totalnya). Widget Sistem hanya membaca nilai-nilai ini selama terlihat, setiap 2 detik, dan disk setiap 30 detik. Penggunaan prosesor butuh dua kali pembacaan, jadi saat widget muncul, nilai terakhir ditampilkan redup sebentar.
- **Jam:** waktu, mengikuti pengaturan 12 atau 24 jam Anda, dan tanggal.
- **Pomodoro:** sesi fokus dan istirahat dengan tombol mulai, reset, dan lompat. Atur durasi fokus, istirahat singkat, dan istirahat panjang, jumlah sesi fokus sebelum istirahat panjang, dan apakah tahap berikutnya mulai sendiri.
- **Hitung mundur:** atur durasinya di sini, atau dengan − dan + di panel sebelum dimulai. **Stopwatch:** mulai, jeda, dan reset.
- **Bunyikan suara saat timer selesai** (aktif secara default). Timer yang berjalan tetap berjalan saat panel tertutup atau Ririku ditutup, dan selama tidak ada musik yang diputar, timer tampil di samping notch.
- **Jaringan:** kecepatan unduh dan unggah Wi-Fi dan Ethernet, dibaca setiap 2 detik selama terlihat; versi lebar menambahkan grafik.
- **Baterai:** daya dan statusnya, dengan perkiraan waktu di versi lebar. **Tampilkan pemberitahuan saat mulai mengisi daya** (aktif secara default) berlaku selama widget Baterai ada di sebuah halaman.
- **Catatan:** catatan biasa yang Anda ketik di panel, tersimpan di Mac ini. **Hapus catatan…** mengosongkannya.
- **Penghitung:** judul dan angka yang bisa ditambah atau dikurangi. **Sisa hari:** judul dan tanggal; menghitung hari hingga tanggal itu, atau sejak tanggal itu. **Air minum:** jumlah gelas menuju target harian (default 8), mulai dari nol setiap hari.
- **App:** hingga 12 app yang ditambahkan lewat **Tambah app…**; klik di panel untuk membukanya.
- **Shortcut:** aktifkan hingga 12 shortcut dari app Shortcuts; panel hanya menjalankan shortcut itu, lewat perintah `shortcuts` milik Apple.
- **Bookmark:** hingga 12 alamat web (http atau https) dengan judul opsional; dibuka di browser default Anda.
- **Kalender:** acara hari ini yang belum selesai, atau acara besok jika hari ini sudah tidak ada lagi, dengan acara berjam sebelum acara sepanjang hari. Widget kecil menampilkan acara berikutnya, widget lebar hingga tiga. macOS meminta akses ke kalender Anda saat Anda menambahkan widget di **Setup → Tata letak**; Ririku hanya membacanya dan tidak pernah membuat, mengubah, atau menghapus acara. Matikan kalender yang tidak ingin Anda lihat; kalender baru otomatis ditampilkan.
- **Kamera:** cermin dari kamera Mac Anda. macOS meminta akses kamera saat Anda menambahkan widget. Kamera hanya menyala saat Anda mengklik widget di panel, tidak pernah di pratinjau Setup, dan mati saat panel tertutup atau Anda berpindah tab; lampu hijau kamera menyala selama kamera aktif.
- Jika Anda menolak akses ke kalender atau kamera, widget dan halaman ini menampilkan **Buka System Settings**, yang membuka **Privacy & Security** agar Anda bisa mengizinkannya; Ririku tidak meminta lagi dengan sendirinya. Ririku ditandatangani ad hoc, jadi macOS mungkin meminta izin ini lagi setelah update.
- **Tray:** jumlah file dan **Kosongkan Tray**. Tray menyimpan tautan ke setiap file, bukan salinannya, dan tidak pernah memindahkan atau menghapus file: menghapus file dari Tray hanya melupakannya, dan file yang Anda hapus akan hilang dari Tray. Maksimal 50 file.
- **Simpan riwayat clipboard** (nonaktif secara default): selama aktif, Ririku memeriksa clipboard dua kali per detik dan menyimpan 50 teks dan gambar terakhir yang Anda salin. Isi yang ditandai rahasia, sementara, atau dibuat otomatis oleh app, seperti kata sandi dari password manager, dan file yang disalin dilewati. Ririku tidak bisa melakukan paste untuk Anda, karena itu butuh izin Accessibility. **Hapus riwayat…** menghapus semua item, dan mematikan opsi ini juga menghapusnya.
- **Terjemahkan** (macOS 15 atau lebih baru, nonaktif secara default): **Tampilkan tab Terjemahkan** dan **Terjemahkan ke**. Terjemahan berjalan di Mac Anda dengan framework Translation milik Apple. Setiap bahasa diunduh sekali: buka **Bahasa di Mac ini**, klik **Unduh** di samping bahasa, lalu konfirmasi di jendela yang ditampilkan macOS. Panel hanya menerjemahkan bahasa yang sudah diunduh dan selain itu mengarahkan ke sini. Bahasa yang sudah diunduh bisa dihapus di **System Settings → General → Language & Region**.

### Tampilan

- **Lebar island ringkas** dan **Tinggi island ringkas** dimulai seukuran notch Mac Anda — itu nilai default sekaligus ukuran terkecilnya — dan dapat ditambah hingga 440 pt dan 40 pt. Setup menyebutkan ukuran notch Anda (misalnya 179 × 32 pt). Artwork dan spectrum menempel di sisi kiri dan kanan, jadi keduanya muncul dari balik housing kamera saat island diperlebar; sekitar 240 pt keduanya terlihat penuh.
- **Lebar island terbuka** (360–720 pt, default 442): panel terbuka minimal selebar ini. Halaman yang widgetnya butuh ruang lebih akan terbuka lebih lebar; Beranda bawaan terbuka sekitar 518 pt.
- **Kembalikan ke ukuran notch** mengembalikan ketiganya.
- **Warna aksen:** Otomatis — dari artwork, Peach, Lavender, atau Netral. Mode otomatis mengambil warna dominan thumbnail secara lokal, mencerahkannya untuk latar hitam, dan memakai Netral jika gambar belum tersedia atau hitam-putih. Hasil disimpan di memori, dengan transisi halus kecuali animasi dimatikan atau Reduce Motion aktif. Tidak ada analisis audio atau permintaan jaringan tambahan; pilihan manual sebelumnya tetap dipertahankan.
- **Transisi panel halus:** matikan agar ukuran panel berubah seketika. **Reduce Motion** macOS juga mematikan animasi dan spectrum.
- **Tampilkan lirik di island** dan **Jumlah baris lirik:** 1 (saat ini), 2 (saat ini + berikutnya), atau 3 (sebelum + saat ini + berikutnya). Bila sebuah lagu punya baris yang terlalu panjang untuk island, baris yang sedang berjalan memakai dua baris selama lagu itu, jadi tingginya tidak berubah-ubah; baris sebelum dan sesudahnya tetap satu baris dan diakhiri “…”. Jadi island yang sempit pun tetap menampilkan baris yang Anda baca secara utuh — perlebar island kalau ingin baris sekitarnya juga terlihat penuh.

### Koneksi browser

Empat langkah instalasi di atas. Kembali ke sini setelah memperbarui Ririku atau memindahkannya ke folder lain.

### Sumber musik

**Spotify desktop:** buka Spotify dan putar lagu, lalu aktifkan **Hubungkan Spotify desktop**. Setujui izin Automation macOS. Tidak perlu extension atau API key. Mode otomatis mengikuti pemutar yang mulai bermain; matikan untuk memilih Spotify secara manual. Pilih lirik Auto atau LRCLIB, bukan hanya subtitle. Jika izin ditolak, izinkan Ririku di **System Settings → Privacy & Security → Automation**, lalu klik **Sambungkan ulang Spotify**. Mematikan opsi ini menghentikan polling; pilihannya tersimpan saat restart. Artwork berasal dari `i.scdn.co`; metadata lagu dikirim ke LRCLIB jika lirik otomatis aktif. Playback dan izin masih perlu diuji langsung.

**Apple Music:** buka app Music dan putar lagu, lalu aktifkan **Hubungkan Apple Music** dan setujui izin Automation macOS. Berlaku untuk lagu di library dan streaming Apple Music; stasiun radio dan siaran langsung tanpa durasi tidak ditampilkan. Artwork dibaca secara lokal dari app Music, sehingga tidak ada server gambar yang dihubungi. Jika LRCLIB tidak menemukan lirik, Ririku menampilkan lirik yang tersimpan pada lagu di app Music (**Get Info → Lyrics**) sebagai teks biasa tanpa sinkronisasi. Biasanya ini berlaku untuk file milik Anda sendiri; lirik tersinkron Apple Music tidak tersedia untuk app lain. Pemilihan sumber, lirik, pemulihan izin (**Sambungkan ulang Apple Music**), dan pilihan yang tersimpan bekerja sama seperti Spotify. Playback dan izin masih perlu diuji langsung.

- **Otomatis ikuti pemutar aktif** (aktif secara default): Ririku mengikuti tab browser yang mulai memutar.
- **Pemutar aktif:** matikan mode otomatis untuk mengunci satu tab. Ririku tersambung kembali ke tab yang sama setelah halaman di-refresh.

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
- **Terjemahkan lirik** (macOS 15 atau lebih baru, nonaktif secara default) dan **Terjemahkan ke:** terjemahan setiap baris tersinkron muncul di bawah baris aktif di panel yang terbuka; island kecil tidak berubah. Seluruh lagu diterjemahkan di Mac Anda saat liriknya dimuat, baris yang sudah dalam bahasa tujuan dibiarkan, dan liriknya sendiri tidak pernah diubah. Baris di bawahnya menampilkan status lagu saat ini; jika bahasanya belum diunduh, klik **Unduh**. Lirik teks biasa dan caption tidak diterjemahkan.

### Prototipe

**Demo lokal (tanpa audio)** menampilkan lagu contoh dengan lirik tersinkron agar panel bisa dicoba tanpa browser. Matikan sebelum memakai musik sungguhan.

### Tentang

Versi, catatan privasi, dan tautan ke kode sumber, panduan ini dalam bahasa antarmuka Anda, dan halaman laporan masalah. Tautan dibuka di browser. Jika ikon Dock aktif, **Tentang Ririku** di menu app juga membuka halaman ini.

## Mendapatkan lirik yang lebih baik

Pencarian otomatis mengikuti pergantian lagu; saran judul dan artis di Setup ikut diperbarui. Error sementara LRCLIB 502/503/504 dicoba ulang secara terbatas, tetapi gangguan layanan yang berlanjut tetap dapat menghalangi lirik. Baris lirik bertimestamp bergerak ke atas jika animasi aktif; Reduce Motion menonaktifkannya. YouTube Music menggunakan waktu lagu yang terlihat, bukan durasi media kumulatif. Setelah memperbarui extension, reload extension dan refresh tab YouTube yang sudah terbuka sekali.

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
3. Di **Setup → Koneksi browser**, bila ada langkah yang tidak lagi hijau, klik **Tampilkan di Finder** untuk menyalin extension baru, lalu klik tombol **reload** extension di halaman extension browser dan refresh tab YouTube.

Jika Ririku dipindahkan ke folder lain, klik **Daftarkan ulang** pada langkah 1.

## Mengatasi masalah

**Tombol Daftarkan nonaktif atau muncul peringatan oranye.** Ririku berjalan dari lokasi sementara. Keluar, pindahkan **Ririku.app** ke Applications, lalu buka lagi.

**Langkah 4 menampilkan "Belum terhubung".**
- Pastikan Ririku berjalan (ikon di menu bar) dan browser terbuka.
- Di halaman extension browser, pastikan **Developer mode** aktif dan **Ririku — Browser Bridge** menyala.
- Refresh tab YouTube atau YouTube Music, lalu putar lagu.
- Klik ikon extension di browser untuk melihat statusnya; **Coba sambungkan sekarang** mencoba ulang, dan **Buka Setup aplikasi** membuka Ririku.
- Muat hanya satu salinan extension. Hapus duplikat di `chrome://extensions`.
- Hanya satu profil browser yang dapat terhubung pada satu waktu. Bila extension dimuat di dua browser, yang terhubung lebih dulu yang dipakai; tutup browser lainnya untuk berpindah.

**Ikon extension menampilkan "!".** Extension tidak dapat menjangkau Ririku. Buka Ririku dan selesaikan **Setup → Koneksi browser**.

**"Terdaftar untuk salinan Ririku lain".** App dipindahkan atau salinan lain yang didaftarkan. Klik **Daftarkan ulang**.

**Extension usang.** Klik **Tampilkan di Finder** pada langkah 2, lalu tombol reload extension di `chrome://extensions`.

**Lirik belum ditemukan.** LRCLIB mungkin belum memiliki lagu tersebut, atau judul video tidak sama dengan nama lagu. Coba [Memilih versi lain](#memilih-versi-lain), caption, atau **Impor LRC…**.

**Lirik tampil sebagai teks biasa tanpa baris aktif.** Hanya lirik tanpa timing yang ditemukan. Coba versi lain.

**Tombol sebelumnya atau berikutnya nonaktif.** Halaman tidak menyediakan tombol tersebut, misalnya video tunggal tanpa playlist.

**"Aplikasi Ririku lain sudah berjalan".** Keluar dari salinan Ririku yang lain.

**YouTube berubah dan ada fitur yang berhenti bekerja.** Ririku membaca halaman YouTube yang dapat berubah sewaktu-waktu. Silakan [buat issue](https://github.com/ghufronakbar/Ririku/issues).

## Uninstall

1. Keluar dari Ririku melalui ikon menu bar.
2. Di halaman extension browser, hapus **Ririku — Browser Bridge**.
3. Pindahkan **Ririku.app** ke Trash.
4. Opsional, hapus datanya. Di Finder pilih **Go → Go to Folder…** lalu hapus hanya item berikut:
   - `~/Library/Application Support/Ririku` (salinan extension browser dan riwayat clipboard)
   - `io.github.lanstheprodigy.ririku.bridge.json` di folder `NativeMessagingHosts` setiap browser yang didaftarkan, misalnya `~/Library/Application Support/Google/Chrome/NativeMessagingHosts`
   - `~/Library/Caches/io.github.lanstheprodigy.ririku`
   - `~/Library/Preferences/io.github.lanstheprodigy.ririku.plist` (atau jalankan `defaults delete io.github.lanstheprodigy.ririku` di Terminal)
5. Jika mau, hapus Ririku dari daftar di **System Settings → Privacy & Security** tempat Anda mengizinkannya: **Calendars**, **Camera**, dan **Automation**.

## Privasi

- **Tanpa akun dan tanpa analitik.** Ririku tidak mengumpulkan data penggunaan.
- **LRCLIB:** saat pencarian otomatis aktif, judul, artis, dan durasi lagu dikirim ke `lrclib.net`. **Cari** mengirim teks yang Anda ketik. Mode **Subtitle YouTube saja** tidak menghubungi LRCLIB.
- **Artwork:** thumbnail diunduh dari server gambar YouTube/Google atau `i.scdn.co` milik Spotify; artwork Apple Music dibaca secara lokal dari app Music. Automation Spotify dan Music membaca metadata secara lokal dan mengirim kontrol saat diminta.
- **Extension browser:** hanya berjalan di `www.youtube.com` dan `music.youtube.com` dan hanya memakai izin `nativeMessaging`. Extension membaca status pemutar, judul, artis, alamat artwork, dan caption yang terlihat di halaman, lalu mengirimkannya hanya ke app Ririku di Mac Anda. Extension tidak membaca cookies, kata sandi, atau riwayat browsing.
- **Tersimpan di Mac Anda:** lirik yang ditemukan disimpan 30 hari (maksimal 300 berkas) dan hasil "tidak ditemukan" 30 menit di `~/Library/Caches/io.github.lanstheprodigy.ririku`. Pengaturan dan offset per lagu disimpan di preferensi Ririku; offset mencakup ID video lagu yang pernah Anda sesuaikan.
- **Widget:** widget bekerja di Mac Anda dan tidak menambah tujuan jaringan. Widget Sistem dan Jaringan membaca penghitung penggunaan hanya selama terlihat, dan widget Baterai membaca sumber daya. Catatan, penghitung, air minum, timer, serta daftar app, shortcut, dan bookmark Anda disimpan di preferensi Ririku. Shortcut dijalankan lewat perintah `shortcuts` milik Apple, app dibuka oleh macOS, dan bookmark dibuka di browser default Anda.
- **Tray dan clipboard:** Tray menyimpan tautan ke file Anda di preferensi Ririku. Riwayat clipboard, jika aktif, disimpan di `~/Library/Application Support/Ririku/Clipboard`, hanya bisa dibaca oleh akun pengguna Anda, dan dihapus saat Anda mematikannya.
- **Terjemahan:** teks yang Anda terjemahkan dan lirik diterjemahkan di Mac Anda dengan framework Translation milik Apple dan tidak dikirim ke layanan terjemahan. macOS mengunduh bahasanya dari Apple satu kali. Teks dan terjemahannya hanya disimpan di memori.
- **Kalender dan kamera:** widget Kalender membaca acara di Mac Anda hanya selama terlihat dan tidak menyimpan satu pun; yang disimpan hanya daftar kalender yang Anda matikan. Gambar kamera hanya ditampilkan di panel: tidak pernah direkam, disimpan, atau dikirim.

## Keterbatasan

- YouTube dan YouTube Music di satu browser Chromium, serta Spotify desktop dan Apple Music yang diaktifkan di Setup. Podcast, file lokal, dan iklan Spotify, serta siaran radio Apple Music tanpa durasi, belum didukung sebagai lagu. Safari dan Firefox belum didukung.
- Baru Chrome yang terverifikasi. Brave, Edge, Vivaldi, Opera, Chromium, dan Arc memakai extension dan host yang sama, tetapi belum diuji; khususnya folder Arc masih perlu dipastikan.
- Extension dipasang dengan **Load unpacked** dan tidak memperbarui dirinya sendiri.
- Tidak di-notarize Apple, sehingga peluncuran pertama perlu konfirmasi.
- Ketersediaan dan timing lirik bergantung pada LRCLIB.
- Perubahan halaman YouTube dapat mengganggu deteksi sampai Ririku diperbarui.
- Terjemahkan dan terjemahan lirik butuh macOS 15 atau lebih baru. Belum dipastikan di semua sistem bahwa macOS menampilkan prompt unduhan bahasa dengan benar dari Setup.
