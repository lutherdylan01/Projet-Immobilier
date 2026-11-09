import 'package:flutter/material.dart';

import '../services/supabase_client.dart';
import '../services/visit_service.dart';
import '../utils/format.dart';

/// Formulaire « Demander une visite » (date, heure, message).
Future<void> showVisitRequestSheet(BuildContext context, String listingId) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _VisitRequestSheet(listingId: listingId),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Demande envoyée. Le bailleur va vous répondre.'),
    ));
  }
}

class _VisitRequestSheet extends StatefulWidget {
  final String listingId;
  const _VisitRequestSheet({required this.listingId});

  @override
  State<_VisitRequestSheet> createState() => _VisitRequestSheetState();
}

class _VisitRequestSheetState extends State<_VisitRequestSheet> {
  DateTime? _when;
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;

  Future<void> _pick() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _send() async {
    if (_when == null) {
      setState(() => _error = 'Choisissez une date et une heure');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await VisitService().request(
          listingId: widget.listingId, proposedAt: _when!, message: _message.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Demander une visite', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.calendar_month),
            label: Text(_when == null ? 'Choisir la date et l\'heure' : formatDateTime(_when!)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Message (facultatif)'),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
  }
}
