import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Layar yang tampil bila Firebase belum bisa dihubungi saat aplikasi
/// dibuka — hampir selalu karena `google-services.json` belum diletakkan
/// di `android/app/`. Ini layar petunjuk, BUKAN crash: begitu konfigurasi
/// benar, tombol "Coba Lagi" membawa masuk ke aplikasi.
class BelumKonfigurasiScreen extends ConsumerWidget {
  const BelumKonfigurasiScreen({super.key, this.rincianGalat});

  final String? rincianGalat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buku Hajatan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            'Firebase belum dikonfigurasi',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aplikasi belum menemukan konfigurasi Firebase. '
            'Langkah penyiapannya (sekali saja, oleh pemilik project):',
          ),
          const SizedBox(height: 12),
          const _Langkah(
            nomor: '1',
            teks:
                'Buat project di Firebase Console (paket Spark/gratis), '
                'aktifkan Authentication (Email/Password DAN Anonymous) '
                'dan Firestore Database.',
          ),
          _Langkah(
            nomor: '2',
            teks:
                'Daftarkan aplikasi Android dengan nama paket '
                'id.my.ozinsq.bukuhajatan, lalu unduh google-services.json.',
          ),
          _Langkah(
            nomor: '3',
            teks:
                'Letakkan google-services.json di folder android/app/ '
                'pada project ini, lalu jalankan ulang aplikasi.',
          ),
          _Langkah(
            nomor: '4',
            teks:
                'Tempel isi firestore.rules (ada di root project) ke '
                'Firebase Console > Firestore Database > Rules.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => ref.invalidate(inisialisasiFirebaseProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
          if (rincianGalat != null) ...[
            const SizedBox(height: 20),
            Text(
              'Rincian galat: $rincianGalat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah({required this.nomor, required this.teks});

  final String nomor;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text(nomor)),
          const SizedBox(width: 12),
          Expanded(child: Text(teks)),
        ],
      ),
    );
  }
}
