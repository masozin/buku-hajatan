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

- **Perbaikan gabung pencatat (2026-11-17)**: bug — gabung dari
  tab Pencatat di layar Masuk tidak pernah berhasil diam-diam:
  form masuk anonim dulu, gerbang langsung menukar layar ke
  Daftar Acara begitu sesi muncul, form hancur sebelum klaim
  undangan berjalan (dokumen pencatat tidak pernah dibuat, galat
  tidak pernah tampil) sehingga beranda menyatakan "belum
  mengikuti acara apa pun". Sekarang tab Pencatat hanya membuat
  sesi anonim; pencatat yang belum mengikuti acara mendarat di
  form gabung sebagai berandanya (galat PIN/nama tampil normal),
  dan begitu klaim berhasil gerbang berpindah ke Daftar Acara
  sendiri. Rules tidak berubah, tidak ada dependensi baru.

## Cara uji perbaikan gabung

1. Keluar dari semua sesi. Di layar Masuk, tab Pencatat → ketuk
   **Masuk sebagai Pencatat** → kamu mendarat di form Gabung Acara.
2. Isi kode + nama terdaftar + PIN yang BENAR → berhasil masuk,
   acara tampil di beranda.
3. Ulangi dari awal (keluar dulu) dengan PIN SALAH → pesan "PIN
   acara salah." harus TAMPIL di form (tidak lagi hilang), dan
   kamu tetap di form, bisa langsung betulkan.

## Batch 8 — Edit oleh penginput, masuk langsung ke panel, halaman bersih

**WAJIB tempel ulang `firestore.rules`** sesudah menerapkan patch
ini (aturan ubah amplop berubah).

1. **Tombol edit per amplop.** Pencatat kini bisa mengubah amplop
   yang IA input sendiri selama acara masih aktif (pensil di tiap
   baris pada layar Pencatatan dan di Isi Bundel miliknya) — untuk
   membetulkan salah ketik di tempat. Total bundel & acara
   menyesuaikan sebesar selisihnya. Hapus tetap tidak bisa untuk
   pencatat. Sesudah acara selesai, hak ubah berpindah ke pemilik
   (mode koreksi Batch 6, tidak berubah).
2. **Pencatat langsung ke panelnya.** Pencatat yang hanya mengikuti
   satu acara langsung masuk ke panel acara itu setelah masuk —
   tidak perlu mengetuk daftar dulu. Mengikuti lebih dari satu
   acara tetap memilih dari daftar. Panel pencatat kini punya
   tombol Keluar sendiri.
3. **Halaman pemilik lebih bersih.** Di tab Ringkasan, bagian
   "Kode Gabung & PIN Pencatat" dan "Pencatat" sekarang terlipat —
   ketuk judulnya untuk membuka isinya.

## Cara uji Batch 8

1. Sebagai pencatat di acara aktif: catat satu amplop, lalu ketuk
   pensil di barisnya → ubah nominal/nama → tersimpan, dan total
   bundel berubah sebesar selisihnya.
2. Coba ubah amplop dari bundel pencatat LAIN (lewat Isi Bundel):
   tidak ada tombol ubah.
3. Keluar, lalu masuk lagi sebagai pencatat yang hanya ikut satu
   acara: langsung tiba di panel acara itu.
4. Sebagai pemilik: tab Ringkasan tampil ringkas; ketuk "Kode
   Gabung & PIN Pencatat" dan "Pencatat" untuk membuka isinya.
5. Tandai acara selesai: tombol ubah pencatat hilang; koreksi
   pemilik berjalan seperti sebelumnya.

## Batch 9 — Reset gabung pencatat, Pengunjung bisa diketuk, tab Bundel

Patch ini **TIDAK mengubah `firestore.rules`** — tidak perlu
tempel ulang rules.

1. **Lepas HP (reset gabung).** Di bagian Pencatat (tab Ringkasan,
   buka lipatannya), tiap pencatat yang sudah bergabung kini punya
   tombol ikon HP: melepas ikatan HP lamanya. Sesudah dilepas,
   orangnya bisa bergabung lagi dari HP baru dengan kode + PIN +
   nama yang sama. Bundel & amplop yang sudah ia catat TIDAK ikut
   terhapus, dan nomor bundel berikutnya disambung dari bundel
   terakhir prefix-nya (tidak ada kode bundel kembar).
2. **Pengunjung bisa diketuk.** Ketuk satu nama di tab Pengunjung
   → muncul pratinjau data lengkapnya. Bila acara sudah selesai,
   ada tombol **Ubah Amplop** yang membuka form koreksi langsung
   dari situ.
3. **Tab Bundel baru** di samping tab Pengunjung (tombol "Lihat
   Semua Bundel" di Ringkasan dihapus): tiap bundel tampil sebagai
   dropdown berisi kode bundel, jumlah amplop, total Rp, dan nama
   pencatatnya — ketuk untuk membuka daftar pengunjung di
   dalamnya. Setelah acara selesai, baris di dalam dropdown ikut
   bisa diubah/dihapus, dan ada "Tambah amplop ke bundel ini"
   untuk bundel yang belum penuh.

## Cara uji Batch 9

1. Pemilik: buka lipatan Pencatat → pada pencatat yang sudah
   bergabung ketuk ikon HP → konfirmasi. Lalu dari HP lain (atau
   setelah keluar) gabung lagi dengan nama itu: harus berhasil,
   dan bundel barunya menyambung nomor terakhir prefix-nya.
2. Ketuk satu nama di tab Pengunjung → pratinjau tampil; pada
   acara yang sudah selesai, ketuk Ubah Amplop → ubah nominal →
   total berubah.
3. Buka tab Bundel: tiap bundel tampil ringkas; ketuk satu bundel
   → daftar pengunjungnya terbuka.

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
   penuh. Uji tambahan: hapus amplop di TENGAH bundel (mis. urut 5
   dari bundel penuh), lalu tambah penggantinya — amplop baru harus
   memakai nomor 5 yang kosong, bukan duplikat nomor 10.
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

## Batch 10 — Identitas pencatat tetap + PIN pribadi + kunci sesi

Identitas pencatat tidak lagi menempel ke HP. Pencatat kini punya
catatan tetap atas namanya dan **PIN pribadi** sendiri; ia bisa
masuk dari perangkat mana pun dengan **kode acara + nama + PIN
pribadi** (PIN acara bersama tidak lagi dipakai untuk gabung).
Satu nama hanya boleh dipegang **satu perangkat dalam satu waktu**
(kunci sesi): perangkat kedua **ditolak** sampai perangkat pertama
keluar, atau pemilik menekan **Reset Sesi**. Karena identitasnya
tetap, bundel-bundelnya selalu tampil sebagai miliknya — ganti HP
tidak lagi mengosongkan daftar Bundel Saya.

**WAJIB — 2 langkah di Firebase Console setelah menerapkan patch:**

1. **Tempel ulang `firestore.rules`** (Firestore Database → Rules
   → Edit rules → tempel seluruh isi file → Publish). Rules lama
   tidak mengenal dokumen sesi dan akan menolak pencatatan model
   baru.
2. **Buat pengecualian indeks baru** untuk query "acara yang saya
   ikuti" model baru: Firestore Database → **Indexes** → tab
   **Single field** → **Add exemption**: Collection ID `pencatat`,
   Field `uidAktif`, centang **Collection group**, Ascending →
   Save. (Persis seperti pengecualian `userId` dulu; yang lama
   boleh dibiarkan.)

**Yang berubah di aplikasi:**

- Form gabung: kolom PIN kini **PIN Pribadimu**.
- Pemilik mendaftarkan pencatat: ada kolom PIN pribadi — kosongkan
  untuk dibuatkan otomatis (PIN tampil di pesan setelah menambah
  dan di daftar pencatat; bagikan ke orangnya). Ikon kunci di tiap
  baris untuk mengatur/mengganti PIN pribadi.
- Tombol **Lepas HP** digantikan **Reset Sesi**: melepas kunci
  sesi dari perangkat yang memegangnya. Identitas, bundel, dan
  amplop pencatat tidak berubah sama sekali.
- Keluar dari aplikasi kini melepas sesi perangkat ini dulu —
  jadi pencatat yang keluar bisa langsung masuk dari HP lain.
- Menonaktifkan pencatat juga memutus sesinya seketika.
- Kartu "Kode Gabung & PIN Pencatat" kini hanya menampilkan kode;
  PIN pribadi tiap pencatat ada di bagian Pencatat.

**Catatan migrasi data yang sudah ada:**

- Pencatat yang **sedang masuk** di HP-nya tetap bisa mencatat
  seperti biasa — sesinya dikenali otomatis oleh versi baru.
- Undangan & pencatat lama **belum punya PIN pribadi**: sebelum
  orangnya bisa masuk dari perangkat lain, pemilik mengatur PIN
  pribadinya dulu lewat ikon kunci di bagian Pencatat.
- Bila sesi lama tertinggal (mis. HP lama sudah tidak dipakai),
  pemilik menekan **Reset Sesi** — setelah itu orangnya masuk
  dengan nama + PIN pribadinya dari HP mana pun.

## Cara uji Batch 10

1. Terapkan patch → tempel ulang rules → buat pengecualian indeks
   `uidAktif` (langkah Console di atas) → `flutter run`.
2. Pemilik: daftarkan pencatat baru — pesan setelah menambah
   menampilkan PIN pribadinya. Pencatat gabung dari HP dengan
   kode + nama + PIN pribadi itu: berhasil, mencatat seperti biasa.
3. Tanpa keluar dari HP pertama, coba gabung dengan nama + PIN
   yang sama dari perangkat/sesi lain: harus **ditolak** dengan
   pesan sesi sedang dipakai perangkat lain.
4. Keluar dari HP pertama, lalu gabung lagi dari perangkat kedua:
   harus berhasil, dan daftar **Bundel Saya** menampilkan
   bundel-bundel yang dicatat dari HP pertama (tidak kosong).
5. Pemilik: tekan **Reset Sesi** pada pencatat yang sedang masuk
   di HP pertama → HP pertama tidak bisa mencatat lagi (pesan
   sesi), dan orangnya bisa masuk dari perangkat lain.
6. Pemilik: ubah PIN pribadi lewat ikon kunci → PIN lama ditolak,
   PIN baru diterima.

## Perbaikan Batch 10 — sesi ditulis atomik dengan klaim

Gejala: gabung pencatat pertama tampak berhasil, tetapi tepat
sesudahnya muncul `cloud_firestore/permission-denied`. Sebabnya:
dokumen sesi semula ditulis TERPISAH sesudah batch klaim, jadi ada
sesaat ketika dokumen pencatat sudah terbaca daftar "acara yang
saya ikuti" tetapi rules belum mengakui sesinya — baca dokumen
acara pun ditolak, dan error itu menempel di layar.

Perbaikan: dokumen sesi kini ditulis di dalam batch yang sama
dengan klaim/ambil-sesi/migrasi (atomik), rules sesi tidak lagi
bergantung pada pemeriksaan silang dokumen lain, dan daftar
keikutsertaan melewati acara yang sesaat gagal dibaca alih-alih
gagal seluruhnya. **Tempel ulang `firestore.rules`** setelah
menerapkan perbaikan ini; indeks tidak berubah.

## Batch 11 — Tab Pengunjung & Bundel untuk pencatat

Patch ini **TIDAK mengubah `firestore.rules`** — tidak perlu
tempel ulang rules, tidak ada indeks baru.

Halaman Detail Acara pencatat kini memakai tiga tab seperti
pemilik: **Ringkasan** (seperti sebelumnya), **Pengunjung**, dan
**Bundel**.

1. **Tab Pengunjung (pencatat):** menampilkan SEMUA pengunjung
   yang tercatat di acara (lintas pencatat), lengkap dengan
   pencarian & urutan seperti di halaman pemilik. Ketuk satu nama
   untuk melihat pratinjau lengkapnya — tombol **Ubah Amplop**
   hanya muncul untuk amplop yang **ia input sendiri** dan hanya
   selama acara masih aktif. Pratinjau catatan pencatat lain
   diberi catatan bahwa ia hanya bisa melihatnya; setelah acara
   selesai, pengubahan sepenuhnya lewat pemilik.
2. **Tab Bundel (pencatat):** dropdown per bundel seperti di
   halaman pemilik (kode, jumlah amplop, total Rp, isi daftar
   pengunjung), tetapi hanya menampilkan **bundel miliknya**.
   Selama acara aktif, amplop di dalamnya bisa diubah (pensil) —
   tanpa hapus dan tanpa tambah koreksi, sesuai hak pencatat.

## Cara uji Batch 11

1. Masuk sebagai pencatat → Detail Acara kini bertab tiga.
2. Tab Pengunjung: semua pengunjung lintas pencatat tampil.
   Ketuk pengunjung inputanmu → ada tombol Ubah Amplop → ubah
   nominal → total berubah. Ketuk pengunjung inputan pencatat
   lain → hanya pratinjau + catatan, tanpa tombol ubah.
3. Tab Bundel: hanya bundel milikmu yang tampil; buka dropdown
   satu bundel → daftar pengunjungnya tampil dan bisa diubah
   selama acara aktif.

## Batch 12 — Rombak tampilan (sistem desain zamrud & emas)

Patch ini mengubah **tampilan saja** — tidak ada perubahan
perilaku, data, rules, atau dependensi. **Tidak perlu tempel
ulang `firestore.rules`, tidak ada indeks baru.** Cukup terapkan
patch lalu `flutter run` (pubspec berubah: font kini dibundel
sebagai aset, jadi jalankan `flutter pub get` bila diminta).

Bahasa desain baru:

1. **Warna zamrud & emas.** Hijau zamrud untuk kepercayaan
   (urusan uang titipan), emas seperlunya untuk aksen hajatan:
   lencana "Penuh", penanda menunggu sinkron, statistik amplop
   kosong/tanpa nama.
2. **Font Plus Jakarta Sans** dibundel di dalam aplikasi
   (5 bobot), jadi tetap tampil walau tanpa jaringan.
3. **Tema gelap** mengikuti setelan perangkat — buka aplikasi
   malam hari tidak lagi silau.
4. **Komponen seragam:** kartu bersudut 20 dengan garis tepi
   tipis (tanpa bayangan keras), tombol utama berbentuk pil,
   kolom isian terisi lembut bersudut 14, tab berbentuk pil,
   dialog & lembar bawah bersudut 24.
5. **Kartu sorotan gradasi** untuk angka terpenting: total
   acara di Detail & Rekap (dengan jumlah pengunjung, bundel,
   dan rata-rata per amplop), serta bundel aktif di layar
   pencatatan (kode besar + batang kemajuan + total bundel).
6. **Sentuhan per layar:** layar Masuk berkepala logo & tagline
   dengan pemilih peran berbentuk pil; kartu acara berisi ikon
   meta + total ditegaskan + lencana status berwarna; daftar
   pengunjung memakai avatar inisial; rincian per pencatat di
   Rekap kini ada batang proporsinya; keadaan kosong/galat
   memakai ikon dalam lingkaran lembut.

## Cara uji Batch 12

1. Jalankan aplikasi — layar Masuk tampil berlogo, font dan
   warna baru terasa di semua layar.
2. Kelilingi alur utama: Daftar Acara → Detail (kartu total
   gradasi) → Catat Amplop (kartu bundel gradasi, kolom nominal
   besar) → Rekap (batang proporsi per pencatat).
3. Aktifkan mode gelap di setelan HP → aplikasi ikut gelap dan
   tetap terbaca.
4. Pastikan semua tombol/form berperilaku sama seperti
   sebelumnya — batch ini murni tampilan.

## Batch 13 — Penyesuaian tampilan & alur pencatat

Menindaklanjuti uji visual Batch 12 oleh Mark. **Tidak ada
perubahan rules, data, atau dependensi.** Isinya:

1. **Pemilik:** kartu "Kode Gabung & PIN Pencatat" (dropdown)
   dihapus — kode gabung + tombol salin kini langsung tampil di
   kartu info acara, di bawah tanggal, tanpa keterangan.
   Dropdown Pencatat: avatar huruf inisial dihapus, dan semua
   label "PIN pribadi" menjadi "PIN" saja.
2. **Pencatat:** tombol & layar "Daftar Bundel Saya" dihapus
   (termasuk layar Isi Bundel lama) — sudah digantikan tab
   Bundel. Tombol melayang "Catat Amplop" kini ikon saja.
3. **Perbaikan keluar dua kali:** keluar dari panel pencatat
   dulu bisa berhenti di halaman gabung (harus keluar sekali
   lagi), karena pemeriksaan `mounted` membatalkan proses
   keluar begitu gerbang menukar layar. Kini sekali keluar
   langsung ke halaman masuk utama.
4. **Login pencatat otomatis:** membuka tab Pencatat di halaman
   Masuk langsung membuat sesi — tidak ada tombol perantara
   lagi (tombol tetap tampil sebagai jalan mencoba ulang bila
   pembuatan sesi gagal).
5. **Kartu total:** statistik rata-rata dihapus; tersisa
   Pengunjung & Bundel.
6. **Tab Pengunjung:** tampilan bawaan Terbaru; pilihan urutan
   Bundel & Dusun dihapus, diganti urutan **Desa** (berdasarkan
   alamat). Baris per pengunjung tanpa avatar inisial: di bawah
   nama hanya alamat + dusun; sisi kanan berisi nominal, kode
   bundel-urut (mis. A001-1), dan cap waktu — hari yang sama
   cukup jamnya, beda tanggal tampil tanggal + jam.
7. **Tab Bundel:** kepala dropdown cukup "KODE • Rp total",
   di bawahnya "Pencatat: ..." dan batang kemajuan — tanpa
   kotak inisial, tanpa kata "Bundel", tanpa lencana Penuh.
   Isi dropdown: nomor urut sebagai angka biasa, di bawah nama
   hanya alamat + dusun.

## Cara uji Batch 13

1. Sebagai pemilik: kode gabung + tombol salin ada di kartu
   info acara; bagian Pencatat tanpa huruf inisial, labelnya
   "PIN".
2. Sebagai pencatat: buka tab Pencatat di halaman Masuk —
   langsung diarahkan ke form gabung (tanpa tombol). Di panel
   acara tidak ada lagi tombol Daftar Bundel Saya; tombol
   melayang hanya ikon.
3. Keluar dari panel pencatat → langsung tiba di halaman
   Masuk utama, cukup SEKALI.
4. Tab Pengunjung: bawaan Terbaru, ada urutan Desa; barisnya
   ringkas dengan kode-urut + jam di kanan. Tab Bundel: kepala
   dropdown ringkas seperti di atas.

## Batch 14 — Form gabung di tab + perbaikan kolom isian

**Tidak ada perubahan rules, data, atau dependensi.**

1. **Login pencatat tanpa halaman baru:** form gabung (kode +
   nama + PIN) kini LANGSUNG di tab Pencatat pada layar Masuk.
   Gerbang menahan sesi anonim yang belum mengikuti acara di
   layar Masuk (tab Pencatat terbuka), jadi form tidak hancur
   saat sesi dibuat — bug gabung lama tidak terulang. Di tab
   yang sama ada tombol "Keluar sesi pencatat" untuk yang batal
   bergabung.
2. **Baris pengunjung tidak lagi meluap:** tulisan "bottom
   overflowed" dari Batch 13 hilang — baris pengunjung memakai
   tata letak bebas (bukan ListTile) sehingga kolom kanan
   (nominal, kode-urut, waktu) muat berapa pun tingginya.
3. **Kolom Dusun bertombol − / +:** tiap ketuk mengubah angka
   sebanyak 1; dari kosong + mengisi 1, dari 1 − mengosongkan.
   Berlaku di form catat dan form koreksi/ubah.
4. **Sugesti alamat:** kolom Alamat menawarkan alamat yang
   pernah dipakai DI ACARA ITU — mengetik "c" menampilkan
   alamat berawalan c (atau yang salah satu katanya berawalan
   c, mis. "Cahya Tani"); ketuk untuk memakai. Alamat yang baru
   disimpan langsung ikut menjadi sugesti berikutnya.
5. **Nominal dalam ribu saat input:** di form Catat Amplop dan
   form Tambah (koreksi), nominal diketik dalam ribu — 50
   berarti Rp 50.000 — dengan pratinjau "= Rp 50.000" di bawah
   kolom. Form UBAH tetap memakai angka penuh seperti biasa.

## Cara uji Batch 14

1. Keluar total, buka tab Pencatat: form gabung langsung ada
   di sana. Isi dengan PIN salah → pesan galat tampil di form;
   betulkan → berhasil masuk.
2. Tab Pengunjung: tidak ada lagi tulisan overflow; alamat
   tampil di bawah nama untuk amplop yang alamatnya terisi.
3. Form catat: tombol − / + di kolom Dusun bekerja; ketik "c"
   di Alamat → sugesti alamat acara muncul; ketik nominal 50 →
   pratinjau "= Rp 50.000" dan hasil simpan Rp 50.000.
4. Buka form Ubah Amplop: nominal tampil & tersimpan sebagai
   angka penuh (tidak dikali 1000).

## Batch 15 — Nama urutan "Alamat" + isi bundel terbaru di atas

Dua penyesuaian kecil (tanpa perubahan rules/data/dependensi):

1. Pilihan urutan **Desa** di tab Pengunjung diganti namanya
   menjadi **Alamat** (cara urutnya sama: berdasarkan alamat,
   yang kosong paling belakang).
2. Di layar pencatatan, daftar **Isi bundel** kini urut dari
   yang terbaru: nomor urut terbesar di atas, nomor 1 paling
   bawah — amplop yang baru diinput langsung terlihat tanpa
   menggulir.

## Batch 16 — Logo & ikon aplikasi

Logo resmi Buku Hajatan: dua tamu di belakang buku terbuka
dengan pena emas, berwarna zamrud & emas sesuai tema.

1. **Ikon launcher Android diganti** dari ikon bawaan Flutter:
   ikon *legacy* (ic_launcher.png semua kepadatan) untuk Android
   lama, dan **ikon adaptif** (Android 8+) — latar warna zamrud
   #074C3C (disampling dari latar karya logo) + foreground logo
   yang diskalakan 92% agar aman dari masker lingkaran/squircle
   launcher. Manifest kini juga memasang `roundIcon`.
2. **Logo di dalam aplikasi**: `LogoAplikasi` di layar Masuk kini
   menampilkan gambar logo — versi terang di tema terang, versi
   zamrud di tema gelap. Berkas induk ada di `assets/icon/`
   (logo_terang.png & logo_zamrud.png, 1024×1024).

## Cara uji Batch 16

1. `flutter run`, lalu keluar ke layar utama HP: ikon Buku
   Hajatan sudah menjadi logo buku + pena (bukan lagi ikon
   Flutter). Bila ikon lama masih tampil, hapus instalan lama
   dulu / bersihkan cache launcher — ikon kadang tersimpan di
   cache launcher.
2. Buka aplikasi: logo di atas tulisan "Buku Hajatan" pada layar
   Masuk sudah berganti logo baru (terang; atau zamrud bila HP
   memakai mode gelap).

## Batch 17 — Ikon launcher memakai logo terang

Menindaklanjuti Batch 16: ikon di layar HP kini memakai logo
**versi terang** (bukan zamrud). Agar seluruh logo selalu
terlihat utuh apa pun bentuk ikon launcher (lingkaran,
squircle, tetes air, dsb.), foreground ikon adaptif diskalakan
ke **72%** di tengah kanvas — seluruh gambar berada di zona
aman masker — dengan latar warna kertas #FBF3E9 yang disampling
dari latar karya logo. Ikon legacy semua kepadatan juga dibuat
ulang dari logo terang. Logo di dalam aplikasi tidak berubah
(terang/zamrud mengikuti tema).

## Cara uji Batch 17

1. `flutter run`, keluar ke layar utama: ikon Buku Hajatan
   tampil terang dan utuh (tidak ada bagian terpotong).
2. Bila launcher HP-mu menyediakan pilihan bentuk ikon (tema
   ikon), ganti-ganti bentuknya: logo tetap terlihat semua.

## Batch 18 — Sesi pencatat dibuat saat Gabung ditekan

Menindaklanjuti Batch 13/14: sesi anonim kini TIDAK lagi dibuat
otomatis saat tab Pencatat dibuka, melainkan oleh form saat
tombol **Gabung** ditekan. Agar cara malas ini tidak menghidupkan
bug gabung lama, gerbang direstrukturisasi menjadi
`_GerbangMasuk` (main.dart): satu widget yang melayani keadaan
belum masuk dan sesi anonim, selalu membungkus layar Masuk
dalam StreamBuilder yang sama — subtree layar Masuk tidak
dibangun ulang saat sesi dibuat, jadi isi form dan pesan galat
klaim (mis. PIN salah) tetap tampil. Tombol "Keluar sesi
pencatat" kini hanya muncul bila memang ada sesi anonim (mis.
setelah percobaan gabung). Tanpa perubahan rules/data.

## Cara uji Batch 18

1. Pindah tab Pemilik → Pencatat berulang kali: tidak ada muat
   ulang layar, dan tidak ada tombol "Keluar sesi pencatat".
2. Isi form gabung dengan PIN yang SALAH lalu tekan Gabung:
   pesan galat tampil di form dan isianmu TIDAK hilang.
3. Betulkan PIN, tekan Gabung lagi: berhasil masuk ke acara.
4. Keluar sebagai pencatat, buka aplikasi lagi dari awal
   (paksa berhenti dulu): pencatat yang sudah punya acara tetap
   langsung masuk ke acaranya (layar muat sebentar, tanpa
   kedipan layar Masuk).

## Batch 19 — PIN pencatat selalu dibuatkan otomatis

Form tambah pencatat di Kelola Pencatat tidak lagi punya kolom
PIN: PIN pribadi SELALU dibuatkan acak 4 digit oleh aplikasi
dan ditampilkan di pemberitahuan setelah pencatat ditambahkan
("… — PIN: 1234. Bagikan ke orangnya.") serta di daftar pencatat.
Pemilik tetap bisa MENGGANTI PIN sesudahnya lewat ikon kunci
(atur PIN) — PIN baru berlaku untuk gabung berikutnya; sesi
pencatat yang sedang aktif tidak terganggu dan datanya tidak
berubah. Tanpa perubahan rules/data.

## Cara uji Batch 19

1. Kelola Pencatat → tambah nama baru: tidak ada lagi kolom
   PIN; setelah menekan Tambah, pemberitahuan menampilkan PIN
   yang dibuatkan.
2. Gabung sebagai pencatat itu dengan PIN dari pemberitahuan:
   berhasil.
3. Ganti PIN-nya lewat ikon kunci selagi pencatat itu sedang
   aktif di perangkat lain: perangkat itu tetap bisa mencatat;
   setelah keluar, gabung lagi harus memakai PIN baru.

## Batch 20 — Dialog status, bundel khusus pemilik, kata "pengunjung", Rekap per alamat

Lima perubahan:

1. **Dialog konfirmasi ganti status acara.** Menekan "Tandai Acara
   Selesai" atau "Aktifkan Kembali" kini membuka dialog yang
   menjelaskan apa yang akan terjadi (pencatat berhenti bisa
   mencatat; koreksi pemilik dibuka/ditutup; dst) — status hanya
   berubah setelah pemilik menekan tombol konfirmasi.
2. **Bundel khusus pemilik (kode PM).** Koreksi "Catat Koreksi"
   kini masuk ke bundel milik pemilik sendiri — prefix `PM`
   (PM001, PM002, …), dibuat otomatis saat pertama dibutuhkan dan
   dibuka lagi setelah penuh — TIDAK lagi bercampur ke bundel
   pencatat. Di dalam form, pemilik tetap bisa mengganti ke bundel
   lain yang belum penuh; tambah per bundel dari tab Bundel juga
   tetap ada. Di tab Bundel bundel ini berlabel "Pemilik acara";
   di Rekap Per Pencatat tampil sebagai "Pemilik". **WAJIB tempel
   ulang firestore.rules** (aturan buat bundel bertambah cabang
   pemilik) — tanpa itu pembuatan bundel PM ditolak
   (permission-denied).
3. **Kata "amplop" → "pengunjung"** di seluruh teks yang terlihat
   pengguna: tombol, judul, pesan, sampai ekspor (sheet Excel
   "Buku Pengunjung", judul "REKAP PENGUNJUNG"). Nama field data
   di Firestore TIDAK berubah — data lama aman.
4. **FAB koreksi pemilik ikon saja** (sebelumnya tombol panjang
   "Catat Koreksi"), sama seperti FAB pencatat.
5. **Rekap diperbaiki:** kartu statistik "Kosong"/"Tanpa Nama"
   disusun menumpuk (peringatan "height overflowed" hilang);
   bagian "Per Bundel" diganti **"Per Alamat"** (pengunjung
   dikelompokkan per alamat: jumlah + total, terbesar dulu, tanpa
   alamat paling akhir); **pencarian di Rekap dihapus** (sudah ada
   di tab Pengunjung).

## Cara uji Batch 20

0. Tempel ulang firestore.rules di Firebase Console, Publish.
1. Tandai acara selesai → dialog penjelasan muncul; Batal tidak
   mengubah apa pun; "Tandai Selesai" mengubah status. Aktifkan
   kembali → dialog versi sebaliknya.
2. Setelah selesai, ketuk FAB koreksi (ikon saja): form membuka
   dengan tujuan bundel **PM001**. Simpan satu pengunjung →
   tab Bundel menampilkan PM001 berlabel "Pemilik acara".
   Isi sampai 10 → koreksi berikutnya membuka PM002.
3. Kata "pengunjung" tampil di tombol/judul/pesan (mis. "Catat
   Pengunjung", "Simpan Pengunjung", ekspor Excel sheet
   "Buku Pengunjung").
4. Rekap: tidak ada lagi kartu pencarian; ada bagian "Per
   Alamat"; kartu Kosong/Tanpa Nama tampil tanpa peringatan
   overflow (garis kuning-hitam) di bagian bawah layar.

## Batch 21 — Aplikasi memeriksa pembaruan sendiri (GitHub Releases)

Sekali setiap aplikasi dibuka, aplikasi bertanya ke GitHub
Releases repo ini apakah ada rilis lebih baru dari versi yang
terpasang. Bila ada: dialog "Ada Pembaruan Aplikasi" (versi baru
+ catatan rilis) dengan tombol **Unduh Sekarang** (membuka unduhan
APK di browser) dan **Nanti Saja**. Pemeriksaan gagal (offline
dsb.) diam saja. Versi aplikasi naik ke **1.1.0+2**.

Aturan main merilis (PENTING, ikuti persis):

1. Naikkan `version:` di pubspec.yaml (angka di belakang `+`
   WAJIB selalu naik — itu yang dibandingkan).
2. Build APK rilis, buat release di GitHub dengan **tag = `v` +
   versi pubspec persis** (mis. `v1.1.0+2`), lampirkan file
   APK-nya sebagai aset, Publish sebagai rilis penuh (bukan
   pre-release/draft — endpoint "latest" mengabaikannya).
3. Bila sebuah rilis WAJIB dipasang semua orang (mis. perubahan
   model data), tulis penanda **[WAJIB]** di catatan rilisnya:
   dialog pembaruannya tidak bisa ditunda/ditutup.
4. Catatan rilis tampil apa adanya di dialog — tulis ringkas
   dengan bahasa pengguna.

Sekali ini saja pemasangan versi 1.1.0 masih manual (aplikasi
lama belum punya pemeriksa); setelah itu pembaruan terdeteksi
sendiri. Batch ini juga menambahkan **izin INTERNET ke manifest
utama** — tanpa itu APK rilis tidak bisa online sama sekali
(selama ini terbantu manifest debug milik `flutter run`).

## Cara uji Batch 21

1. `flutter pub get` (ada 2 dependensi baru), lalu pasang build
   dari patch ini ke HP seperti biasa.
2. Di GitHub repo ini: buat release UJI dengan tag `v9.9.9+99`,
   lampirkan APK apa pun sebagai aset, Publish.
3. Buka aplikasi → dalam beberapa detik dialog pembaruan muncul
   menawarkan versi 9.9.9; "Nanti Saja" menutupnya; buka lagi
   aplikasi dan ketuk "Unduh Sekarang" → browser membuka unduhan.
4. Hapus release uji itu di GitHub → aplikasi kembali tenang.

## Batch 22 — Tanda tangan rilis (keystore)

Gradle kini membaca `android/key.properties` (lokal, tidak ikut
git; contoh di `android/key.properties.example`): bila file itu
ada, build rilis ditandatangani keystore tersebut; bila belum
ada, tetap kunci debug seperti sebelumnya. Langkah membuat
keystore + merilis ke GitHub Releases ada di panduan terpisah
(panduan-rilis-github-buku-hajatan.md, dibagikan ke Mark).
Yang diunggah ke GitHub Releases adalah APK UNIVERSAL hasil
`flutter build apk --release` (satu file), bukan split per ABI.
- Batch 23: perbaiki layar merah saat dialog Atur PIN ditutup
  (controller dialog kini dimiliki widget dialog sendiri),
  baris pencatat disusun ke bawah dengan tombol aksi satu baris,
  halaman Masuk dibersihkan + tombol WhatsApp admin.
- Batch 24: pembaruan kini diunduh DI DALAM aplikasi dengan
  indikator progres, lalu tombol Pasang membuka pemasang paket
  Android (FileProvider + izin REQUEST_INSTALL_PACKAGES);
  jalur browser tetap sebagai cadangan.
- Batch 25: kolom RT & RW (stepper − / +) di form pencatatan &
  koreksi; teks Mode Koreksi + Ganti Bundel dihapus dari form
  pemilik; ekspor PDF baru (kop acara, tabel abjad, alamat
  gabungan, rekap) — kolom Alamat Excel/CSV juga digabungkan.
