# Spesifikasi UI dan motion

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

**Prototipe native:** panel nonactivating, hover expand/collapse, pop-up track, gear/menu bar menuju satu Setup, ukuran/aksen/animasi, lirik, offset, dan demo lokal telah dibuat. V0.2 menambahkan thumbnail nyata, sumber otomatis, status pencarian lirik, serta popup status extension. Fullscreen, VoiceOver, fokus lintas aplikasi, dan multi-monitor belum lulus pengujian harian. Animasi awal memakai transisi frame AppKit 240 ms, belum motion spring final.

## 1. Arah visual

Hitam menyatu dengan notch, tipografi sistem, artwork sebagai satu aksen warna, sudut membulat, serta hierarki lirik yang jelas. Hindari glow berlebihan, kartu bertumpuk, dan indikator yang terus bergerak tanpa informasi.

Hardware notch adalah area terhalang: tidak boleh memuat teks/kontrol penting. Posisi dan ukuran produksi harus mengikuti geometri layar, bukan ukuran notch hard-coded. Mockup hanya ilustrasi proporsi.

## 2. State panel

| State | Isi | Interaksi |
| --- | --- | --- |
| Idle | Menyatu dengan notch, tidak ada data lagu lama | Buka menu/panel dengan klik |
| Compact | Artwork kiri, area notch kosong, indikator kanan | Hover/klik membuka panel |
| Lyrics | Compact + satu baris lirik di bawah notch | Hover/klik membuka panel |
| Expanded | Metadata, indikator sumber read-only, kontrol, progress, tiga baris lirik | Kontrol musik, seek, tombol Setup |
| Track change | Pop-up metadata singkat | Kembali ke state sebelumnya |
| Unavailable | Metadata + status lirik tidak tersedia | Kontrol tetap tersedia jika sumber terhubung |
| Disconnected | Status koneksi, tanpa playback palsu | Petunjuk reconnect yang relevan |

Playback state dan panel state terpisah: pause tidak otomatis menutup panel. Lirik panjang di mode ringkas memakai truncation, bukan marquee terus-menerus; teks lengkap tersedia saat expanded.

## 3. Layout usulan

- Compact: sekitar 300–340 pt lebar, menyesuaikan notch nyata.
- Lyrics: sekitar 360–420 pt lebar; baris berada di bawah batas notch.
- Expanded: sekitar 420–460 pt lebar, tinggi mengikuti isi; metadata dan kontrol seluruhnya di bawah notch.
- Baris lirik aktif paling kontras; baris sebelum/sesudah lebih redup tetapi tetap terbaca.
- Sumber hanya ditampilkan sebagai indikator read-only di panel expanded. Pemilihnya berada di jendela Setup; jangan mengganti sumber tanpa indikasi.
- Tombol gear/Setup membuka jendela pengaturan terpisah, bukan memperpanjang pop-up musik.
- Kontrol yang tidak didukung dinonaktifkan dengan penjelasan, bukan tombol seolah berfungsi.
- Untuk layar sempit atau teks besar, prioritaskan isi dan kontrol daripada ukuran tetap.

## 4. Motion usulan

| Transisi | Nilai awal | Perilaku |
| --- | --- | --- |
| Hover masuk | Delay 150 ms | Mengurangi pembukaan tidak sengaja |
| Expand/collapse | 250–350 ms | Spring ringan, overshoot minimal |
| Hover keluar | Delay 350 ms | Tidak menutup saat pindah menuju kontrol |
| Pergantian baris | 160–220 ms | Gerak pendek, tanpa loncatan layout |
| Pergantian lagu | Sekitar 2 detik | Satu pop-up, tidak berulang karena metadata diperbarui |

Pop-up tidak mengambil fokus keyboard. Panel dipertahankan terbuka saat fokus ada di kontrol atau sedang drag seek. Escape menutup panel. Reduce Motion meniadakan spring/pergeseran besar dan memakai transisi sederhana. Tidak menggunakan equalizer dekoratif sebagai bukti audio benar-benar sedang keluar.

## 5. Pengaturan minimum

Disepakati: tombol Setup membuka jendela pengaturan terpisah yang memuat pemilih sumber dan penyesuaian visual. Panel notch tetap fokus pada musik dan lirik. Usulan akses tambahan dari menu bar agar Setup tetap tersedia saat idle.

Usulan isi jendela:

- Sumber: YouTube Music/YouTube di Chrome, Apple Music, Spotify; status koneksi dan pemilihan sesi jika lebih dari satu tersedia.
- Tampilan: ukuran panel, warna aksen, dan animasi. Detail opsi masih dapat direvisi; pilihan pengguna tidak boleh membuat konten menabrak hardware notch.
- Lirik: tampilkan/sembunyikan baris ringkas dan koreksi offset.
- Umum: launch at login; preferensi layar/fullscreen ditentukan setelah pengujian.

Usulan perilaku: perubahan visual langsung terlihat, preferensi disimpan lokal di aplikasi native, dan satu jendela Setup digunakan kembali. Jendela boleh menerima fokus ketika sengaja dibuka, berbeda dari pop-up pergantian lagu yang tidak boleh mengambil fokus. Menutup Setup tidak menghentikan musik atau menutup aplikasi. Reduce Motion sistem tetap mengungguli pilihan animasi aplikasi.

Perilaku v0.2: toggle **Otomatis ikuti pemutar aktif** aktif secara default; picker manual dinonaktifkan saat mode otomatis aktif. Toggle **Cari lirik otomatis** aktif secara default, disertai status/provenance, **Cari ulang**, dan **Impor LRC cadangan…**. Jika hanya plain text tersedia, panel memberi label tanpa timing dan scroll manual. Popup extension menyediakan status koneksi, jumlah tab, **Buka Setup aplikasi**, dan retry koneksi tanpa menaruh pemilih sumber di popup.

## 6. Aksesibilitas

- Klik dan keyboard tetap dapat membuka panel; hover bukan satu-satunya cara.
- Label VoiceOver untuk sumber, status, tombol, dan slider.
- Jangan mengumumkan timestamp tiap tick kepada screen reader.
- Kontras, fokus terlihat, target klik, teks panjang, dan Reduce Motion diuji.
- Jangan mengandalkan warna saja untuk status koneksi atau playback.

## 7. Batas mockup

Mockup mengeksplorasi compact, lyrics, expanded, track-change pop-up, serta jendela Setup terpisah. Pemilih sumber dipindahkan ke Setup; kontrol ukuran, aksen, dan animasi memperagakan penyesuaian visual. Metadata, artwork, dan lirik adalah contoh fiktif/orisinal. Kontrol hanya mengubah simulasi; tidak membaca atau mengontrol aplikasi pengguna. Pilihan mockup hanya bertahan selama preview terbuka, belum disimpan permanen. Detail pemasangan extension serta seluruh error state belum divisualisasikan.
