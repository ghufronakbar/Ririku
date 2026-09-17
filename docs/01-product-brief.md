# Product brief

[Kembali ke indeks](../README.md)

## 1. Masalah dan tujuan

Pengguna ingin aplikasi pribadi yang sederhana tanpa fitur inti terkunci premium. Aktivitas utama saat ini adalah mendengarkan YouTube/YouTube Music melalui Chrome. Aplikasi harus memudahkan kontrol musik dan membaca lirik tanpa terus membuka tab pemutar.

Prioritas: ketepatan sumber dan timing → kontrol yang dapat diandalkan → UI native yang menarik → efisiensi resource. Native tidak dianggap otomatis ringan; penggunaan resource perlu diukur.

## 2. Pengguna dan platform

- Pengguna awal: pemilik Mac ini, untuk penggunaan pribadi.
- Target prototipe: macOS 14+. Build awal pada macOS 15.7.2, arm64, Swift 6.1.2 melalui Command Line Tools. Model layar belum dicatat; geometri dibaca saat runtime. Dukungan Intel belum diuji.
- Target utama: layar dengan notch. Perilaku layar tanpa notch/monitor eksternal masih berupa usulan fallback.
- Distribusi awal: lokal. Distribusi App Store, signing, dan notarization belum diputuskan.

## 3. Cakupan

| Area | Kebutuhan | Status |
| --- | --- | --- |
| UI | Native, bergaya Dynamic Island, animasi pop-up | Disepakati |
| Browser | YouTube dan YouTube Music di Chrome | Disepakati, prioritas pertama |
| Desktop | Apple Music dan Spotify | Disepakati sebagai target, adapter perlu validasi |
| Kontrol | Play/pause, previous/next | Usulan detail kontrol; bergantung kemampuan sumber |
| Posisi | Progress dan seek bila didukung sumber | Usulan |
| Lirik | Sinkron per baris terhadap posisi playback | Target inti |
| Multi-sumber | Otomatis mengikuti pemutar aktif dan pulih setelah reconnect; opsi mengunci sumber manual di Setup | Disepakati setelah pengujian pengguna |
| Lirik otomatis | Mencari lirik per lagu tanpa impor rutin; LRC hanya cadangan | Disepakati |
| Artwork dan extension | Thumbnail nyata; klik extension menampilkan status dan akses Setup | Disepakati |
| Pengaturan | Tombol Setup membuka jendela terpisah; pilihan sumber dan visual adjustable | Disepakati; detail kontrol visual masih usulan |

Tidak termasuk: karaoke per kata, unduhan audio, bypass DRM/premium, file shelf, clipboard, kalender, cuaca, atau akun cloud aplikasi.

## 4. Skenario utama

1. Pengguna memutar lagu di YouTube Music; panel menunjukkan sumber dan lagu yang benar.
2. Pengguna pause atau seek dari browser maupun panel; baris lirik mengikuti posisi yang dilaporkan pemutar.
3. Pengguna membuka panel untuk kontrol, lalu kembali bekerja tanpa fokus keyboard diambil.
4. Pemutar baru mulai memainkan lagu; mode otomatis mengikutinya. Pengguna dapat mengunci sumber melalui jendela Setup, bukan pop-up notch.
5. Lirik tidak tersedia atau versi rekaman tidak cocok; UI menyatakan kondisinya tanpa menampilkan sinkronisasi palsu.
6. Koneksi extension terputus; UI tidak terus menampilkan playback lama sebagai data aktif.

## 5. Batasan lirik

Sinkronisasi adalah target kualitas yang harus diuji, bukan jaminan semua lagu memiliki lirik akurat. Video live, cover, remix, intro panjang, serta judul video yang tidak terstruktur berpotensi sulit dicocokkan.

Usulan fallback: lirik bertimestamp → lirik teks dengan label tidak sinkron → informasi lagu saja. Jangan menggulir lirik tanpa timestamp seolah tersinkron. Offset manual digunakan untuk selisih konstan, bukan memperbaiki versi lagu yang berbeda.

## 6. Privasi dan biaya

Tidak merancang subscription atau paywall aplikasi. Layanan eksternal tetap memiliki ketentuan, ketersediaan, dan kemungkinan biaya sendiri. Tidak mengasumsikan akses semua layanan bebas biaya selamanya.

Usulan kebijakan: tanpa telemetry default; cache lokal; izin browser hanya domain pemutar yang diperlukan; jangan membaca cookies, kredensial, atau riwayat browsing. Pencarian lirik daring akan mengirim metadata lagu ke penyedia, sehingga perlu dijelaskan kepada pengguna.
