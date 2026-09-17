const statusLabel = document.getElementById("status");
const sourceLabel = document.getElementById("sources");

async function refresh() {
  try {
    const status = await chrome.runtime.sendMessage({ kind: "status" });
    statusLabel.textContent = status?.connected ? "Terhubung ke Notch Box" : status?.error || "Menyambungkan otomatis…";
    sourceLabel.textContent = status?.sources ? status.sources + " tab pemutar terdeteksi." : "Putar YouTube atau YouTube Music pada profil Chrome ini.";
  } catch { statusLabel.textContent = "Extension berubah. Tutup lalu buka kembali panel ini."; }
}

for (const kind of ["openSetup", "reconnect"]) {
  document.getElementById(kind === "openSetup" ? "setup" : "reconnect").addEventListener("click", async () => {
    try {
      await chrome.runtime.sendMessage({ kind });
      statusLabel.textContent = kind === "openSetup" ? "Membuka Setup…" : "Mencoba menyambungkan…";
    } catch { statusLabel.textContent = "Tidak dapat mengirim perintah. Buka ulang extension."; }
  });
}
refresh();
setInterval(refresh, 1000);
