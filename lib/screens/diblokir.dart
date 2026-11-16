import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Layar untuk pemilik yang diblokir admin (Batch 4). Ditampilkan
/// gerbang aplikasi menggantikan Daftar Acara; satu-satunya jalan
/// keluar adalah tombol Keluar (atau admin mengaktifkan kembali —
/// stream profil akan membukanya sendiri).
class DiblokirScreen extends ConsumerWidget {
  const DiblokirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.block_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Akun Diblokir',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Akun pemilik ini sedang diblokir oleh admin Buku '
                'Hajatan, jadi belum bisa dipakai membuat atau '
                'mengelola acara. Silakan hubungi admin bila ini '
                'keliru.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(authServiceProvider).keluar(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
