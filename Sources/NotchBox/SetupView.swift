import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Sumber musik") {
                Toggle("Otomatis ikuti pemutar aktif", isOn: $model.automaticSource).disabled(model.demo)
                Picker("Pemutar aktif", selection: $model.selectedSource) {
                    Text("Pilih tab pemutar").tag("")
                    if !model.selectedSource.isEmpty && model.sessions[model.selectedSource] == nil {
                        Text("Menunggu sumber tersambung kembali").tag(model.selectedSource)
                    }
                    ForEach(model.sessions.values.filter { $0.id != "demo:demo" }.sorted { $0.id < $1.id }, id: \.id) { entry in
                        Text("\(entry.snapshot.sourceLabel) · \(entry.snapshot.title)").tag(entry.id)
                    }
                }.disabled(model.demo || model.automaticSource)
                Text("Mode otomatis mengikuti tab yang mulai memutar dan memulihkan koneksi. Matikan untuk mengunci satu tab secara manual.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Apple Music dan Spotify: belum diimplementasikan.").font(.caption).foregroundStyle(.secondary)
                if let error = model.bridgeError { Text(error).foregroundStyle(.red) }
            }
            Section("Tampilan") {
                Picker("Ukuran panel", selection: $model.panelWidth) {
                    Text("Kecil").tag(398.0)
                    Text("Sedang").tag(442.0)
                    Text("Besar").tag(480.0)
                }
                Picker("Warna aksen", selection: $model.accentName) {
                    ForEach(["Peach", "Lavender", "Netral"], id: \.self) { Text($0) }
                }
                Toggle("Animasi panel", isOn: $model.animations)
                Toggle("Baris lirik saat ringkas", isOn: $model.showLyrics)
            }
            Section("Lirik") {
                Toggle("Cari lirik otomatis", isOn: $model.automaticLyrics)
                Text(model.trackKey.flatMap { model.lyricMessages[$0] } ?? "Lirik dicari saat lagu mulai diputar.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cari ulang") { model.retryMedia() }.disabled(model.trackKey == nil || !model.automaticLyrics)
                    Button("Impor LRC cadangan…") { model.importLyrics() }.disabled(model.trackKey == nil)
                    Text(model.trackKey.flatMap { model.lyricNames[$0] } ?? "Belum ada berkas").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack {
                    Text("Koreksi timing")
                    Slider(value: $model.lyricOffset, in: -10...10, step: 0.1)
                    Text(String(format: "%+.1f s", model.lyricOffset)).monospacedDigit().frame(width: 60)
                }
                Text("Lirik otomatis dari LRCLIB dicocokkan menurut judul, artis, dan durasi, lalu disimpan di cache lokal. LRC manual hanya opsi cadangan. Nilai offset positif menunda lirik.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = model.commandError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
            Section("Prototipe") {
                Text("Notch Box 0.2.0 · Native macOS").font(.caption).foregroundStyle(.secondary)
                Toggle("Demo lokal (tanpa audio)", isOn: $model.demo)
                Text("Tanpa telemetry/cookies. Saat lirik otomatis aktif, metadata lagu dikirim ke LRCLIB. Thumbnail diambil dari server gambar YouTube/Google.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 700)
    }
}
