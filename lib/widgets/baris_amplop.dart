import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/pencatatan_service.dart';

/// Satu baris amplop di dalam bundel: urut, nama, alamat, nominal,
/// plus penanda sinkron (menunggu terkirim / sudah terkirim).
/// [onUbah]/[onHapus] hanya diisi pada mode koreksi pemilik setelah
/// acara selesai (Batch 6) — di layar pencatatan keduanya kosong.
///
/// Ditata ulang Batch 12: nomor urut dalam kotak membulat hijau
/// muda, nama & nominal ditegaskan, penanda sinkron memakai warna
/// tema (emas = menunggu, zamrud = terkirim).
class BarisAmplop extends StatelessWidget {
  const BarisAmplop({
    super.key,
    required this.tercatat,
    this.onUbah,
    this.onHapus,
  });

  final AmplopTercatat tercatat;
  final VoidCallback? onUbah;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final amplop = tercatat.amplop;
    final keterangan = [
      if (amplop.alamat != null && amplop.alamat!.isNotEmpty) amplop.alamat!,
      if (amplop.dusun != null) 'Dusun ${amplop.dusun}',
      if (amplop.keterangan != null && amplop.keterangan!.isNotEmpty)
        amplop.keterangan!,
      if (amplop.jenis.label != 'Normal') amplop.jenis.label,
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: skema.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          '${amplop.urut}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: skema.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        amplop.tampilNama,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: keterangan.isEmpty
          ? null
          : Text(
              keterangan,
              style: tema.textTheme.bodySmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatRupiah(amplop.nominal),
            style: tema.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            tercatat.menungguSinkron
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            size: 18,
            color: tercatat.menungguSinkron
                ? skema.tertiary
                : skema.primary,
          ),
          if (onUbah != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Ubah',
              visualDensity: VisualDensity.compact,
              onPressed: onUbah,
            ),
          if (onHapus != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Hapus',
              visualDensity: VisualDensity.compact,
              color: skema.error,
              onPressed: onHapus,
            ),
        ],
      ),
    );
  }
}
