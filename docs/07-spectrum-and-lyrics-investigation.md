# Investigasi spectrum dan bahasa lirik

17 September 2026. Ini penjelasan/usulan, bukan fitur yang telah diimplementasikan.

## 1. Spectrum: pilihan dan tradeoff

| Opsi | Kelebihan | Tradeoff |
| --- | --- | --- |
| Animasi dekoratif berdasarkan playing/paused | Tidak membutuhkan capture audio/izin tambahan; dapat mereda ke bar datar saat pause/stop | Bukan representasi frekuensi/beat suara; tetap bergerak pada bagian hening jika hanya mengikuti playing |
| Audio native melalui ScreenCaptureKit + analisis | Dapat mengikuti energi audio yang benar-benar ditangkap; arah native dan dapat dieksplorasi lintas aplikasi | Memerlukan alur izin capture macOS, pemilihan sumber, buffer/analisis audio, dan penanganan lifecycle. Capture aplikasi Chrome tidak otomatis mengidentifikasi satu tab musik; audio lain berisiko ikut masuk bila filter tidak tepat |
| Audio per tab Chrome melalui tabCapture | Lebih spesifik untuk tab yang dipilih | Izin extension dan aksi eksplisit pengguna diperlukan; lifecycle capture/offscreen menambah kompleksitas. Audio tab perlu dihubungkan kembali ke output agar tetap terdengar. Tidak mencakup Apple Music/Spotify desktop |

Untuk spectrum frekuensi sungguhan, pipeline perlu analisis frekuensi (misalnya FFT) dan smoothing band. RMS/level meter hanya merepresentasikan energi/volume, bukan spectrum lengkap. Penilaian bahwa jalur dekoratif lebih sederhana adalah pertimbangan arsitektur; belum ada pengukuran CPU, baterai, atau latency pada aplikasi ini. Jangan menjanjikan persentase resource tanpa benchmark.

Usulan: mulai dengan animasi dekoratif berlabel jujur, mereda ketika pause/stop/stale, menghormati Reduce Motion. Jika pengguna memilih real audio, spike terpisah dahulu untuk izin/source isolation dan overhead. Audio tidak perlu disimpan atau dikirim keluar; bila kelak dibuat, cukup hitung band lokal dan buang buffer. Tidak ada capture/animasi spectrum yang ditambahkan pada v0.2.3.

Referensi primer yang dibaca:
- [Chrome tabCapture: user invocation, permission, preserve system audio](https://developer.chrome.com/docs/extensions/reference/api/tabCapture)
- [Apple: Capturing screen content in macOS, izin Screen Recording pada sample serta pemrosesan audio](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos)

## 2. Mengapa アイドル menampilkan romaji?

Inspeksi cache aplikasi `Lyrics-v2` untuk query judul アイドル, artis YOASOBI, durasi 213 detik menemukan record LRCLIB **2116394** dengan 156 baris. Timestamp 00:29.26, 00:30.26, dan 00:31.61 masing-masing terdapat pada baris Jepang dan baris Latin/romaji. Jadi setidaknya kasus ini bukan ketiadaan teks Jepang dan bukan masalah font.

Parser sekarang mempertahankan urutan asal untuk timestamp sama, lalu pemilihan baris aktif mengambil baris terakhir yang waktunya ≤ posisi playback. Ketika romaji berada setelah Jepang pada timestamp sama, romaji menjadi aktif dan Jepang dapat muncul sebagai baris konteks. Aplikasi tidak menerjemahkan teks Jepang menjadi romaji; konten ganda memang ada di record dan belum ada kebijakan bahasa.

Perbaikan yang memungkinkan (belum diterapkan): kelompokkan cue bertimestamp sama, lalu berikan preferensi Asli/Jepang, Romaji, atau Keduanya. Untuk Jepang, utamakan kana/kanji yang sudah ada, dengan fallback bila tidak tersedia. Jangan hanya menghapus semua teks Latin karena kata bahasa Inggris dapat menjadi bagian lirik asli; hindari reverse-transliterasi romaji→kanji secara buta karena ambigu. Jika record hanya memiliki romaji, perlu memilih record Jepang lain, bukan menganggap aplikasi dapat memulihkan teks aslinya secara pasti.

Tidak ada perubahan parser, pemilihan bahasa, atau isi cache pada pekerjaan ini.
