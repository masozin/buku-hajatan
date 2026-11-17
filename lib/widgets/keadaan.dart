import 'package:flutter/material.dart';

/// Tampilan standar untuk keadaan memuat / galat / kosong,
/// dipakai semua layar supaya konsisten. Ditata ulang Batch 12:
/// ikon kini duduk di dalam lingkaran lembut berwarna permukaan.

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
    final skema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: skema.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: skema.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: skema.onSurfaceVariant,
              ),
            ),
            if (onCobaLagi != null) ...[
              const SizedBox(height: 16),
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
    final skema = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: skema.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ikon ?? Icons.inbox_outlined,
                size: 36,
                color: skema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              teks,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: skema.onSurfaceVariant,
              ),
            ),
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
