import 'package:flutter/material.dart';

/// Tampilan standar untuk keadaan memuat / galat / kosong,
/// dipakai semua layar supaya konsisten.

class TampilMuat extends StatelessWidget {
  const TampilMuat({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class TampilGalat extends StatelessWidget {
  const TampilGalat({super.key, required this.pesan, this.onCobaLagi});

  final String pesan;
  final VoidCallback? onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(pesan, textAlign: TextAlign.center),
            if (onCobaLagi != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onCobaLagi,
                child: const Text('Coba Lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TampilKosong extends StatelessWidget {
  const TampilKosong({super.key, required this.teks, this.ikon});

  final String teks;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon ?? Icons.inbox_outlined, size: 40),
            const SizedBox(height: 12),
            Text(teks, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Pesan galat ringkas dari sembarang error untuk ditampilkan ke pengguna.
String pesanDari(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
