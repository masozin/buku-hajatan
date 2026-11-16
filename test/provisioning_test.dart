import 'package:buku_hajatan/core/provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('galatPemilikBaru', () {
    test('form sah menghasilkan null', () {
      expect(
        galatPemilikBaru(
          nama: 'Pak Hartono',
          email: 'hartono@contoh.id',
          kataSandi: 'rahasia1',
          konfirmasiSandi: 'rahasia1',
        ),
        isNull,
      );
    });

    test('nama kosong ditolak', () {
      expect(
        galatPemilikBaru(
          nama: '  ',
          email: 'a@b.id',
          kataSandi: 'rahasia1',
          konfirmasiSandi: 'rahasia1',
        ),
        contains('Nama'),
      );
    });

    test('email tanpa @ atau titik ditolak', () {
      expect(
        galatPemilikBaru(
          nama: 'A',
          email: 'bukan-email',
          kataSandi: 'rahasia1',
          konfirmasiSandi: 'rahasia1',
        ),
        contains('email'),
      );
      expect(
        galatPemilikBaru(
          nama: 'A',
          email: 'a@tanpatitik',
          kataSandi: 'rahasia1',
          konfirmasiSandi: 'rahasia1',
        ),
        contains('email'),
      );
    });

    test('kata sandi pendek & konfirmasi beda ditolak', () {
      expect(
        galatPemilikBaru(
          nama: 'A',
          email: 'a@b.id',
          kataSandi: '12345',
          konfirmasiSandi: '12345',
        ),
        contains('6 karakter'),
      );
      expect(
        galatPemilikBaru(
          nama: 'A',
          email: 'a@b.id',
          kataSandi: 'rahasia1',
          konfirmasiSandi: 'rahasia2',
        ),
        contains('tidak sama'),
      );
    });
  });
}
