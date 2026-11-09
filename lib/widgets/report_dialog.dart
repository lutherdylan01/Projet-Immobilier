import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../services/supabase_client.dart';

/// Boîte de dialogue « Signaler cette annonce ».
Future<void> showReportDialog(BuildContext context, String listingId) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(listingId: listingId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Merci, votre signalement a été envoyé.'),
    ));
  }
}

class _ReportDialog extends StatefulWidget {
  final String listingId;
  const _ReportDialog({required this.listingId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = reportReasons.keys.first;
  final _details = TextEditingController();
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ReportService().report(
          listingId: widget.listingId, reason: _reason, details: _details.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler cette annonce'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v!),
              child: Column(
                children: reportReasons.entries
                    .map((e) => RadioListTile<String>(
                          value: e.key,
                          title: Text(e.value),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Détails (facultatif)'),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        FilledButton(onPressed: _sending ? null : _send, child: const Text('Envoyer')),
      ],
    );
  }
}
