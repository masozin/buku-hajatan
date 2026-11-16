import 'package:buku_hajatan/core/admin.dart';
import 'package:buku_hajatan/models/acara.dart';
import 'package:buku_hajatan/models/pemilik.dart';
import 'package:flutter_test/flutter_test.dart';

Acara acaraUji({
  required String id,
  required String pemilikId,
  int totalAmplop = 0,
  int totalRp = 0,
}) {
  return Acara(
    id: id,
    pemilikId: pemilikId,
    namaAcara: 'Acara $id',
    tuanRumah: 'Tuan Rumah',
    jenis: 'Pernikahan',
    tanggal: DateTime(2026, 1, 1),
    kodeGabung: 'KODE$id',
    totalAmplop: totalAmplop,
    totalRp: totalRp,
  );
}

void main() {
  const pemilik = [
    Pemilik(id: 'u2', nama: 'Zahra', email: 'zahra@contoh.id'),
    Pemilik(id: 'u1', nama: 'Andi', email: 'andi@contoh.id'),
    Pemilik(id: 'u3', nama: 'Budi', diblokir: true),
  ];
  final acara = [
    acaraUji(id: 'a1', pemilikId: 'u1', totalAmplop: 25, totalRp: 1000000),
    acaraUji(id: 'a2', pemilikId: 'u1', totalAmplop: 10, totalRp: 400000),
    acaraUji(id: 'a3', pemilikId: 'u2', totalAmplop: 30, totalRp: 2500000),
    // Acara yatim: pemiliknya tidak ada di daftar — diabaikan
    // ringkasPerPemilik, tetap dihitung ringkasPlatform.
    acaraUji(id: 'a4', pemilikId: 'uX', totalAmplop: 5, totalRp: 100000),
  ];

  group('ringkasPlatform', () {
    test('menjumlahkan semua acara & menghitung pemilik', () {
      final r = ringkasPlatform(pemilik: pemilik, acara: acara);
      expect(r.totalPemilik, 3);
      expect(r.totalAcara, 4);
      expect(r.totalAmplop, 70);
      expect(r.totalRp, 4000000);
    });

    test('daftar kosong menghasilkan nol semua', () {
      final r = ringkasPlatform(pemilik: const [], acara: const []);
      expect(r.totalPemilik, 0);
      expect(r.totalAcara, 0);
      expect(r.totalAmplop, 0);
      expect(r.totalRp, 0);
    });
  });

  group('ringkasPerPemilik', () {
    test('agregat per pemilik, urut nama, tanpa acara tetap muncul', () {
      final hasil = ringkasPerPemilik(pemilik, acara);
      expect(hasil.map((r) => r.pemilik.nama).toList(), [
        'Andi',
        'Budi',
        'Zahra',
      ]);
      expect(hasil[0].jumlahAcara, 2);
      expect(hasil[0].totalAmplop, 35);
      expect(hasil[0].totalRp, 1400000);
      expect(hasil[1].jumlahAcara, 0);
      expect(hasil[1].pemilik.diblokir, isTrue);
      expect(hasil[2].jumlahAcara, 1);
      expect(hasil[2].totalRp, 2500000);
    });
  });
}
