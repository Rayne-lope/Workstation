# Workly Style Guide

## 1. Brand Direction

Workly menggunakan gaya visual **ultra-dark productivity dashboard**: elegan, modern, bersih, dan terasa premium seperti produk SaaS kelas dunia. Antarmuka dirancang untuk task management, project dashboard, dan kanban board dengan kesan yang lebih "hidup" dibanding style lama — menggunakan aksen ungu/violet sebagai warna identitas utama, radial gradient background, dan glassmorphism yang subtle.

Kesan utama yang harus muncul:

* Modern & Premium
* Focused
* Energik tapi tidak ramai
* Gelap & elegan
* Futuristik — bukan sekadar flat dark

Hindari tampilan terlalu kering, terlalu flat, atau terlalu monoton. Warna aksen violet digunakan untuk CTA, active state, pill badge, dan progress. Background menggunakan radial gradient dengan noise texture halus agar tidak terasa seperti hitam polos.

---

## 2. Visual Personality

### Karakter Visual

| Aspek        | Arahan                                                      |
| ------------ | ----------------------------------------------------------- |
| Mood         | Dark, vibrant, focused                                      |
| Kesan        | Premium, alive, modern SaaS                                 |
| Kepadatan UI | Medium-compact, breathable                                  |
| Bentuk       | Rounded corners besar (16–20px), pill untuk badge/status    |
| Warna utama  | Deep charcoal dengan radial gradient dark                   |
| Warna aksen  | Violet/purple (#6f5bf6)                                     |
| Kontras      | High untuk teks utama, low contrast untuk metadata          |
| Motion       | Subtle hover lift, border glow aktif                        |
| Texture      | Radial gradient background + noise halus                    |

### Kata Kunci Desain

* Ultra-dark SaaS
* Violet accent
* Glassmorphism subtle
* Radial gradient
* Premium productivity
* Rounded modern
* Breathable compact

---

## 3. Color System

### Base Background

| Token          | Hex         | Penggunaan                                              |
| -------------- | ----------- | ------------------------------------------------------- |
| `--bg`         | `#0c0c0e`   | Latar utama paling gelap                                |
| `--panel`      | `#141416`   | Card, sidebar, panel utama (border transparan di atas bg)|
| `--panel-2`    | `#161618`   | Panel lapis kedua, hover state card                     |

Background body menggunakan radial gradient:
```css
background: radial-gradient(140% 120% at 80% -10%, #19191d 0%, #0c0c0e 55%);
```

### Border / Stroke

| Token            | Value       | Penggunaan                              |
| ---------------- | ----------- | --------------------------------------- |
| `--stroke`       | `#ffffff14` | Border card, divider utama (8% opacity) |
| `--stroke-soft`  | `#ffffff0d` | Divider sangat lembut, separator halus  |

Border menggunakan white dengan alpha sangat rendah sehingga terasa "floating" di atas background gelap.

### Text Palette

| Token     | Hex / Value | Penggunaan                                    |
| --------- | ----------- | --------------------------------------------- |
| `--txt`   | `#f4f4f5`   | Teks utama, judul, label aktif                |
| `--txt-2` | `#a1a1aa`   | Teks sekunder, metadata, body ringan          |
| `--txt-3` | `#6e6e76`   | Teks tersier, placeholder, disabled, muted    |

### Accent Palette

| Token          | Hex       | Penggunaan                                                |
| -------------- | --------- | --------------------------------------------------------- |
| `--accent`     | `#6f5bf6` | Primary button, active state, progress fill, active badge |
| `--accent-2`   | `#5b48e8` | Hover primary button, gradient end                        |

Gradient accent (digunakan di button dan badge pill):
```css
background: linear-gradient(135deg, #6f5bf6, #5b48e8);
```

### Radius

| Token          | Value | Penggunaan                             |
| -------------- | ----- | -------------------------------------- |
| `--radius`     | 16px  | Card, panel, container utama           |
| `--radius-lg`  | 20px  | Modal, container besar                 |

### Status / Label Colors

Warna berikut digunakan sebagai badge/pill status — selalu dengan background transparan gelap dan border tipis.

| Status      | Text Color  | Background (approx)    | Penggunaan                    |
| ----------- | ----------- | ---------------------- | ----------------------------- |
| In Progress | `#6f5bf6`   | `rgba(111,91,246,0.15)`| Status aktif / on-track       |
| Review      | `#f59e0b`   | `rgba(245,158,11,0.15)`| Menunggu review                |
| Done        | `#10b981`   | `rgba(16,185,129,0.15)`| Selesai                        |
| Blocked     | `#ef4444`   | `rgba(239,68,68,0.15)` | Blocked / urgent               |
| Planned     | `#a1a1aa`   | `rgba(161,161,170,0.1)`| Direncanakan / belum mulai     |

### Priority Dot Colors

| Priority | Color     |
| -------- | --------- |
| High     | `#ef4444` |
| Medium   | `#f59e0b` |
| Low      | `#10b981` |

---

## 4. Typography

### Font

**Workly menggunakan satu font tunggal:**

| Kebutuhan     | Font               | Weight    |
| ------------- | ------------------ | --------- |
| Display/Heading | Plus Jakarta Sans | 700–800   |
| Body / UI     | Plus Jakarta Sans  | 400–500   |
| Label / Meta  | Plus Jakarta Sans  | 500–600   |

Import:
```html
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
```

Untuk SwiftUI (macOS), gunakan fallback: **SF Pro Rounded** atau **SF Pro Display**.

### Type Scale

| Style             | Size  | Weight  | Letter Spacing | Penggunaan                              |
| ----------------- | ----- | ------- | -------------- | --------------------------------------- |
| App Title / Logo  | 15px  | 700     | –0.3px         | Brand name di sidebar                   |
| Page Title        | 22px  | 700     | –0.5px         | Judul halaman utama (h1)                |
| Section Label     | 11px  | 600     | +0.5px         | Label uppercase di atas section         |
| Card Title        | 14px  | 600     | –0.2px         | Judul task card                         |
| Body              | 13px  | 400–500 | 0              | Deskripsi card, properti, body text     |
| Meta / Small      | 12px  | 500     | 0              | Metadata, tanggal, counter kecil        |
| Tag / Badge       | 11px  | 600     | +0.2px         | Status pill, priority tag, label badge  |
| Nav Item          | 13px  | 500     | 0              | Item sidebar navigasi                   |
| Stat Value        | 28px  | 700     | –1px           | Angka besar di widget stat              |
| Stat Label        | 12px  | 500     | 0              | Label di bawah angka stat               |
| Due Date          | 11px  | 600     | 0              | Tanggal jatuh tempo di card             |
| Column Count      | 13px  | 600     | 0              | Counter jumlah task di header kolom     |

### Typography Rules

1. Semua teks utama dan judul menggunakan `--txt` (`#f4f4f5`).
2. Metadata dan secondary info menggunakan `--txt-2` (`#a1a1aa`).
3. Placeholder dan disabled text menggunakan `--txt-3` (`#6e6e76`).
4. Section label uppercase dengan letter spacing +0.5px agar terasa terstruktur.
5. Heading: weight 700–800, tracking negatif agar terasa "tight" dan premium.
6. Hindari paragraf panjang di card — batasi 2 baris teks.
7. Gunakan `font-feature-settings: 'ss01', 'cv02'` untuk Plus Jakarta Sans agar angka lebih estetik.

---

## 5. Layout System

### Struktur Layout Utama

Aplikasi terdiri dari 3 area:

1. **Sidebar** — Navigasi workspace, daftar project/filter, stat ringkasan.
2. **Main Content** — Header board + papan kanban / list view.
3. **Detail Panel (opsional)** — Drawer kanan untuk detail task.

### Sidebar

| Property      | Value         |
| ------------- | ------------- |
| Width expanded | 240px        |
| Width collapsed | 64px        |
| Background    | `#141416`     |
| Border right  | `1px solid #ffffff14` |
| Padding       | `0 12px`      |

**Sidebar sections (dari atas ke bawah):**

1. **Brand Header** — Logo icon (6px radius, gradient fill) + nama app
2. **Workspace / Nav Section** — Project list / view mode nav
3. **Divider** (`border-top: 1px solid var(--stroke-soft)`)
4. **Stats Block** — 2-column grid untuk quick stats
5. **User Profile** — Avatar + nama + role

### Spacing Scale

| Token | Value | Penggunaan                           |
| ----- | ----- | ------------------------------------ |
| 4px   | 4px   | Gap icon inline, chip padding kecil  |
| 6px   | 6px   | Gap tag row, badge padding horizontal|
| 8px   | 8px   | Padding button compact               |
| 12px  | 12px  | Padding card internal kecil          |
| 16px  | 16px  | Padding card, section spacing kecil  |
| 20px  | 20px  | Padding sidebar vertical             |
| 24px  | 24px  | Gap antar section besar              |
| 28px  | 28px  | Header horizontal padding            |
| 32px  | 32px  | Section spacing kanban               |

### Kanban Board Layout

| Property                | Value         |
| ----------------------- | ------------- |
| Column width            | 300px         |
| Column gap              | 16px          |
| Column background       | `#141416`     |
| Column border           | `1px solid #ffffff14` |
| Column border radius    | 16px          |
| Column padding          | 16px          |
| Card gap                | 10px          |
| Board padding           | `28px 28px 32px` |
| Board overflow          | horizontal scroll |

---

## 6. Radius & Shape

| Token        | Value  | Penggunaan                                        |
| ------------ | ------ | ------------------------------------------------- |
| `4px`        | 4px    | Elemen mikro: progress bar, dot kecil             |
| `6px`        | 6px    | Logo icon, icon wrapper kecil                     |
| `8px`        | 8px    | Button compact, input field                       |
| `10px`       | 10px   | Badge/pill status (terkadang hingga 999px = pill) |
| `12px`       | 12px   | Card counter/badge di header                      |
| `--radius`   | 16px   | Card task, panel, container utama                 |
| `--radius-lg`| 20px   | Modal, large container                            |
| `999px`      | 999px  | Avatar, status dot, pill badge penuh              |

### Shape Rules

1. **Card** selalu menggunakan `--radius` (16px). Ini adalah identitas utama Workly.
2. **Pill badge** (status, priority) selalu menggunakan `border-radius: 999px`.
3. **Button** menggunakan 8–10px.
4. **Avatar** selalu circular.
5. **Logo container** menggunakan `border-radius: 6px` dengan gradient fill.
6. Jangan menggunakan radius kurang dari 4px kecuali untuk element teknis.

---

## 7. Border, Shadow, dan Elevation

### Border System

Seluruh border menggunakan **white dengan alpha rendah** — tidak pernah menggunakan warna gelap solid seperti `#1e1e1e`.

| Elemen               | Border                      |
| -------------------- | --------------------------- |
| Card default         | `1px solid rgba(255,255,255,0.08)` (`--stroke`) |
| Column kanban        | `1px solid rgba(255,255,255,0.08)` |
| Sidebar border       | `1px solid rgba(255,255,255,0.08)` |
| Divider              | `1px solid rgba(255,255,255,0.05)` (`--stroke-soft`) |
| Input focus          | `1px solid #6f5bf6`         |
| Badge/pill border    | tidak ada (background saja) |

### Shadow

| State              | Shadow                                         |
| ------------------ | ---------------------------------------------- |
| Card hover         | `0 8px 32px rgba(0,0,0,0.4)`                   |
| Column hover       | `0 4px 24px rgba(0,0,0,0.3)`                   |
| Primary button hover | `0 4px 20px rgba(111,91,246,0.4)`            |
| Active element     | `0 0 0 1px rgba(111,91,246,0.3)` (glow ring)   |

### Elevation Rules

1. Default: hampir flat, hanya border stroke tipis.
2. Hover card: naik tipis (`translateY(-2px)`) + shadow gelap.
3. Hover button: naik (`translateY(-1px)`) + violet shadow.
4. Jangan gunakan shadow putih atau shadow terang.
5. Active state lebih baik pakai violet border/glow daripada shadow besar.

---

## 8. Components

### 8.1 Sidebar Navigation

#### Brand Header

```
[ Logo Icon ] App Name
```

* Logo icon: kotak 28×28px, border-radius 6px, gradient `#6f5bf6 → #5b48e8`, isi dengan icon/inisial putih 14px bold.
* App name: 15px, weight 700, `--txt`, letter-spacing -0.3px.

#### Nav Item

| State    | Style                                                             |
| -------- | ----------------------------------------------------------------- |
| Default  | Text `--txt-2`, background transparent, radius 8px               |
| Hover    | Background `rgba(255,255,255,0.04)`, text `--txt`                 |
| Active   | Background `rgba(111,91,246,0.15)`, text `#6f5bf6`, font 500     |

* Padding: `8px 10px`
* Gap: 8px (icon + label)
* Icon: 14px, warna menyesuaikan text

#### Stats Block

Dua kolom grid, masing-masing stat:

```
28px bold  ← angka besar
12px 500   ← label muted
```

* Background: `rgba(255,255,255,0.03)`
* Border: `1px solid rgba(255,255,255,0.06)`
* Border radius: 12px
* Padding: `12px`

#### User Profile (bawah sidebar)

```
[ Avatar 32px ] Name (13px 600)
                Role (12px txt-3)
```

* Padding top: 16px
* Border top: `1px solid rgba(255,255,255,0.06)`

---

### 8.2 Board Header

```
[ Page Title 22px 700 ]     [ Filter ] [ Sort ] [ + New Task ]
[ Breadcrumb / subtitle ]
```

* Background: transparan (konten langsung di atas board)
* Padding bottom: 24px
* Breadcrumb: 12px, `--txt-3`, uppercase, letter-spacing +0.5px
* Action buttons: ghost style di kiri, primary violet di kanan

---

### 8.3 Kanban Column

#### Column Header

```
[ Dot 8px ] Column Label (14px 600 txt)   [ Count badge ] [ + ]
```

* Dot: 8px circle, warna berbeda per kolom (lihat Status Colors)
* Count badge: `rgba(255,255,255,0.08)` background, border-radius 12px, padding `2px 8px`, font 13px 600
* Add button (+): 28×28px, border-radius 8px, hover background `rgba(255,255,255,0.06)`

#### Column Footer

Tombol "+ Add Task" di bawah list:
* Width: penuh (100%)
* Border: `1px dashed rgba(255,255,255,0.12)`
* Border radius: 10px
* Padding: `10px`
* Text: 13px, `--txt-3`, icon + label
* Hover: background `rgba(255,255,255,0.04)`, text `--txt-2`

---

### 8.4 Task Card

#### Anatomy (dari atas ke bawah)

```
┌─────────────────────────────────┐
│ [Tag pill] [Tag pill]           │  ← baris tag (opsional)
│                                 │
│ Task Title (14px 600)           │  ← judul
│ Description text... (13px)      │  ← 1–2 baris, txt-2
│                                 │
│ [Priority dot] Priority label   │  ← baris priority
│                                 │
│ ─────────────────────────────── │  ← divider tipis
│                                 │
│ Due: Jan 15   [◯] [◯] [◯]  💬3 │  ← footer: due date + avatars + count
└─────────────────────────────────┘
```

#### Style

| Property      | Value                                        |
| ------------- | -------------------------------------------- |
| Background    | `#141416` (`--panel`)                        |
| Border        | `1px solid rgba(255,255,255,0.08)`            |
| Border radius | 16px (`--radius`)                             |
| Padding       | `16px`                                        |
| Gap internal  | `12px`                                        |
| Title         | 14px, weight 600, `--txt`, letter-spacing –0.2px |
| Description   | 13px, weight 400, `--txt-2`, max 2 lines     |
| Divider       | `1px solid rgba(255,255,255,0.06)`            |

#### Hover State

* `transform: translateY(-2px)`
* `box-shadow: 0 8px 32px rgba(0,0,0,0.4)`
* `border-color: rgba(255,255,255,0.12)`
* Transition: `all 200ms ease`

#### Active / Selected State

* Border: `1px solid #6f5bf6`
* Box shadow: `0 0 0 1px rgba(111,91,246,0.3)`

#### Card Footer

* Layout: `flex`, `justify-content: space-between`, `align-items: center`
* Due date: 11px, weight 600, `--txt-3`
* Avatar stack: overlap –6px, size 22px
* Comment count: icon + angka, 12px, `--txt-3`
* Icon pemisah: `·` atau divider karakter

---

### 8.5 Status Badge / Pill

Semua status menggunakan pill elongated (border-radius: 999px):

```css
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.2px;
}
```

| Status      | Text        | Background                    |
| ----------- | ----------- | ----------------------------- |
| In Progress | `#6f5bf6`   | `rgba(111,91,246,0.15)`       |
| Review      | `#f59e0b`   | `rgba(245,158,11,0.15)`       |
| Done        | `#10b981`   | `rgba(16,185,129,0.15)`       |
| Blocked     | `#ef4444`   | `rgba(239,68,68,0.15)`        |
| Planned     | `#a1a1aa`   | `rgba(161,161,170,0.1)`       |

Dot kecil 6px di dalam badge (warna sama dengan text):
```css
.badge-dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }
```

---

### 8.6 Priority Tag

Menggunakan dot + label horizontal:

```
● High
```

| Priority | Dot Color | Text            |
| -------- | --------- | --------------- |
| High     | `#ef4444` | `#ef4444`       |
| Medium   | `#f59e0b` | `#f59e0b`       |
| Low      | `#10b981` | `#10b981`       |

* Font: 12px, weight 500
* Gap: 5px
* Dot size: 6px circle

---

### 8.7 Buttons

#### Primary Button

Digunakan untuk aksi utama: **+ New Task**, **Save**, **Submit**.

| Property     | Value                                       |
| ------------ | ------------------------------------------- |
| Background   | `linear-gradient(135deg, #6f5bf6, #5b48e8)` |
| Text         | `#ffffff`                                   |
| Font         | 13px, weight 600                            |
| Padding      | `8px 16px`                                  |
| Border radius | 10px                                       |
| Border       | none                                        |
| Hover bg     | gradient lebih terang + translateY(–1px)    |
| Hover shadow | `0 4px 20px rgba(111,91,246,0.4)`           |
| Transition   | `all 200ms ease`                            |

#### Ghost / Secondary Button

Digunakan untuk: Filter, Sort, Export, Close.

| Property     | Value                              |
| ------------ | ---------------------------------- |
| Background   | `rgba(255,255,255,0.06)`           |
| Text         | `--txt-2`                          |
| Border       | `1px solid rgba(255,255,255,0.1)`  |
| Border radius | 8–10px                            |
| Padding      | `7px 14px`                         |
| Hover bg     | `rgba(255,255,255,0.1)`            |
| Hover text   | `--txt`                            |
| Transition   | `all 150ms ease`                   |

#### Icon Button (Square)

* Size: 32×32px (min 30×30px)
* Border radius: 8px
* Background: `rgba(255,255,255,0.06)` atau transparent
* Hover: `rgba(255,255,255,0.1)`
* Icon size: 14–16px

#### Add Task Button (dalam column footer)

Lihat §8.3 Column Footer.

---

### 8.8 Avatar

| Property      | Value                      |
| ------------- | -------------------------- |
| Shape         | Circle (border-radius: 50%)|
| Size card     | 22–24px                    |
| Size header   | 30–32px                    |
| Size sidebar  | 32px                       |
| Border        | `2px solid #0c0c0e` (bg color) |
| Stack overlap | `–6px`                     |
| Font size     | 8–10px, bold, untuk initials |
| Color base    | Gradient atau flat accent  |

Avatar stack: elemen pertama di depan (z-index lebih tinggi).

---

### 8.9 Progress Bar

| Property      | Value                                       |
| ------------- | ------------------------------------------- |
| Height        | 3–4px                                       |
| Track color   | `rgba(255,255,255,0.08)`                    |
| Fill gradient | `linear-gradient(90deg, #6f5bf6, #5b48e8)`  |
| Border radius | 999px (pill)                                |
| Animation     | `width` transition 600ms ease-out           |

---

### 8.10 Input / Search

| Property      | Value                                |
| ------------- | ------------------------------------ |
| Background    | `rgba(255,255,255,0.05)`             |
| Border        | `1px solid rgba(255,255,255,0.08)`   |
| Border radius | 10px                                 |
| Text          | `--txt`                              |
| Placeholder   | `--txt-3`                            |
| Padding       | `8px 12px`                           |
| Focus border  | `1px solid #6f5bf6`                  |
| Focus shadow  | `0 0 0 3px rgba(111,91,246,0.2)`     |
| Transition    | `all 150ms ease`                     |

---

### 8.11 Divider

* Horizontal: `1px solid rgba(255,255,255,0.05)` (`--stroke-soft`)
* Vertikal (sidebar): `1px solid rgba(255,255,255,0.06)`
* Jangan gunakan margin berlebihan — spacing sudah cukup dari padding parent

---

## 9. Motion & Interaction

### Animation Timing

| Interaction           | Duration | Easing         |
| --------------------- | -------- | -------------- |
| Hover card            | 200ms    | ease           |
| Hover button          | 150ms    | ease           |
| Hover nav item        | 150ms    | ease           |
| Card translate-up     | 200ms    | ease           |
| Progress bar fill     | 600ms    | ease-out       |
| Detail panel slide    | 300ms    | cubic-bezier   |
| Badge/pill appear     | 150ms    | ease           |
| Column appear         | 200ms    | ease-out       |
| Input focus glow      | 150ms    | ease           |

### Motion Rules

1. **Translate** card saat hover: `translateY(-2px)` — tidak lebih.
2. **Translate** button saat hover: `translateY(-1px)`.
3. Semua interaksi hover: transition `all` dengan durasi pendek.
4. Jangan gunakan animasi loop tanpa trigger.
5. Loading indicator menggunakan native `ProgressView` (SwiftUI) atau spinner kecil 16px — tidak ada custom skeleton complex.
6. Sidebar collapse: `width` transition 300ms.
7. Panel slide: `transform: translateX` dari kanan.

---

## 10. Iconography

### Style

* **Stroke icon** (line icon), bukan filled.
* Stroke width: 1.5–2px.
* Size umum: 14–16px.
* Color default: `--txt-2` atau `--txt-3`.
* Color aktif/hover: `--txt` atau `#6f5bf6`.

### Usage

| Konteks               | Size | Color      |
| --------------------- | ---- | ---------- |
| Nav item sidebar      | 14px | --txt-2    |
| Card footer           | 12px | --txt-3    |
| Button icon           | 14px | --txt      |
| Header action button  | 14px | --txt-2    |
| Column add button     | 14px | --txt-3    |

### Rules

1. Gunakan satu library icon konsisten (SF Symbols untuk macOS, Lucide/Heroicons untuk web).
2. Jangan campur filled dan outline dalam satu area.
3. Icon dalam button: gap 6px dari label.
4. Icon standalone tanpa teks: pastikan ada tooltip.

---

## 11. Background Texture

Background body menggunakan radial gradient — **bukan flat dark dan bukan dot pattern** seperti style lama.

```css
body {
  background: radial-gradient(140% 120% at 80% -10%, #19191d 0%, #0c0c0e 55%);
}
```

### Rules

1. Radial gradient hanya di body/app background — tidak di card atau panel.
2. Panel dan card menggunakan flat `#141416` — gradient cukup dari background.
3. Subtle noise texture boleh ditambahkan di level body (opacity sangat rendah, < 3%).
4. Jangan gunakan dot grid pattern — terlalu bertektur dan mengurangi sense of depth.

---

## 12. Content Rules

### Task Card Content

Judul task harus pendek, spesifik, dapat dipindai dengan cepat.

Contoh baik:
* Redesign onboarding flow
* Fix auth token expiry bug
* Add CSV export feature

Contoh kurang baik:
* Fix stuff
* UI work
* Backend thing

### Metadata Display

Tampilkan metadata ringkas di footer card:
* Due date (format: "Jan 15" atau "Due in 3d")
* Avatar stack (max 3 avatar + overflow counter)
* Comment count (icon + angka)

### Empty State Column

* Teks pendek: "No tasks here"
* Action: "+ Add first task"
* Jangan terlalu elaborate

### Column Label Convention

Kolom status menggunakan label singkat:
* To Do / Backlog
* In Progress
* Review
* Done

---

## 13. Quick Implementation Tokens

### CSS Variables (Web)

```css
:root {
  /* Background */
  --bg: #0c0c0e;
  --panel: #141416;
  --panel-2: #161618;

  /* Stroke / Border */
  --stroke: rgba(255, 255, 255, 0.08);
  --stroke-soft: rgba(255, 255, 255, 0.05);

  /* Text */
  --txt: #f4f4f5;
  --txt-2: #a1a1aa;
  --txt-3: #6e6e76;

  /* Accent */
  --accent: #6f5bf6;
  --accent-2: #5b48e8;

  /* Radius */
  --radius: 16px;
  --radius-lg: 20px;

  /* Status */
  --status-progress: #6f5bf6;
  --status-review: #f59e0b;
  --status-done: #10b981;
  --status-blocked: #ef4444;
  --status-planned: #a1a1aa;

  /* Priority */
  --priority-high: #ef4444;
  --priority-medium: #f59e0b;
  --priority-low: #10b981;
}
```

### SwiftUI Color Mapping

```swift
// WorkstationTheme baru (Workly style)
extension WorkstationTheme {
    // Background
    static let background    = Color(hex: "#0c0c0e")
    static let panel         = Color(hex: "#141416")
    static let panelAlt      = Color(hex: "#161618")

    // Stroke
    static let stroke        = Color.white.opacity(0.08)
    static let strokeSoft    = Color.white.opacity(0.05)

    // Text
    static let textPrimary   = Color(hex: "#f4f4f5")
    static let textSecondary = Color(hex: "#a1a1aa")
    static let textMuted     = Color(hex: "#6e6e76")

    // Accent
    static let accent        = Color(hex: "#6f5bf6")
    static let accentDark    = Color(hex: "#5b48e8")

    // Status
    static let statusProgress = Color(hex: "#6f5bf6")
    static let statusReview  = Color(hex: "#f59e0b")
    static let statusDone    = Color(hex: "#10b981")
    static let statusBlocked = Color(hex: "#ef4444")
    static let statusPlanned = Color(hex: "#a1a1aa")

    // Priority
    static let priorityHigh  = Color(hex: "#ef4444")
    static let priorityMed   = Color(hex: "#f59e0b")
    static let priorityLow   = Color(hex: "#10b981")

    // Radius
    enum Radius {
        static let small:  CGFloat = 8
        static let medium: CGFloat = 12
        static let large:  CGFloat = 16
        static let xl:     CGFloat = 20
    }

    // Spacing
    enum Space {
        static let xs:  CGFloat = 6
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }
}
```

---

## 14. Do & Don't

### Do ✅

* Gunakan `rgba(255,255,255,X)` untuk semua border dan stroke — tidak pernah warna gelap solid.
* Gunakan radial gradient di background utama.
* Gunakan violet (#6f5bf6) sebagai satu-satunya accent dominan.
* Berikan hover shadow violet pada primary button.
* Gunakan pill (border-radius: 999px) untuk semua badge status.
* Pertahankan radius besar (16px) di card untuk kesan modern.
* Gunakan Plus Jakarta Sans (atau SF Pro Rounded di macOS) untuk semua teks.
* Icon selalu stroke/outline, tidak pernah filled.

### Don't ❌

* Jangan gunakan gold/amber sebagai accent (itu style Craftboard lama).
* Jangan gunakan flat black `#000000` sebagai background.
* Jangan gunakan border gelap solid seperti `#1e1e1e`.
* Jangan gunakan dot background pattern.
* Jangan gunakan shadow putih atau glowing terang.
* Jangan gunakan border-radius kurang dari 8px untuk card.
* Jangan gunakan font weight di bawah 400 atau di atas 800.
* Jangan gunakan animasi looping yang tidak di-trigger user.
* Jangan gunakan lebih dari 2 warna accent berbeda dalam satu area.

---

## 15. Summary

Workly adalah style guide untuk aplikasi produktivitas dark-mode generasi berikutnya. Berbeda dengan style Craftboard yang menggunakan gold warm accent dan flat dark surface, Workly menggunakan **violet/purple accent**, **radial gradient background**, **white alpha border**, dan **radius besar** untuk menciptakan tampilan yang lebih modern, energik, dan premium.

Sistem ini cocok digunakan untuk:
* Kanban board / task management app
* Project dashboard
* SaaS internal tool
* Issue tracker dengan tampilan modern

Referensi visual: Workly Tasks Dashboard (Dribbble-class design, 2025 aesthetic).
