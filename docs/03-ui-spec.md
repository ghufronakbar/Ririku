# Spesifikasi UI dan motion

[Kembali ke indeks](../README.md)

**Status:** usulan untuk review mockup. Angka ukuran dan durasi di bawah adalah titik awal desain, bukan spesifikasi hardware atau hasil pengukuran.

**Keputusan 17 September 2026:** visual dapat disesuaikan melalui jendela Setup terpisah. Pemilihan sumber hanya berada di jendela tersebut, bukan pop-up notch.

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

## 6. Aksesibilitas

- Klik dan keyboard tetap dapat membuka panel; hover bukan satu-satunya cara.
- Label VoiceOver untuk sumber, status, tombol, dan slider.
- Jangan mengumumkan timestamp tiap tick kepada screen reader.
- Kontras, fokus terlihat, target klik, teks panjang, dan Reduce Motion diuji.
- Jangan mengandalkan warna saja untuk status koneksi atau playback.

## 7. Batas mockup

Mockup mengeksplorasi compact, lyrics, expanded, track-change pop-up, serta jendela Setup terpisah. Pemilih sumber dipindahkan ke Setup; kontrol ukuran, aksen, dan animasi memperagakan penyesuaian visual. Metadata, artwork, dan lirik adalah contoh fiktif/orisinal. Kontrol hanya mengubah simulasi; tidak membaca atau mengontrol aplikasi pengguna. Pilihan mockup hanya bertahan selama preview terbuka, belum disimpan permanen. Detail pemasangan extension serta seluruh error state belum divisualisasikan.
