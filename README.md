# Buku Hajatan

Aplikasi Flutter pencatat amplop hajatan — pengganti pencatatan manual
di buku (amplop digabung per 10 jadi satu bundel berkode, mis. `A001`).
Backend: **Firebase (Firestore)**, paket Spark/gratis — sinkron offline
dan rekap realtime bawaan.

Dokumen perancangan (di luar repo): konsep aplikasi + rancangan teknis
Firestore (struktur pemilik > acara > pencatat > bundel > amplop,
Auth Opsi A, security rules multi-tenant).

## Auth — Opsi A

- **Pemilik acara**: daftar/masuk dengan email + kata sandi. Membuat
  acara, mendapat kode gabung + PIN, mendaftarkan nama para pencatat.
- **Pencatat**: tanpa email. Gabung dengan kode acara + nama (harus
  sudah didaftarkan pemilik) + PIN acara; di balik layar memakai
  Firebase Anonymous Auth. Setiap pencatat dapat prefix unik
  (A, B, C, ...) dan bundelnya bernomor `A001`, `A002`, ...

## Penyiapan Firebase (sekali, oleh pemilik project)

1. Buat project di [Firebase Console](https://console.firebase.google.com)
   (paket Spark).
2. **Authentication > Sign-in method**: aktifkan **Email/Password** dan
   **Anonymous** (Anonymous wajib untuk pencatat).
3. **Firestore Database**: buat database.
4. **Project settings > Your apps > Android**: daftarkan aplikasi
   dengan nama paket **`id.my.ozinsq.bukuhajatan`**, unduh
   `google-services.json`, letakkan di `android/app/`.
   File ini *tidak* di-commit (sudah di-.gitignore; repo ini publik).
   Tanpa file ini aplikasi tetap bisa dibuka, tetapi menampilkan layar
   "Firebase belum dikonfigurasi".
5. **Firestore Database > Rules**: tempel seluruh isi `firestore.rules`
   dari root repo ini, lalu Publish.

## Menjalankan

```bash
flutter pub get
flutter run
```

## Status batch

- **Batch 1 (fondasi)**: nama paket & label, dependensi Firebase +
  Riverpod, model data, Auth Opsi A, layar Masuk/Daftar Acara/Buat
  Acara/Detail & Kelola Pencatat, `firestore.rules`.
- **Batch 2 (pencatatan)**: layar Pencatatan (bundel aktif n/10, form
  cepat nama–alamat–nominal, jenis Normal/Kosong/Tanpa Nama, dialog
  bundel penuh + bundel baru otomatis), Daftar Bundel + isi bundel,
  indikator sinkron per baris, agregat bundel & acara naik dalam
  batch tulis yang sama. **PENTING: `firestore.rules` berubah di
  Batch 2** (pencatat kini boleh menaikkan agregat acara) — tempel
  ulang seluruh isi `firestore.rules` ke Firebase Console > Firestore
  > Rules > Publish sebelum menguji pencatatan, kalau tidak simpan
  amplop ditolak Rules.
- **Batch 3 (rekap & ekspor)**: layar Rekap dari Detail Acara
  (tombol **Rekap & Ekspor**, khusus pemilik) — total keseluruhan
  realtime, rincian per pencatat & per bundel, pencarian nama tamu,
  dan ekspor **Excel** (format buku: kode bundel tercetak sekali per
  kelompok, sel digabung) serta **CSV** (kode di setiap baris, untuk
  diolah lagi). File dibagikan lewat share sheet Android. Ekspor
  inilah arsip utama acara di paket gratis — simpan baik-baik.
  Batch 3 menambah dependensi (excel, share_plus, path_provider):
  jalankan `flutter pub get` setelah apply patch ini. Rules TIDAK
  berubah di Batch 3.

## Cara uji Batch 3

1. `flutter pub get`, lalu `flutter run` (rules tidak perlu ditempel
   ulang — tidak ada perubahan rules di batch ini).
2. Masuk sebagai pemilik, buka acara tes dari Batch 2 (yang sudah
   berisi bundel-bundel amplop) > **Rekap & Ekspor**.
3. Periksa: total amplop/bundel/Rp sama dengan Detail Acara; rincian
   per pencatat (prefix A) dan per bundel (A001 penuh, A002 terbuka)
   masuk akal; hitungan amplop kosong & tanpa nama cocok.
4. Cari nama salah satu tamu yang dicatat di Batch 2 — harus ketemu,
   lengkap dengan nominal & kode bundelnya. Cari juga potongan
   alamatnya.
5. Ketuk **Excel** — share sheet muncul; kirim file ke WhatsApp/
   Drive, buka di komputer: kode bundel tercetak sekali per kelompok
   10 baris, ada baris TOTAL di bawah. Ulangi untuk **CSV** dan buka
   file-nya (kode bundel ada di setiap baris).

## Cara uji Batch 2

1. Tempel ulang `firestore.rules` (lihat di atas), lalu `flutter run`.
2. Sebagai pemilik: buat acara tes, daftarkan satu pencatat.
3. Keluar, gabung sebagai pencatat (kode + nama + PIN), buka acara
   > **Mulai Mencatat** — bundel `A001` terbuka, posisi `0/10`.
4. Catat 10 amplop (campur: normal, satu Kosong, satu Tanpa Nama).
   Amplop ke-10 memunculkan dialog "Bundel A001 penuh — masukkan ke
   kotak" dan bundel `A002` langsung terbuka di `0/10`.
5. Total di Detail Acara pemilik ikut naik realtime (amplop + Rp).
6. Uji offline: matikan data/Wi-Fi, catat 1 amplop — barisnya
   berpenanda oranye "menunggu sinkron"; hidupkan lagi, penanda
   berubah hijau.
