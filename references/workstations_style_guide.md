# Craftboard General Style Guide

## 1. Brand Direction

Craftboard menggunakan gaya visual **dark productivity workspace**: tenang, premium, fokus, dan efisien. Antarmuka dirancang untuk aplikasi kerja seperti kanban board, task management, project dashboard, workspace internal, atau SaaS productivity tool.

Kesan utama yang harus muncul:

* Profesional
* Fokus
* Minimal
* Premium
* Terstruktur
* Modern
* Tidak terlalu ramai

Hindari tampilan yang terlalu playful, terlalu colorful, atau terlalu terang. Warna aksen digunakan seperlunya untuk menandai status aktif, progress, prioritas, dan action utama.

---

## 2. Visual Personality

### Karakter Visual

| Aspek        | Arahan                                                      |
| ------------ | ----------------------------------------------------------- |
| Mood         | Dark, calm, focused                                         |
| Kesan        | Premium, precise, modern                                    |
| Kepadatan UI | Compact, information-dense                                  |
| Bentuk       | Rounded, clean, soft edges                                  |
| Warna utama  | Hitam arang dan abu gelap                                   |
| Warna aksen  | Gold hangat                                                 |
| Kontras      | Medium-high untuk teks penting, low contrast untuk metadata |
| Motion       | Subtle, cepat, tidak mencolok                               |

### Kata Kunci Desain

* Dark workspace
* Premium productivity
* Compact dashboard
* Warm accent
* Soft interaction
* Minimal hierarchy
* Low-noise interface

---

## 3. Color System

### Primary Palette

| Token          |       Hex | Penggunaan                            |
| -------------- | --------: | ------------------------------------- |
| Background     | `#0F0F0F` | Latar utama aplikasi                  |
| Surface        | `#111111` | Sidebar, header, panel                |
| Card           | `#141414` | Card, comment bubble, container kecil |
| Input Surface  | `#151515` | Input, textarea, search field         |
| Border Soft    | `#1A1A1A` | Divider, border panel besar           |
| Border Default | `#1E1E1E` | Border card dan container             |
| Border Strong  | `#2A2A2A` | Hover border, tag border              |

### Text Palette

| Token          |       Hex | Penggunaan                                |
| -------------- | --------: | ----------------------------------------- |
| Text Primary   | `#F0ECE4` | Judul, teks utama, active tab             |
| Text Secondary | `#888888` | Body ringan, assignee, comment text       |
| Text Muted     | `#555555` | Metadata, nav inactive, deskripsi pendek  |
| Text Disabled  | `#333333` | Placeholder, icon nonaktif, divider label |
| Text Subtle    | `#444444` | Label properti, timestamp, breadcrumb     |

### Accent Palette

| Token             |       Hex | Penggunaan                                           |
| ----------------- | --------: | ---------------------------------------------------- |
| Accent Gold       | `#ECC864` | Primary button, active state, progress, status aktif |
| Accent Gold Hover | `#F5D980` | Hover primary button, gradient progress              |
| Info Blue         | `#7DD3FC` | Tag dashboard, review status, avatar CT              |
| Success Green     | `#86EFAC` | Done status, completed stat                          |
| Purple            | `#D8B4FE` | Mobile tag, avatar AR                                |
| Red               | `#F87171` | File PDF / danger ringan                             |
| Orange            | `#FB923C` | File design / AI asset                               |

### Aturan Penggunaan Warna

1. Gunakan warna gelap sebagai dasar mayoritas UI.
2. Gunakan gold hanya untuk elemen yang perlu perhatian tinggi.
3. Jangan gunakan banyak warna terang dalam satu area.
4. Metadata harus low contrast agar tidak bersaing dengan judul.
5. Status boleh memakai warna berbeda, tapi tetap dalam tone gelap.
6. Border lebih sering digunakan daripada shadow untuk memisahkan elemen.

---

## 4. Typography

### Font Direction

Style asli menggunakan kombinasi:

* **Display / Heading:** Syne
* **Body / UI:** DM Sans

Jika font tersebut tidak tersedia, gunakan alternatif:

| Kebutuhan | Font Utama | Alternatif                            |
| --------- | ---------- | ------------------------------------- |
| Heading   | Syne       | Inter Tight, Manrope, SF Pro Rounded  |
| Body      | DM Sans    | Inter, SF Pro Text, system sans-serif |
| Metadata  | DM Sans    | Inter, SF Pro Text                    |

### Type Scale

| Style         | Size |  Weight | Penggunaan                          |
| ------------- | ---: | ------: | ----------------------------------- |
| Page Title    | 26px |     800 | Judul halaman utama                 |
| Panel Title   | 22px |     700 | Judul detail task                   |
| Section Title | 14px |     600 | Section dalam panel                 |
| Card Title    | 13px |     600 | Judul task card                     |
| Body          | 13px | 400–500 | Deskripsi, komentar, property value |
| Small Body    | 12px | 400–500 | Metadata, nav item, secondary info  |
| Label         | 11px |     600 | Uppercase label, breadcrumb         |
| Tag           | 10px | 600–700 | Chip, counter, due date             |

### Typography Rules

1. Heading memakai weight tebal dan spacing rapat.
2. Body text tidak perlu terlalu besar; UI ini bersifat compact.
3. Label kecil boleh uppercase dengan letter spacing.
4. Gunakan warna, weight, dan spacing untuk hierarchy; jangan hanya mengandalkan ukuran font.
5. Hindari paragraf panjang di card. Batasi maksimal 2 baris.

---

## 5. Layout System

### Struktur Layout Utama

Aplikasi terdiri dari 4 area utama:

1. **Sidebar**
   Navigasi workspace, project list, quick stats.

2. **Header**
   Breadcrumb, page title, avatar stack, action button, view tabs.

3. **Main Board**
   Area kanban dengan horizontal scroll dan background dot pattern.

4. **Detail Panel**
   Panel kanan untuk detail task, progress, property, attachment, subtasks, comments, activity.

### Spacing Scale

| Token | Value | Penggunaan                        |
| ----- | ----: | --------------------------------- |
| XXS   |   4px | Gap icon kecil, chip internal     |
| XS    |   6px | Gap tag, inline metadata          |
| SM    |   8px | Padding kecil, button compact     |
| MD    |  12px | Padding card kecil, form field    |
| LG    |  16px | Padding card utama, button normal |
| XL    |  24px | Section spacing, board padding    |
| XXL   |  28px | Header horizontal padding         |

### Layout Rules

1. Sidebar default: 240px.
2. Collapsed sidebar: 64px.
3. Kanban column width: 300px.
4. Detail panel width: sekitar 460px.
5. Gunakan vertical rhythm yang konsisten: 8, 12, 16, 24.
6. Area utama boleh horizontal scroll untuk menjaga card tetap compact.
7. Jangan memaksa semua kolom masuk ke layar jika mengorbankan readability.

---

## 6. Radius & Shape

| Token  | Value | Penggunaan                 |
| ------ | ----: | -------------------------- |
| Small  |   4px | Tag, mini badge, due date  |
| Medium | 6–8px | Button, input, nav item    |
| Large  |  10px | Card, progress container   |
| Panel  |  12px | Container besar atau modal |
| Circle | 999px | Avatar, status dot, pill   |

### Shape Rules

1. Gunakan rounded corner, tetapi jangan terlalu besar.
2. Card utama ideal di 10px.
3. Button dan input ideal di 8px.
4. Tag dan badge ideal di 4px.
5. Avatar selalu circular.

---

## 7. Border, Shadow, dan Elevation

### Border

Border adalah pemisah utama dalam sistem ini.

| Elemen        | Border                                  |
| ------------- | --------------------------------------- |
| Card default  | `1px solid #1E1E1E`                     |
| Card hover    | `1px solid #2A2A2A`                     |
| Active card   | `1px solid #ECC864` + subtle outer ring |
| Panel divider | `1px solid #1A1A1A`                     |
| Input         | `1px solid #222222`                     |
| Input focus   | `1px solid #ECC864`                     |

### Shadow

Gunakan shadow sangat terbatas.

| State         | Shadow                              |
| ------------- | ----------------------------------- |
| Card hover    | `0 8px 32px rgba(0,0,0,0.4)`        |
| Active card   | `0 8px 32px rgba(236,200,100,0.08)` |
| Primary hover | `0 4px 16px rgba(236,200,100,0.3)`  |

### Elevation Rules

1. Default state hampir flat.
2. Hover boleh sedikit naik dan diberi shadow.
3. Active state lebih baik memakai border gold daripada shadow besar.
4. Jangan memakai shadow terang berlebihan.

---

## 8. Components

## 8.1 Sidebar

### Fungsi

Sidebar digunakan untuk navigasi utama, daftar project, quick stats, dan collapse control.

### Style

* Background: `#111111`
* Border kanan: `#1A1A1A`
* Width expanded: 240px
* Width collapsed: 64px
* Padding vertical: 20px

### States

| State          | Style                                           |
| -------------- | ----------------------------------------------- |
| Default nav    | Text `#555555`                                  |
| Hover nav      | Background `#1A1A1A`, text `#F0ECE4`            |
| Active project | Background `#161616`, text primary, colored dot |
| Collapsed      | Icon only                                       |

---

## 8.2 Header

### Fungsi

Header menampilkan konteks halaman, title, member/avatar, action utama, dan tabs view.

### Style

* Background: `#111111`
* Bottom border: `#1A1A1A`
* Padding: `16px 28px 0`
* Title: 26px, bold, display font

### Header Elements

* Breadcrumb kecil di atas title.
* Page title di kiri.
* Avatar stack dan buttons di kanan.
* View tabs di bawah.

---

## 8.3 Kanban Column

### Style

* Width: 300px
* Gap antar card: 10px
* Header dot: 8px circle
* Column counter: badge kecil

### Rules

1. Header kolom harus ringkas.
2. Counter ditempatkan dekat label.
3. Add task button memakai dashed border.
4. Kolom tidak perlu background sendiri agar board terasa ringan.

---

## 8.4 Task Card

### Style

* Background: `#141414`
* Border: `#1E1E1E`
* Radius: 10px
* Padding: `14px 16px`
* Title: 13px, semibold
* Description: 12px, muted, max 2 lines

### Anatomy

1. Tags
2. Title
3. Description
4. Progress bar jika ada
5. Footer: avatar, attachment count, comment count, due date

### Active State

* Border gold.
* Top gradient line gold.
* Subtle gold shadow.

### Hover State

* Translate Y: -2px.
* Shadow hitam lembut.
* Border sedikit lebih terang.

---

## 8.5 Detail Panel

### Fungsi

Panel kanan digunakan untuk memperlihatkan detail task tanpa meninggalkan board.

### Style

* Width: 460px
* Background: `#111111`
* Border left: `#1E1E1E`
* Header height compact
* Content scrollable

### Sections

1. Breadcrumb panel
2. Title task
3. Progress summary
4. Properties
5. Description
6. Attachments
7. Tabs
8. Subtasks / Comments / Activity

### Rules

1. Detail panel harus terasa seperti drawer, bukan full page.
2. Gunakan spacing 24px antar section utama.
3. Gunakan label kecil uppercase untuk section title.
4. Informasi properti ditampilkan dalam grid dua kolom.

---

## 8.6 Buttons

### Primary Button

Digunakan untuk aksi utama seperti **New Task**.

| Property   | Value                      |
| ---------- | -------------------------- |
| Background | `#ECC864`                  |
| Text       | `#0F0F0F`                  |
| Radius     | 8px                        |
| Padding    | `8px 16px`                 |
| Font       | 13px / 600                 |
| Hover      | `#F5D980`, translateY -1px |

### Ghost Button

Digunakan untuk aksi sekunder seperti Share, Filter, Sort, More, Close.

| Property   | Value                    |
| ---------- | ------------------------ |
| Background | Transparent              |
| Text       | `#888888` atau `#555555` |
| Border     | `#222222`                |
| Hover BG   | `#1A1A1A`                |
| Hover Text | `#F0ECE4`                |

### Button Rules

1. Hanya satu primary button dalam satu area utama.
2. Ghost button digunakan untuk action tambahan.
3. Icon button harus 30–40px agar mudah diklik.
4. Button compact memakai font 12px.

---

## 8.7 Tags / Chips

### Base Style

* Display: inline-flex
* Gap: 4px
* Padding: `2px 8px`
* Radius: 4px
* Font size: 10px
* Font weight: 600

### Tag Variants

| Tag       | Background |      Text |    Border |
| --------- | ---------: | --------: | --------: |
| High      |  `#1A1108` | `#ECC864` | `#3A2F0A` |
| Medium    |  `#141414` | `#AAAAAA` | `#2A2A2A` |
| Low       |  `#111111` | `#555555` | `#1E1E1E` |
| Dashboard |  `#0F1A1F` | `#7DD3FC` | `#0F2535` |
| Mobile    |  `#1A0F1A` | `#D8B4FE` | `#2E1A40` |

### Rules

1. Tag tidak boleh terlalu besar.
2. Gunakan background gelap sesuai warna kategori.
3. Hindari solid bright background.
4. High priority boleh diberi dot kecil gold.

---

## 8.8 Avatar

### Style

* Shape: circle
* Size default: 24px
* Size header: 30px
* Border: `2px solid #181818`
* Font: 8–10px, bold

### Avatar Stack

* Overlap: -6px
* Hover: jarak overlap bisa berkurang sedikit
* Gunakan initials jika tidak ada foto
* Foto avatar boleh grayscale agar tidak terlalu ramai

---

## 8.9 Progress

### Progress Bar

* Height: 3px
* Track: `#1E1E1E`
* Fill: gradient `#ECC864 → #F5D980`
* Radius: 2px
* Animation: 600ms ease-out

### Progress Ring

* Stroke track: `#1E1E1E`
* Stroke fill: `#ECC864`
* Stroke width: 3px
* Size kecil: 28px
* Size panel: 44px

### Rules

1. Progress hanya ditampilkan jika nilainya relevan.
2. Gunakan gold sebagai warna progress utama.
3. Jangan memakai banyak progress style berbeda dalam satu layar.

---

## 8.10 Forms & Inputs

### Search / Input Field

| Property     | Value     |
| ------------ | --------- |
| Background   | `#151515` |
| Border       | `#222222` |
| Text         | `#F0ECE4` |
| Placeholder  | `#444444` |
| Focus border | `#ECC864` |
| Radius       | 8px       |

### Rules

1. Input harus menyatu dengan dark surface.
2. Focus state harus jelas tetapi tidak terlalu terang.
3. Placeholder harus low contrast.
4. Gunakan icon kecil untuk memperjelas fungsi input.

---

## 9. Motion & Interaction

### Animation Timing

| Interaction        | Duration | Easing                  |
| ------------------ | -------: | ----------------------- |
| Hover button       |    150ms | ease                    |
| Hover card         |    200ms | cubic ease-out          |
| Detail panel slide |    350ms | cubic-bezier style      |
| Progress change    |    600ms | smooth ease-out         |
| Check animation    |    250ms | ease                    |
| Sidebar collapse   |    300ms | spring / cubic ease-out |

### Motion Rules

1. Motion harus subtle.
2. Gunakan translate kecil, bukan scale besar.
3. Hindari animasi yang berulang terus-menerus kecuali untuk loading.
4. Progress animation boleh lebih lambat agar terasa smooth.
5. Drawer/panel menggunakan slide dari kanan.

---

## 10. Iconography

### Style

* Stroke icon, bukan filled icon.
* Stroke width: 2–2.5px.
* Size umum: 12–16px.
* Gunakan warna muted secara default.
* Icon aktif boleh memakai text primary atau accent.

### Rules

1. Icon hanya membantu, bukan elemen utama.
2. Jangan gunakan icon dengan style berbeda-beda dalam satu area.
3. Gunakan ukuran kecil untuk metadata.
4. Action icon dalam panel memakai button 30x30px.

---

## 11. Background Pattern

Board menggunakan dot background untuk memberi tekstur halus.

### Style

* Base: `#0F0F0F`
* Dot color: `#1E1E1E`
* Dot size: 1px
* Grid size: 24px

### Rules

1. Pattern harus sangat subtle.
2. Jangan gunakan pattern pada card atau panel.
3. Pattern cocok untuk area luas seperti kanban board.
4. Pattern tidak boleh mengganggu readability.

---

## 12. Content Rules

### Task Card Content

Judul task harus pendek dan spesifik.

Contoh baik:

* Employee Details Page
* Dark Mode Version
* KPI & Employee Statistics

Contoh kurang baik:

* Fix UI
* Make page
* Dashboard thing

### Metadata

Gunakan metadata ringkas:

* Comment count
* Attachment count
* Due date
* Progress percentage
* Assignee initials

### Empty State

Gunakan teks pendek dan action jelas.

Contoh:

* “No tasks yet”
* “Add your first task”
* “Create section”

---

## 13. Accessibility Guidelines

1. Pastikan teks utama memiliki kontras cukup terhadap background.
2. Jangan mengandalkan warna saja untuk status; tambahkan label atau icon.
3. Area klik minimal 30x30px untuk desktop, 44x44px untuk mobile.
4. Focus state harus terlihat jelas.
5. Hover state harus punya alternatif untuk keyboard focus.
6. Hindari teks terlalu kecil untuk konten penting.
7. Gunakan semantic label untuk icon button.

---

## 14. Responsive Behavior

### Desktop

* Sidebar expanded default.
* Detail panel kanan dapat terbuka bersamaan dengan board.
* Board horizontal scroll.

### Tablet

* Sidebar bisa collapsed secara default.
* Detail panel dapat overlay di atas board.
* Column width tetap 280–300px.

### Mobile

* Sidebar menjadi drawer.
* Header disederhanakan.
* Kanban column ditampilkan satu per satu atau horizontal swipe.
* Detail panel menjadi full-screen sheet.
* Button utama tetap terlihat di area atas atau floating.

---

## 15. Do & Don’t

### Do

* Gunakan dark surface yang konsisten.
* Pakai gold untuk action dan active state.
* Gunakan border tipis sebagai pemisah.
* Buat card compact dan mudah dipindai.
* Gunakan metadata kecil dan muted.
* Pertahankan spacing 8/12/16/24.

### Don’t

* Jangan membuat semua elemen berwarna gold.
* Jangan memakai background terlalu terang.
* Jangan memakai shadow besar di semua card.
* Jangan memperbesar font metadata.
* Jangan mencampur banyak gaya icon.
* Jangan membuat card terlalu tinggi tanpa alasan.
* Jangan memakai animasi berlebihan.

---

## 16. Quick Implementation Tokens

```css
:root {
  --bg: #0f0f0f;
  --surface: #111111;
  --card: #141414;
  --input: #151515;

  --border-soft: #1a1a1a;
  --border: #1e1e1e;
  --border-strong: #2a2a2a;

  --text-primary: #f0ece4;
  --text-secondary: #888888;
  --text-muted: #555555;
  --text-disabled: #333333;

  --accent: #ecc864;
  --accent-hover: #f5d980;
  --info: #7dd3fc;
  --success: #86efac;
  --purple: #d8b4fe;
  --danger-soft: #f87171;
  --orange: #fb923c;

  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 10px;

  --space-xs: 6px;
  --space-sm: 8px;
  --space-md: 12px;
  --space-lg: 16px;
  --space-xl: 24px;
}
```

---

## 17. Summary

Craftboard adalah style guide untuk aplikasi produktivitas dark-mode yang compact, premium, dan terstruktur. Sistem ini mengandalkan surface gelap, border tipis, typography kecil namun jelas, serta aksen gold yang dipakai secara hemat untuk menandai prioritas dan interaksi penting.

Gunakan sistem ini ketika ingin membangun UI yang terasa profesional, fokus, dan cocok untuk dashboard, task management, project workspace, atau SaaS internal tool.
