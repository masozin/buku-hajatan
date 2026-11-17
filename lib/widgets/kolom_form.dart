import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/rekap.dart';

/// Kolom isian bersama untuk form amplop (Batch 14): dusun
/// dengan tombol − / + dan alamat dengan sugesti dari alamat
/// yang pernah dipakai di acara yang sama.

/// Kolom dusun dengan tombol kurang/tambah di sisi kanan:
/// tiap ketuk mengubah angka sebanyak 1. Dari kosong, +
/// mengisi 1; dari 1, − mengosongkan lagi (dusun boleh kosong).
class KolomDusun extends StatelessWidget {
  const KolomDusun({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  void _ubah(int delta) {
    final sekarang = int.tryParse(controller.text.trim());
    if (delta > 0) {
      controller.text = '${(sekarang ?? 0) + 1}';
    } else if (sekarang == null || sekarang <= 1) {
      controller.clear();
    } else {
      controller.text = '${sekarang - 1}';
    }
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Dusun (angka, boleh kosong)',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Kurangi dusun',
              visualDensity: VisualDensity.compact,
              onPressed: () => _ubah(-1),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Tambah dusun',
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
