import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/qc_local_draft_store.dart';
import '../utils/qc_photo_validation.dart';
import 'app_snackbar.dart';

enum _DraftExitAction { save, discard, cancel }

enum _DraftRestoreAction { restore, restart }

class QCDraftProtection extends StatefulWidget {
  final String identity;
  final QCLocalDraftStore store;
  final Map<String, dynamic> Function() createSnapshot;
  final Future<void> Function(Map<String, dynamic>) restoreSnapshot;
  final bool hasProcessingEvidence;
  final VoidCallback preserveEvidence;
  final VoidCallback releaseEvidence;
  final Widget child;

  const QCDraftProtection({
    super.key,
    required this.identity,
    this.store = const QCLocalDraftStore(),
    required this.createSnapshot,
    required this.restoreSnapshot,
    required this.hasProcessingEvidence,
    required this.preserveEvidence,
    required this.releaseEvidence,
    required this.child,
  });

  @override
  State<QCDraftProtection> createState() => QCDraftProtectionState();
}

class QCDraftProtectionState extends State<QCDraftProtection> {
  late final Future<void> _initialization;
  String? _baseline;
  bool _allowPop = false;
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    _baseline = _snapshotValue();
    await Future<void>.delayed(Duration.zero);
    final draft = await widget.store.read(widget.identity);
    if (!mounted || draft == null) return;

    final action = await showDialog<_DraftRestoreAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Draft ditemukan'),
          content: const Text(
            'Ada isian yang belum selesai. Lanjutkan dari draft terakhir?',
          ),
          actions: [
            TextButton(
              key: const Key('qc_draft_restart_button'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _DraftRestoreAction.restart,
              ),
              child: const Text('Mulai Ulang'),
            ),
            FilledButton(
              key: const Key('qc_draft_restore_button'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _DraftRestoreAction.restore,
              ),
              child: const Text('Lanjutkan Draft'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    try {
      if (action == _DraftRestoreAction.restore) {
        await widget.restoreSnapshot(draft.payload);
        widget.preserveEvidence();
      } else {
        await widget.store.delete(widget.identity);
        widget.releaseEvidence();
      }
      _baseline = _snapshotValue();
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        'Draft tidak dapat dipulihkan. Form baru tetap dapat digunakan.',
      );
    }
  }

  Future<void> completeAndPop<T extends Object?>([T? result]) async {
    await _initialization;
    try {
      await widget.store.delete(widget.identity);
      widget.releaseEvidence();
      _baseline = _snapshotValue();
      await _pop(result);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Draft lokal tidak dapat dibersihkan.');
    }
  }

  Future<void> _handlePopAttempt<T extends Object?>([T? result]) async {
    await _initialization;
    if (!mounted || _allowPop || _exitDialogOpen) return;
    if (_snapshotValue() == _baseline) {
      await _pop(result);
      return;
    }

    _exitDialogOpen = true;
    final action = await showDialog<_DraftExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Simpan sebagai draft?'),
          content: const Text(
            'Data yang sudah diisi dapat disimpan dan dilanjutkan nanti.',
          ),
          actions: [
            TextButton(
              key: const Key('qc_draft_cancel_button'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _DraftExitAction.cancel,
              ),
              child: const Text('Batal'),
            ),
            TextButton(
              key: const Key('qc_draft_discard_button'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _DraftExitAction.discard,
              ),
              child: const Text('Keluar Tanpa Menyimpan'),
            ),
            FilledButton(
              key: const Key('qc_draft_save_button'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _DraftExitAction.save,
              ),
              child: const Text('Simpan Draft'),
            ),
          ],
        ),
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || action == null || action == _DraftExitAction.cancel) return;

    try {
      if (action == _DraftExitAction.save) {
        if (widget.hasProcessingEvidence) {
          AppSnackbar.warning(context, qcPhotoProcessingMessage);
          return;
        }
        final snapshot = widget.createSnapshot();
        await widget.store.write(widget.identity, snapshot);
        widget.preserveEvidence();
        _baseline = _canonical(snapshot);
      } else {
        await widget.store.delete(widget.identity);
        widget.releaseEvidence();
      }
      await _pop(result);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        action == _DraftExitAction.save
            ? 'Draft tidak dapat disimpan. Coba lagi.'
            : 'Draft tidak dapat dihapus. Coba lagi.',
      );
    }
  }

  Future<void> _pop<T extends Object?>([T? result]) async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  String _snapshotValue() => _canonical(widget.createSnapshot());

  String _canonical(Map<String, dynamic> value) => jsonEncode(value);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handlePopAttempt(result));
      },
      child: widget.child,
    );
  }
}
