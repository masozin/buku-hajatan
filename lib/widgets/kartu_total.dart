import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/acara.dart';
import '../theme/tema_aplikasi.dart';

/// Kartu sorotan total acara (Batch 12): panel bergradasi zamrud
/// berisi total terkumpul dalam angka besar, plus statistik
/// pengunjung, bundel, dan rata-rata per amplop. Dipakai di
/// Detail Acara dan Rekap agar keduanya tampil senada.
class KartuTotalAcara extends StatelessWidget {
  const KartuTotalAcara({super.key, required this.acara});

  final Acara acara;

  @override
  Widget build(BuildContext context) {
    final rataRata = acara.totalAmplop == 0
        ? 0
        : acara.totalRp ~/ acara.totalAmplop;
    return Container(
      decoration: BoxDecoration(
        gradient: TemaAplikasi.gradasiPahlawan,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: TemaAplikasi.zamrud.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Lingkaran hias lembut di sudut panel.
          Positioned(
            top: -46,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -24,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TemaAplikasi.emasTerang.withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Terkumpul',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatRupiah(acara.totalRp),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Statistik(
                      label: 'Pengunjung',
                      nilai: '${acara.totalAmplop}',
                    ),
                    _PemisahStatistik(),
                    _Statistik(
                      label: 'Bundel',
                      nilai: '${acara.totalBundel}',
                    ),
                    _PemisahStatistik(),
                    _Statistik(
                      label: 'Rata-rata',
                      nilai: formatRupiah(rataRata),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Statistik extends StatelessWidget {
  const _Statistik({required this.label, required this.nilai});

  final String label;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nilai,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _PemisahStatistik extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.22),
    );
  }
}
