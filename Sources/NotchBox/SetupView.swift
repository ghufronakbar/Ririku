import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel
    @State private var lyricSearchText = ""

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
                Picker("Sumber lirik", selection: $model.lyricSource) {
                    Text("Otomatis · LRCLIB lalu caption").tag("auto")
                    Text("LRCLIB / LRC saja").tag("lrclib")
                    Text("Subtitle YouTube saja").tag("caption")
                }
                Toggle("Cari LRCLIB otomatis saat lagu berganti", isOn: $model.automaticLyrics).disabled(model.lyricSource == "caption")
                Text(model.usesVideoCaption ? "Caption video aktif · mengikuti CC pemutar" : model.lyricSource == "caption" ? model.lyricStatus : (model.trackKey.flatMap { model.lyricMessages[$0] } ?? "Lirik dicari saat lagu mulai diputar.")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Kembali ke hasil otomatis") { model.retryMedia() }.disabled(model.trackKey == nil || !model.automaticLyrics || model.lyricSource == "caption")
                    Button("Impor LRC…") { model.importLyrics() }.disabled(model.trackKey == nil || model.lyricSource == "caption")
                }
                Text(model.trackKey.flatMap { model.lyricNames[$0] } ?? "Belum ada lirik terpilih").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text("Offset lagu ini")
                    Slider(value: Binding(get: { model.lyricOffset }, set: { model.lyricOffset = $0 }), in: -60...60, step: 0.1)
                    Text(String(format: "%+.1f s", model.lyricOffset)).monospacedDigit().frame(width: 60)
                    Button("Reset") { model.lyricOffset = 0 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                HStack {
                    Button("Majukan 0,1 dtk") { model.lyricOffset -= 0.1 }
                    Button("Tunda 0,1 dtk") { model.lyricOffset += 0.1 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                Text("Offset disimpan per video/lagu; positif menunda lirik, negatif memajukan. Tidak diterapkan pada CC. Durasi dipakai untuk memilih kandidat, bukan meregangkan timestamp secara otomatis.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Cari dan pilih versi lirik") {
                    HStack {
                        TextField("Judul, artis, atau alias lagu", text: $lyricSearchText)
                            .onSubmit { model.searchLyrics(lyricSearchText) }
                        Button(model.lyricSearchBusy ? "Mencari…" : "Cari") { model.searchLyrics(lyricSearchText) }
                            .disabled(model.lyricSearchBusy)
                    }
                    Text("Durasi pemutar: \(durationLabel(model.current?.snapshot.duration)) · hasil diurutkan menurut selisih durasi terkecil.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.lyricSearchStatus).font(.caption).foregroundStyle(.secondary)
                    ForEach(model.lyricCandidates, id: \.id) { record in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(record.trackName) — \(record.artistName)").font(.callout).lineLimit(2)
                                Text("\(record.albumName ?? "Album tidak diketahui") · #\(record.id)").font(.caption).foregroundStyle(.secondary)
                                Text("\(durationLabel(record.duration)) · \(differenceLabel(record.duration)) · \(record.instrumental ? "Instrumental" : record.hasValidSyncedLyrics ? "Bertimestamp" : "Teks saja")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Pakai") { model.selectLyrics(record) }
                                .disabled(!record.instrumental && !record.hasValidSyncedLyrics && (record.plainLyrics?.isEmpty ?? true))
                        }.padding(.vertical, 4)
                    }
                    Text("Periksa artis dan versi rekaman. Selisih besar dapat berarti intro, live, cover, atau lagu berbeda. Pilihan manual berlaku selama aplikasi terbuka.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.lyricSource == "caption" || model.trackKey == nil)
                if let error = model.commandError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
            Section("Prototipe") {
                Text("Notch Box 0.2.2 · Native macOS").font(.caption).foregroundStyle(.secondary)
                Toggle("Demo lokal (tanpa audio)", isOn: $model.demo)
                Text("Tanpa telemetry/cookies. Metadata lagu dikirim ke LRCLIB saat pencarian otomatis aktif; tombol Cari mengirim kata pencarian. Mode subtitle saja tidak mencari LRCLIB. Thumbnail diambil dari server gambar YouTube/Google.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 580, height: 700)
        .onAppear { resetSearch() }
        .onChange(of: model.trackKey) { _, _ in resetSearch() }
    }

    private func resetSearch() {
        model.cancelLyricSearch()
        guard let snapshot = model.current?.snapshot else { lyricSearchText = ""; return }
        lyricSearchText = snapshot.title
    }

    private func durationLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, duration < 86400 else { return "tidak diketahui" }
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func differenceLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, let playback = model.current?.snapshot.duration else { return "selisih tidak diketahui" }
        let difference = duration - playback
        return String(format: "selisih %+.1f dtk%@", difference, abs(difference) > 3 ? " · cek versi" : "")
    }
}
