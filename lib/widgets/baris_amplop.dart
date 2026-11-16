import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/pencatatan_service.dart';

/// Satu baris amplop di dalam bundel: urut, nama, alamat, nominal,
/// plus penanda sinkron (menunggu terkirim / sudah terkirim).
class BarisAmplop extends StatelessWidget {
  const BarisAmplop({super.key, required this.tercatat});

  final AmplopTercatat tercatat;

  @override
  Widget build(BuildContext context) {
    final amplop = tercatat.amplop;
    final keterangan = [
      if (amplop.alamat != null && amplop.alamat!.isNotEmpty) amplop.alamat!,
      if (amplop.jenis.label != 'Normal') amplop.jenis.label,
    ].join(' • ');
    return ListTile(
      dense: true,
      leading: CircleAvatar(child: Text('${amplop.urut}')),
      title: Text(amplop.tampilNama),
      subtitle: keterangan.isEmpty ? null : Text(keterangan),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatRupiah(amplop.nominal),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          Icon(
            tercatat.menungguSinkron
                ? Icons.cloud_upload_outlined
                : Icons.cloud_done_outlined,
            size: 18,
            color: tercatat.menungguSinkron
                ? Colors.orange
                : Colors.green,
          ),
        ],
      ),
    );
  }
}
