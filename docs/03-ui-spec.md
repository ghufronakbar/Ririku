# Spesifikasi UI dan motion

## Setup Koneksi Chrome v0.3.0

Section **Koneksi Chrome** berada setelah Bahasa dan berisi empat langkah bernomor dengan ikon centang saat selesai: (1) **Daftarkan koneksi Chrome** dengan tombol Daftarkan/Daftarkan ulang, (2) **Salin folder extension** dengan tombol **Tampilkan di Finder**, (3) **Muat extension di Chrome** berisi instruksi Developer mode/Load unpacked dan tombol **Salin alamat** `chrome://extensions`, serta (4) **Periksa koneksi** yang menampilkan versi extension terhubung atau peringatan versi berbeda. Status setiap langkah ditulis sebagai teks, tidak hanya warna ikon. Peringatan oranye muncul bila app berjalan dari lokasi sementara (belum dipindah ke Applications). Pesan hasil aksi terakhir tampil di bawah langkah. App tidak membuka Chrome atau halaman `chrome://` secara otomatis.

## UI v0.2.5

Section pertama Setup adalah **Bahasa**: pemilih **Bahasa antarmuka** dengan opsi **Ikuti sistem (nama bahasa efektif)**, English, Bahasa Indonesia, dan 日本語. Nama bahasa selalu ditulis dalam bahasanya sendiri. Perubahan langsung berlaku pada Setup, panel island, label aksesibilitas/tooltip, menu bar, judul jendela, serta popup extension yang terhubung. Keterangan di bawah pemilih menyatakan bahwa judul lagu, lirik, caption, dan pesan dari macOS/situs tetap dalam bahasa aslinya. Preferensi **Utamakan Jepang pada timestamp ganda** terpisah dari bahasa antarmuka. Dialog sistem seperti panel impor file mengikuti bahasa macOS.

## UI v0.2.4

Tepi atas dan tinggi header tetap; hanya sisi horizontal dan batas bawah yang bergerak. Tidak ada scale transform/implicit root animation. Ganti lagu tidak membuka panel otomatis. Tanpa konten lirik, island ringkas hanya header; loading/error/miss rinci hanya di Setup. Lookup miss mendapat notifikasi **Lirik belum ditemukan** selama 3 detik tanpa membuka kontrol.

Ikon kanan sekarang spectrum dekoratif lima bar, mereda menjadi datar saat pause/stop/buffering. Tooltip menyatakan bukan analisis audio. Preferensi **Utamakan Jepang pada timestamp ganda** berada di Setup → Lirik; penjelasannya menyebut pengecualian duet multilingual simultan dan cara melihat semua varian. Pengaturan 1/2/3 cue tetap berlaku setelah preferensi diterapkan.

## UI v0.2.3

- **Tampilkan lirik di island** berlaku pada ringkas dan terbuka, tidak mematikan pencarian provider.
- Jumlah baris LRC: 1 = aktif; 2 = aktif+berikutnya; 3 = sebelumnya+aktif+berikutnya. Baris yang tidak tersedia di awal/akhir kosong. Urutan parser/timestamp/bahasa tidak diubah.
- Caption hanya memiliki teks saat ini, sehingga jumlah baris membatasi pembungkusan teks, bukan mengarang cue sebelum/berikutnya. Plain text tetap tidak memiliki baris aktif tersinkron.
- Lebar ringkas 280–620 pt, terbuka 360–720 pt; ukuran efektif dibatasi notch fisik dan lebar layar. Tinggi otomatis mengikuti isi. Tombol reset mengembalikan 360/442 pt.
- Frame ease-in/ease-out 0,32 detik dan opacity SwiftUI menggantikan perpindahan konten mendadak; frame target sama tidak dianimasikan ulang. Reduce Motion/toggle nonaktif meniadakan transisi.
- Ikon waveform/pause tetap statis; animasi spectrum sengaja belum dibuat.

## Setup lirik v0.2.2

Pemilih tiga mode, toggle pencarian otomatis LRCLIB, offset per lagu ±60 detik dengan tombol presisi 0,1 detik/reset, serta disclosure **Cari dan pilih versi lirik** berada di Form Setup yang dapat di-scroll. Hasil menampilkan judul, artis, album/ID, durasi, selisih bertanda, dan status bertimestamp/teks/instrumental. Kandidat dengan selisih >3 detik diberi peringatan cek versi dan hanya dapat dipilih eksplisit. Mode caption menonaktifkan kontrol pencarian/impor/offset. Mode Music tanpa CC dapat memakai LRCLIB. Tidak ada pemilih tambahan di panel notch.

## Caption v0.2.1

Panel expanded memberi label **Caption video** dan hingga dua baris teks saat ini, tanpa prediksi baris sebelumnya/berikutnya. Setup menampilkan status caption aktif. Koreksi timing hanya berlaku untuk LRCLIB/LRC. Caption otomatis tidak dianggap hasil kurasi. Pemilih sumber tetap di Setup.

[Kembali ke indeks](../README.md)

**Status:** usulan untuk review mockup. Angka ukuran dan durasi di bawah adalah titik awal desain, bukan spesifikasi hardware atau hasil pengukuran.

**Keputusan 17 September 2026:** visual dapat disesuaikan melalui jendela Setup terpisah. Pemilihan sumber hanya berada di jendela tersebut, bukan pop-up notch.

**Prototipe native:** panel nonactivating, hover expand/collapse, gear/menu bar menuju satu Setup, ukuran/aksen/animasi, lirik, offset, dan demo lokal telah dibuat. V0.2 menambahkan thumbnail nyata, sumber otomatis, status pencarian lirik, serta popup status extension. Fullscreen, VoiceOver, fokus lintas aplikasi, dan multi-monitor belum lulus pengujian harian. Pop-up otomatis saat ganti lagu dihapus pada v0.2.4; transisi frame kini 0,32 detik smoothstep dengan tepi atas tetap, bukan spring. Tabel dan angka di bawah mencatat usulan awal beserta implementasi sekarang; bagian versi di atas lebih rinci.

## 1. Arah visual

Hitam menyatu dengan notch, tipografi sistem, artwork sebagai satu aksen warna, sudut membulat, serta hierarki lirik yang jelas. Hindari glow berlebihan, kartu bertumpuk, dan indikator yang terus bergerak tanpa informasi.

Hardware notch adalah area terhalang: tidak boleh memuat teks/kontrol penting. Posisi dan ukuran produksi harus mengikuti geometri layar, bukan ukuran notch hard-coded. Mockup hanya ilustrasi proporsi.

## 2. State panel

| State | Isi | Interaksi |
| --- | --- | --- |
| Idle | Menyatu dengan notch, tidak ada data lagu lama | Buka menu/panel dengan klik |
| Compact | Artwork kiri, area notch kosong, spectrum dekoratif kanan | Hover/klik membuka panel |
| Lyrics | Compact + 1/2/3 baris lirik di bawah notch sesuai Setup; dapat disembunyikan | Hover/klik membuka panel |
| Expanded | Metadata, indikator sumber read-only, lirik 1/2/3 baris bila ada, progress, kontrol | Kontrol musik, seek, tombol Setup |
| Track change | Sejak v0.2.4 tidak ada pop-up/auto-expand; island ringkas langsung memperbarui artwork dan lirik | Hover/klik/menu tetap membuka panel |
| Unavailable | Island hanya header; notifikasi **Lirik belum ditemukan** 3 detik, sekali per lagu per sesi dan tidak untuk kegagalan jaringan. Status rinci ada di Setup | Kontrol tetap tersedia jika sumber terhubung |
| Disconnected | Status koneksi, tanpa playback palsu | Petunjuk reconnect yang relevan |

Playback state dan panel state terpisah: pause tidak otomatis menutup panel. Lirik panjang di mode ringkas memakai truncation, bukan marquee terus-menerus; teks lengkap tersedia saat expanded.

## 3. Layout usulan

- Compact/Lyrics: usulan awal 300–420 pt. Implementasi v0.2.3: slider 280–620 pt (default 360), minimal lebar notch + 100 pt; baris lirik berada di bawah batas notch.
- Expanded: usulan awal 420–460 pt. Implementasi v0.2.3: slider 360–720 pt (default 442), minimal lebar notch + 120 pt; tinggi mengikuti isi, metadata dan kontrol seluruhnya di bawah notch.
- Lebar efektif dibatasi lebar layar dikurangi 24 pt.
- Baris lirik aktif paling kontras; baris sebelum/sesudah lebih redup tetapi tetap terbaca.
- Sumber hanya ditampilkan sebagai indikator read-only di panel expanded. Pemilihnya berada di jendela Setup; jangan mengganti sumber tanpa indikasi.
- Tombol gear/Setup membuka jendela pengaturan terpisah, bukan memperpanjang pop-up musik.
- Kontrol yang tidak didukung dinonaktifkan dengan penjelasan, bukan tombol seolah berfungsi.
- Untuk layar sempit atau teks besar, prioritaskan isi dan kontrol daripada ukuran tetap.

## 4. Motion usulan

| Transisi | Usulan awal | Implementasi sekarang |
| --- | --- | --- |
| Hover masuk | Delay 150 ms | Sama |
| Expand/collapse | 250–350 ms, spring ringan | 320 ms smoothstep ease-in-out, tepi atas tetap, tanpa spring/overshoot |
| Hover keluar | Delay 350 ms | Sama; tidak menutup bila panel sedang menerima fokus |
| Pergantian baris | 160–220 ms, gerak pendek | Belum dianimasikan; baris dipilih ulang setiap 0,25 detik tanpa loncatan tinggi |
| Pergantian lagu | Pop-up sekitar 2 detik | Dihapus pada v0.2.4 sesuai permintaan pengguna; tidak ada auto-expand |

Panel tidak mengambil fokus keyboard saat terbuka lewat hover. Panel dipertahankan terbuka saat fokus ada di panel. Escape menutup panel. Reduce Motion atau toggle animasi nonaktif langsung memakai frame akhir dan spectrum statis. Tidak menggunakan equalizer dekoratif sebagai bukti audio benar-benar sedang keluar.

## 5. Pengaturan minimum

Disepakati: tombol Setup membuka jendela pengaturan terpisah yang memuat pemilih sumber dan penyesuaian visual. Panel notch tetap fokus pada musik dan lirik. Usulan akses tambahan dari menu bar agar Setup tetap tersedia saat idle.

Usulan isi jendela:

- Sumber: YouTube Music/YouTube di Chrome, Apple Music, Spotify; status koneksi dan pemilihan sesi jika lebih dari satu tersedia.
- Tampilan: ukuran panel, warna aksen, dan animasi. Detail opsi masih dapat direvisi; pilihan pengguna tidak boleh membuat konten menabrak hardware notch.
- Lirik: tampilkan/sembunyikan baris ringkas dan koreksi offset.
- Umum: launch at login; preferensi layar/fullscreen ditentukan setelah pengujian.

Usulan perilaku: perubahan visual langsung terlihat, preferensi disimpan lokal di aplikasi native, dan satu jendela Setup digunakan kembali. Jendela boleh menerima fokus ketika sengaja dibuka, berbeda dari panel musik yang dibuka lewat hover dan tidak boleh mengambil fokus. Menutup Setup tidak menghentikan musik atau menutup aplikasi. Reduce Motion sistem tetap mengungguli pilihan animasi aplikasi.

Perilaku v0.2: toggle **Otomatis ikuti pemutar aktif** aktif secara default; picker manual dinonaktifkan saat mode otomatis aktif. Toggle **Cari LRCLIB otomatis saat lagu berganti** aktif secara default, disertai status/provenance, **Kembali ke hasil otomatis** (melepas pilihan manual dan meminta ulang LRCLIB tanpa cache), dan **Impor LRC…**. Jika hanya plain text tersedia, panel memberi label tanpa timing dan scroll manual. Popup extension menyediakan status koneksi, jumlah tab, **Buka Setup aplikasi**, dan retry koneksi tanpa menaruh pemilih sumber di popup.

## 6. Aksesibilitas

- Klik dan keyboard tetap dapat membuka panel; hover bukan satu-satunya cara.
- Label VoiceOver untuk sumber, status, tombol, dan slider.
- Jangan mengumumkan timestamp tiap tick kepada screen reader.
- Kontras, fokus terlihat, target klik, teks panjang, dan Reduce Motion diuji.
- Jangan mengandalkan warna saja untuk status koneksi atau playback.

## 7. Batas mockup

Mockup mengeksplorasi compact, lyrics, expanded, track-change pop-up, serta jendela Setup terpisah. Pemilih sumber dipindahkan ke Setup; kontrol ukuran, aksen, dan animasi memperagakan penyesuaian visual. Metadata, artwork, dan lirik adalah contoh fiktif/orisinal. Kontrol hanya mengubah simulasi; tidak membaca atau mengontrol aplikasi pengguna. Pilihan mockup hanya bertahan selama preview terbuka, belum disimpan permanen. Detail pemasangan extension serta seluruh error state belum divisualisasikan.
