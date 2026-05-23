# Workstation Beads Kanban — macOS Client (SwiftUI)

Aplikasi desktop **Beads Kanban** native **macOS** yang dibangun menggunakan **Swift & SwiftUI**. Aplikasi ini berfungsi sebagai visualizer interaktif dan pusat kendali lokal untuk sistem issue tracker **Beads (`bd`)** yang didukung oleh Dolt database.

Aplikasi ini mengadopsi konsep **Craftboard Style Guide** (desain *dark mode* premium, aksen warna emas/gold hangat, font modern Syne & DM Sans, informasi padat, serta layout dinamis yang memikat).

---

## ✨ Fitur & Kapabilitas Saat Ini

Aplikasi telah melewati beberapa fase pengembangan utama:

*   **Fase 0: Beads CLI Contract Spike**
    *   Pemodelan `BeadIssue` yang toleran terhadap perbedaan struktur JSON (field opsional, decoding aman).
    *   Helper JSON decoder untuk perintah `bd list --json`, `bd ready --json`, dan `bd show <id> --json`.
    *   Unit testing lengkap untuk memvalidasi kontrak pertukaran data di `Tests/BeadsContractTests`.

*   **Fase 1: Project Folder & Workspace Detection**
    *   Integrasi folder picker native macOS (`NSOpenPanel`) untuk memilih folder proyek.
    *   Pendeteksian otomatis root folder berbasis keberadaan direktori `.git` dan `.beads`.
    *   Validasi kelengkapan lingkungan kerja (ketersediaan Git, inisialisasi `.beads`, keberadaan dokumen koordinasi `AGENTS.md`, serta instalasi CLI `bd`).

*   **Fase 2: Shell Command Runner & Debug History**
    *   Sistem eksekusi perintah shell lokal menggunakan `Process` Swift secara aman.
    *   Pengaturan batas waktu eksekusi (*timeout*) dan kemampuan pembatalan (*cancellation*) tugas asinkron agar antarmuka tidak membeku.
    *   Perekaman riwayat perintah shell (*command history metadata*) untuk membantu pelacakan masalah dan debugging performa.

*   **Estetika Premium (Craftboard Theme)**
    *   Background utama gelap charcoal (`#0F0F0F`) dengan pola grid titik-titik halus (*dot pattern*).
    *   Aksen emas hangat (`#ECC864`) untuk menyorot status aktif dan aksi utama.
    *   Sidebar lipat (*collapsible sidebar*), header dengan breadcrumb, papan Kanban horizontal, dan panel detail samping kanan (*Detail Drawer*).

---

## 📂 Struktur Direktori Proyek

```text
Workstation/
├── App/                      # Source code SwiftUI native views & ViewModels
│   ├── AppViewModel.swift    # Pengatur state utama aplikasi
│   ├── SettingsShellView.swift
│   └── ... (komponen SwiftUI)
├── Sources/                  # Core Business Logic (Swift Package)
│   ├── BeadsContract/        # Model data issue, representasi data, & decoder
│   └── BeadsWorkspace/       # Validasi workspace, folder picker, & Shell Runner
├── Tests/                    # Target Unit Testing
│   ├── BeadsContractTests/
│   └── BeadsWorkspaceTests/
├── Fixtures/                 # Sample file JSON dari output CLI bd untuk testing
├── references/               # Dokumentasi panduan visual (Style Guide)
├── project.yml               # Konfigurasi XcodeGen untuk membuat file project
├── Package.swift             # Defini Swift Package Manager untuk Core logic
├── GUIDE.md                  # Panduan kolaborasi kerja untuk developer & AI Agent
└── run-app                   # Script cepat utility untuk compile & run app
```

---

## 🚀 Panduan Membangun & Menjalankan Proyek (macOS)

### Prasyarat (Prerequisites)
Pastikan komputer macOS Anda sudah terinstall:
1.  **Xcode (versi 16 atau lebih baru)** untuk kompiler Swift 6 dan runtime SwiftUI.
2.  **XcodeGen**: Alat generator project Xcode dari `project.yml`.
    ```bash
    brew install xcodegen
    ```

---

### Cara Cepat (Utility Script)

Kami menyediakan shell script `./run-app` di root folder proyek untuk mempermudah alur kerja Anda:

*   **Menghasilkan project Xcode, meng-compile, dan menjalankan aplikasi**:
    ```bash
    ./run-app
    ```
*   **Melakukan kompilasi bersih (build) saja tanpa membuka aplikasi**:
    ```bash
    ./run-app build
    ```

---

### Perintah XcodeGen & Xcodebuild Manual

Jika ingin menjalankan alur pengembangan secara manual tanpa utility script:

1.  **Generate file `.xcodeproj` dari file `project.yml`**:
    ```bash
    xcodegen generate
    ```
2.  **Membangun Proyek menggunakan xcodebuild**:
    ```bash
    xcodebuild -project Workstation.xcodeproj -scheme Workstation -configuration Debug build
    ```
3.  **Membuka dan Menjalankan Aplikasi**:
    Aplikasi hasil build dapat ditemukan di folder produk Xcode Anda, atau buka file `.xcodeproj` yang dihasilkan menggunakan Xcode GUI dan tekan tombol **Run (Cmd + R)**.

---

### Menjalankan Unit Testing

Untuk memastikan semua decoder JSON, alur deteksi, dan runner perintah shell berjalan stabil tanpa regresi:

```bash
swift test
```

---

## 🤝 Aturan Kerja Kolaborasi (Beads & Git)

Sesuai aturan kerja proyek ini:
*   **Penyimpanan Tugas**: Sumber kebenaran utama data tugas (*source of truth*) berada di database lokal Beads (`bd`). Jangan membuat berkas TODO.md atau MEMORY.md terpisah.
*   **Pemisahan Cabang Kerja (Worktrees)**: Lakukan pengujian unit test dan kompilasi langsung pada worktree yang sedang aktif dikerjakan.
*   **Sesi Penyelesaian**: Sebelum mengakhiri sesi, selalu lakukan pemeriksaan kelayakan kode (quality gates), perbarui status issue di Beads (`bd update`), lakukan penarikan git dengan rebase, lalu **dorong perubahan ke remote repository (`git push`)**.
