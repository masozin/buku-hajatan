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
- **Batch 4 (panel admin — Fase 2)**: menu **Panel Admin** di Daftar
  Acara, hanya tampil untuk akun admin. Isi: ringkasan platform
  (total pemilik/acara/amplop/Rp), daftar pemilik + **Blokir /
  Aktifkan**, daftar semua acara. Pemilik terblokir melihat layar
  pemberitahuan dan tidak bisa membuat acara (dijaga aplikasi +
  rules; ia tidak bisa membuka blokirnya sendiri). Email kini
  disimpan di dokumen pemilik (akun lama terisi otomatis saat masuk
  berikutnya). **PENTING: `firestore.rules` berubah di Batch 4** —
  tempel ulang seluruh isinya ke Firebase Console > Firestore >
  Rules > Publish. Tidak ada dependensi baru (tidak perlu pub get).

- **Batch 5 (provisioning admin)**: model berubah menjadi dikelola
  admin — **acara hanya dibuat oleh admin**, pemilik menerima acara
  yang dibuatkan untuknya (satu pemilik bisa punya banyak acara).
  Panel Admin bertambah: **Tambah Pemilik** (admin membuatkan akun:
  nama/email/no HP/kata sandi awal, lewat app Firebase sekunder
  supaya sesi admin tidak tertimpa) dan **Buat Acara** (pilih pemilik
  tujuan, atau dari kartu pemiliknya langsung). Pendaftaran mandiri
  di layar Masuk DITUTUP dan tombol Buat Acara di Daftar Acara
  dihapus. **PENTING: `firestore.rules` berubah di Batch 5** —
  tempel ulang seluruh isinya. Tidak ada dependensi baru.

- **Batch 6 (beranda admin, detail pemilik, koreksi pasca-acara)**:
  admin langsung masuk **Panel Admin** sebagai beranda (ikon rumah
  untuk ke tampilan pemilik, ikon keluar di panel). Kartu pemilik di
  panel bisa diketuk → **Detail Pemilik**: profil, statistik, daftar
  acaranya, dan aksi Buat Acara / **Reset Sandi** (email atur ulang
  dari Firebase) / Blokir; layar Masuk juga punya "Lupa kata sandi?".
  Aturan pantau–koreksi: **selama acara aktif pemilik hanya
  memantau** data amplop; **setelah acara ditandai selesai**, isi
  bundel masuk mode koreksi — pemilik bisa **tambah** (ke bundel
  belum penuh), **ubah**, dan **hapus** amplop, agregat bundel &
  acara menyesuaikan otomatis. Kelola pencatat & tombol Selesaikan
  tetap bisa dipakai selama acara aktif. **PENTING:
  `firestore.rules` berubah di Batch 6** (koreksi pemilik dikunci
  ke status selesai) — tempel ulang seluruh isinya. Tidak ada
  dependensi baru.

- **Batch 7 (kolom dusun/keterangan/waktu, tab Detail Acara, FAB
  catat)**: amplop bertambah kolom **Dusun** (angka, setelah alamat)
  dan **Keterangan** (teks bebas) di form pencatatan & koreksi, ikut
  tampil di baris amplop, daftar pengunjung, dan ekspor (Excel & CSV
  juga mendapat kolom **Waktu** dari timestamp pencatatan yang
  memang sudah tersimpan sejak Batch 2). Detail Acara pemilik
  menjadi dua tab: **Ringkasan** (jumlah Pengunjung & Total Rp,
  kode gabung, kelola pencatat, status) dan **Pengunjung** (semua
  amplop lintas bundel, ada pencarian nama/alamat/dusun/keterangan
  dan urutan: bundel, nama, nominal, dusun, terbaru/terlama; data
  dibaca sekali jalan + tombol muat ulang). **Tombol catat
  melayang**: acara AKTIF → hanya pencatat yang melihatnya (Catat
  Amplop); acara SELESAI → hanya pemilik (Catat Koreksi, pilih
  bundel belum penuh dulu). Bagian "Saya Ikuti sebagai Pencatat"
  di beranda disembunyikan untuk sesi pemilik (tetap ada untuk
  sesi anonim pencatat, karena itu beranda mereka). Rules TIDAK
  berubah di batch ini; tidak ada dependensi baru.

## Cara uji Batch 7

1. `flutter run` (tanpa tempel rules). Sebagai pencatat di acara
   aktif: tombol melayang **Catat Amplop** tampil di Detail Acara;
   catat satu amplop mengisi Dusun (angka) & Keterangan — keduanya
   tampil di baris isi bundel.
2. Sebagai pemilik di acara AKTIF yang sama: Detail Acara kini
   bertab; tab Pengunjung menampilkan semua amplop — coba cari
   berdasarkan dusun ("dusun 1") dan urutkan Nominal terbesar.
   Tombol catat TIDAK tampil untuk pemilik.
3. Tandai acara Selesai → tombol **Catat Koreksi** muncul untuk
   pemilik (dan hilang dari pencatat); ketuk → pilih bundel belum
   penuh → tambah amplop koreksi dengan dusun & keterangan.
4. Ekspor Excel & CSV dari Rekap: kolom Dusun, Keterangan, Waktu
   terisi.
5. Beranda pemilik tidak lagi menampilkan bagian "Saya Ikuti
   sebagai Pencatat"; masuk sebagai pencatat (anonim) bagian itu
   tetap ada.

## Cara uji Batch 6

1. Tempel ulang rules, lalu `flutter run`. Masuk sebagai admin →
   langsung mendarat di Panel Admin (bukan Daftar Acara).
2. Ketuk kartu seorang pemilik → Detail Pemilik: daftar acaranya
   tampil; coba **Reset Sandi** → email atur ulang harus tiba di
   kotak masuk pemilik itu.
3. Uji koreksi: pakai acara tes yang masih AKTIF — sebagai pemilik
   buka Detail Acara > Lihat Semua Bundel > buka satu bundel:
   tampil kartu "Mode memantau", tidak ada tombol ubah/hapus.
4. Tandai acara itu **Selesai** (Detail Acara), buka lagi bundel
   yang sama: kartu berubah "Mode koreksi aktif". Coba: ubah
   nominal satu amplop (total bundel & Rekap harus bergeser sama),
   hapus satu amplop (jumlah berkurang; bundel penuh yang terhapus
   isinya terbuka lagi), tambah satu amplop ke bundel yang belum
   penuh.
5. Buka Rekap & ekspor Excel: angka akhirnya harus cocok dengan
   hasil koreksi.

## Cara uji Batch 5

1. Tempel ulang rules, lalu `flutter run`.
2. Sebagai admin: Panel Admin > **Tambah Pemilik** — buat akun tes
   (mis. "Pemilik Tes", email tes, kata sandi awal 6+ karakter).
   Dialog sukses muncul dan kamu TETAP masuk sebagai admin (tidak
   tertimpa sesi akun baru).
3. Panel Admin > **Buat Acara** — pilih pemilik tes tadi, isi form,
   simpan. Acara muncul di daftar Semua Acara panel dengan pemilik
   yang benar, lengkap dengan kode gabungnya.
4. Keluar, masuk dengan akun pemilik tes: acara yang dibuatkan
   admin tampil di "Acara Saya"; TIDAK ada tombol Buat Acara;
   pemilik tetap bisa mengelola acaranya (tambah pencatat, rekap,
   ekspor) seperti biasa.
5. Di layar Masuk, tab Pemilik tidak lagi menawarkan pendaftaran.

## Menjadikan akunmu admin (sekali saja, Batch 4)

1. Tempel ulang `firestore.rules` (lihat di atas), lalu jalankan
   aplikasi dan masuk sebagai pemilik dengan akun yang akan jadi
   admin, supaya dokumen profilnya ada.
2. Di Firebase Console > **Authentication > Users**: temukan akun
   itu, salin **User UID**-nya.
3. Di **Firestore Database > Data**: klik **Start collection**,
   Collection ID: `admin`, Next. Document ID: tempel UID tadi.
   Tambah satu field bebas, mis. field `nama`, type string, value
   `Admin`. Klik **Save**.
4. Kembali ke aplikasi (tutup-buka bila perlu): ikon **Panel Admin**
   (perisai) muncul di kanan atas Daftar Acara, di samping tombol
   Keluar.

## Cara uji Batch 4

1. Tempel ulang rules + buat dokumen admin (langkah di atas), lalu
   `flutter run`.
2. Masuk dengan akun admin → ikon Panel Admin muncul. Buka: angka
   ringkasan & daftar pemilik/acara harus cocok dengan data tes
   selama ini (email pemilik muncul setelah ia masuk sekali lagi
   dengan versi baru ini).
3. Uji blokir: daftarkan akun pemilik KEDUA (atau pakai akun tes),
   lalu dari Panel Admin blokir akun itu. Di HP/sesi akun itu,
   aplikasi menampilkan layar "Akun Diblokir" dan Buat Acara
   ditolak server. Aktifkan lagi dari panel — aksesnya pulih.
4. Masuk dengan akun BUKAN admin: ikon Panel Admin tidak boleh
   muncul.

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
