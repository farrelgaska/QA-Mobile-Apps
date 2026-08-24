# UX Terminology

Kamus ini menjadi acuan teks publik QA Digitalization pada Mobile, Web, dan respons Backend. Nilai API, enum, ID, nama field, serta route tidak mengikuti label tampilan dan tidak boleh diubah hanya untuk menyamakan istilah.

## Istilah utama

| Konsep | Label publik kanonis | Nilai internal / catatan |
| --- | --- | --- |
| Modul pemeriksaan material | QC Material | `MATERIAL` atau `material` tetap |
| Modul pemeriksaan pekerjaan | QC Pekerjaan | `WORK` atau `pekerjaan` tetap |
| Catatan pengguna atau admin | Catatan | Nama field seperti `note` dan `admin_note` tetap |
| Foto pendukung pemeriksaan | Foto Dokumentasi | Path dan field foto tetap |
| Kumpulan foto pendukung | Dokumentasi | Tidak mengganti nama API evidence |
| Hasil parameter memenuhi acuan | Sesuai Standar | `WITHIN_STANDARD` / `PASS` tetap |
| Hasil parameter tidak memenuhi acuan | Tidak Sesuai Standar | `OUT_OF_STANDARD` / `FAIL` tetap |
| Dokumen hasil pemeriksaan | Laporan | ID dan field report tetap |
| Tindakan admin untuk memeriksa laporan | Tinjau / Peninjauan | `NEEDS_REVIEW` tetap |
| Tindakan admin untuk menerima laporan | Setujui / Persetujuan | `APPROVED` tetap |
| Password pada teks publik | Kata Sandi | Atribut HTML dan field internal tetap |
| Username pada teks publik | Nama Pengguna | Atribut HTML dan field internal tetap |

## Status alur laporan

| Nilai kontrak | Label tampilan |
| --- | --- |
| `DRAFT` | Draft |
| `SUBMITTED` | Dikirim |
| `NEEDS_FOLLOW_UP` | Perlu Tindak Lanjut |
| `APPROVED` | Disetujui |

Label lama seperti “Menunggu Review” tetap dapat diterima oleh normalizer kompatibilitas, tetapi tidak digunakan untuk tampilan baru.

## Hasil parameter dan keputusan admin

Evaluasi staf terhadap parameter memakai “Sesuai Standar”, “Tidak Sesuai Standar”, dan “Belum Dinilai/Belum Diisi” sesuai konteks form.

Keputusan admin adalah konsep berbeda. Nilai internal `PASS`, `FAIL`, dan `NEEDS_REVIEW` tetap stabil; label publiknya adalah “Lulus”, “Gagal”, dan “Perlu Ditinjau” atau aksi singkat “Tinjau”.

## Respons Backend

Respons publik menggunakan bahasa Indonesia yang ringkas dan tidak membocorkan detail teknis. Field `code`, status HTTP, nama header, nilai enum, dan struktur payload tetap menjadi kontrak mesin dan tidak diterjemahkan.

## Gaya bahasa

Gunakan bahasa Indonesia untuk teks publik, kecuali nama produk, role bisnis, dan istilah kontrak yang sudah baku. Gunakan kapital awal untuk label dan judul singkat; gunakan kapital kalimat untuk pesan, bantuan, dan validasi.

## Batasan

Istilah teknis yang merupakan bagian kontrak atau identitas produk—misalnya `Idempotency-Key`, path API, role, field JSON, dan kode standar perusahaan—tetap dipertahankan di kode atau dokumentasi teknis. Pembersihan ini tidak mengubah alur, desain visual, autentikasi, atau aturan bisnis.
