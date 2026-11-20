import 'package:buku_hajatan/core/kunci.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('perluKunciSetelahLatar (Batch 38)', () {
    final t0 = DateTime(2026, 11, 20, 20, 0, 0);

    test('belum pernah ke latar -> tidak kunci', () {
      expect(
        perluKunciSetelahLatar(terakhirKeLatar: null, sekarang: t0),
        isFalse,
      );
    });

    test('di latar < 60 detik -> tidak kunci', () {
      expect(
        perluKunciSetelahLatar(
          terakhirKeLatar: t0,
          sekarang: t0.add(const Duration(seconds: 30)),
        ),
        isFalse,
      );
    });

    test('di latar >= 60 detik -> kunci', () {
      expect(
        perluKunciSetelahLatar(
          terakhirKeLatar: t0,
          sekarang: t0.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
      expect(
        perluKunciSetelahLatar(
          terakhirKeLatar: t0,
          sekarang: t0.add(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });
  });
}
