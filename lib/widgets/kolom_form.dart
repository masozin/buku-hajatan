import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/pencatatan.dart';
import '../core/rekap.dart';

/// Kolom isian bersama untuk form amplop (Batch 14): dusun
/// dengan tombol − / + dan alamat dengan sugesti dari alamat
/// yang pernah dipakai di acara yang sama.

/// Kolom angka dengan tombol kurang/tambah di sisi kanan:
/// tiap ketuk mengubah angka sebanyak 1. Dari kosong, +
/// mengisi 1; dari 1, − mengosongkan lagi (boleh kosong).
/// Awalnya khusus dusun (Batch 14); sejak Batch 25 dipakai
/// juga untuk RT dan RW lewat parameter [label].
///
/// Batch 36: mode [teksBebas] untuk DUSUN — kolomnya teks
/// (boleh "SP 2", "RK 1", "Krajan") karena sebutan wilayah
/// beragam, tetapi tombol − / + tetap ada dan mengubah ANGKA
/// DI AKHIR teks (lihat ubahAngkaAkhir). RT/RW tetap mode
/// angka murni.
class KolomDusun extends StatelessWidget {
  const KolomDusun({
    super.key,
    required this.controller,
    this.label = 'Dusun/Kampung (boleh kosong)',
    this.onSubmitted,
    this.teksBebas = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onSubmitted;

  /// True = teks bebas + stepper angka akhir (dusun).
  /// False = angka murni (RT/RW).
  final bool teksBebas;

  void _ubah(int delta) {
    if (teksBebas) {
      controller.text = ubahAngkaAkhir(controller.text, delta);
    } else {
      final sekarang = int.tryParse(controller.text.trim());
      if (delta > 0) {
        controller.text = '${(sekarang ?? 0) + 1}';
      } else if (sekarang == null || sekarang <= 1) {
        controller.clear();
      } else {
        controller.text = '${sekarang - 1}';
      }
    }
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: teksBebas
          ? TextInputType.text
          : TextInputType.number,
      textCapitalization: teksBebas
          ? TextCapitalization.words
          : TextCapitalization.none,
      inputFormatters: teksBebas
          ? null
          : [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Kurangi',
              visualDensity: VisualDensity.compact,
              onPressed: () => _ubah(-1),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Tambah',
              visualDensity: VisualDensity.compact,
              onPressed: () => _ubah(1),
            ),
          ],
        ),
      ),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    );
  }
}

/// Kolom alamat dengan sugesti (Batch 14): saat pengguna
/// mengetik, alamat-alamat yang pernah dipakai di acara ini dan
/// berawalan teks itu (atau salah satu katanya berawalan itu)
/// ditawarkan di bawah kolom; ketuk untuk memakai.
class KolomAlamat extends StatefulWidget {
  const KolomAlamat({
    super.key,
    required this.controller,
    required this.saran,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Semua alamat unik acara ini (dari daftarAlamatUnik).
  final List<String> saran;
  final VoidCallback? onSubmitted;

  @override
  State<KolomAlamat> createState() => _KolomAlamatState();
}

class _KolomAlamatState extends State<KolomAlamat> {
  final _fokus = FocusNode();

  @override
  void dispose() {
    _fokus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _fokus,
      optionsBuilder: (nilaiTeks) =>
          saringSaranAlamat(widget.saran, nilaiTeks.text),
      onSelected: (pilihan) {
        widget.controller.text = pilihan;
        widget.controller.selection = TextSelection.collapsed(
          offset: pilihan.length,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Alamat'),
          onSubmitted: (_) {
            onFieldSubmitted();
            widget.onSubmitted?.call();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 224),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opsi = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                    ),
                    title: Text(opsi),
                    onTap: () => onSelected(opsi),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
