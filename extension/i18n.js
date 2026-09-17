// Teks popup/status extension. Bahasa mengikuti aplikasi native bila terhubung, lalu bahasa UI Chrome, lalu English.
const NOTCHBOX_MESSAGES = {
  en: {
    checking: "Checking connection…",
    waitingPlayer: "Waiting for a Chrome player.",
    openSetup: "Open app Setup",
    reconnect: "Try connecting now",
    note: "Music source, automatic lyrics, and appearance are configured in the native Setup window.",
    connected: "Connected to Notch Box",
    connecting: "Connecting automatically…",
    sources: "Player tabs detected: {count}.",
    noSources: "Play YouTube or YouTube Music in this Chrome profile.",
    extensionChanged: "The extension changed. Close and reopen this panel.",
    openingSetup: "Opening Setup…",
    tryingConnect: "Trying to connect…",
    sendFailed: "Unable to send the command. Reopen the extension.",
    waitingNative: "Waiting to connect to the native app.",
    disconnected: "Connection lost. Reconnecting automatically.",
    titleConnected: "Notch Box: local bridge connected",
    titleDisconnected: "Bridge disconnected. Open Notch Box and check the native host installation."
  },
  id: {
    checking: "Memeriksa koneksi…",
    waitingPlayer: "Menunggu pemutar Chrome.",
    openSetup: "Buka Setup aplikasi",
    reconnect: "Coba sambungkan sekarang",
    note: "Sumber musik, lirik otomatis, dan tampilan diatur di jendela Setup native.",
    connected: "Terhubung ke Notch Box",
    connecting: "Menyambungkan otomatis…",
    sources: "{count} tab pemutar terdeteksi.",
    noSources: "Putar YouTube atau YouTube Music pada profil Chrome ini.",
    extensionChanged: "Extension berubah. Tutup lalu buka kembali panel ini.",
    openingSetup: "Membuka Setup…",
    tryingConnect: "Mencoba menyambungkan…",
    sendFailed: "Tidak dapat mengirim perintah. Buka ulang extension.",
    waitingNative: "Menunggu koneksi ke aplikasi native.",
    disconnected: "Koneksi terputus. Mencoba menyambung ulang otomatis.",
    titleConnected: "Notch Box: bridge lokal terhubung",
    titleDisconnected: "Bridge terputus. Buka Notch Box dan periksa pemasangan native host."
  },
  ja: {
    checking: "接続を確認中…",
    waitingPlayer: "Chrome のプレーヤーを待っています。",
    openSetup: "アプリのセットアップを開く",
    reconnect: "今すぐ接続を試す",
    note: "音楽ソース、歌詞の自動検索、外観はネイティブのセットアップウインドウで設定します。",
    connected: "Notch Box に接続しました",
    connecting: "自動で接続中…",
    sources: "プレーヤーのタブを {count} 個検出しました。",
    noSources: "この Chrome プロファイルで YouTube または YouTube Music を再生してください。",
    extensionChanged: "拡張機能が更新されました。このパネルを閉じて開き直してください。",
    openingSetup: "セットアップを開いています…",
    tryingConnect: "接続を試しています…",
    sendFailed: "コマンドを送信できません。拡張機能を開き直してください。",
    waitingNative: "ネイティブアプリへの接続を待っています。",
    disconnected: "接続が切れました。自動で再接続しています。",
    titleConnected: "Notch Box: ローカルブリッジに接続済み",
    titleDisconnected: "ブリッジが切断されました。Notch Box を開き、ネイティブホストのインストールを確認してください。"
  }
};

function notchboxLanguage(preferred) {
  if (Object.hasOwn(NOTCHBOX_MESSAGES, preferred)) return preferred;
  const browser = String(chrome.i18n?.getUILanguage?.() || "en").toLowerCase().split("-")[0];
  return Object.hasOwn(NOTCHBOX_MESSAGES, browser) ? browser : "en";
}

function notchboxText(language, key, values = {}) {
  const text = NOTCHBOX_MESSAGES[notchboxLanguage(language)][key] ?? NOTCHBOX_MESSAGES.en[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (_, name) => String(values[name] ?? ""));
}
