import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/profile.dart';
import '../../models/visit_request.dart';
import '../../services/supabase_client.dart';
import '../../services/visit_service.dart';
import '../../utils/format.dart';
import '../listing/listing_detail_screen.dart';

/// Demandes de visite : envoyées (locataire) ou reçues (bailleur).
class VisitsScreen extends StatefulWidget {
  final Profile profile;
  const VisitsScreen({super.key, required this.profile});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _service = VisitService();
  late Future<List<VisitRequest>> _future = _service.myVisits();

  Future<void> _reload() async {
    setState(() => _future = _service.myVisits());
    await _future;
  }

  Future<void> _setStatus(VisitRequest v, VisitStatus s) async {
    try {
      await _service.setStatus(v.id, s);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Color _statusColor(VisitStatus s, ColorScheme c) => switch (s) {
        VisitStatus.accepted => Colors.green.shade700,
        VisitStatus.refused || VisitStatus.cancelled => c.error,
        VisitStatus.pending => c.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final myId = widget.profile.id;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile.isLandlord ? 'Visites reçues' : 'Mes demandes de visite'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<VisitRequest>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(friendlyError(snap.error!), textAlign: TextAlign.center),
                ),
              ]);
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Aucune demande de visite.', textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final v = items[i];
                final iAmLandlord = v.listingOwnerId == myId;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ListingDetailScreen(listingId: v.listingId))),
                          child: Text(v.listingTitle ?? 'Annonce indisponible',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const SizedBox(height: 4),
                        Text(formatDateTime(v.proposedAt)),
                        if (iAmLandlord) Text('Demandée par ${v.tenantName ?? '—'}'),
                        if (v.message != null) ...[
                          const SizedBox(height: 4),
                          Text('« ${v.message} »',
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          Text(v.status.label,
                              style: TextStyle(
                                  color: _statusColor(v.status, scheme),
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          if (iAmLandlord && v.tenantPhone != null)
                            IconButton(
                              tooltip: 'Appeler',
                              icon: const Icon(Icons.call_outlined),
                              onPressed: () =>
                                  launchUrl(Uri(scheme: 'tel', path: v.tenantPhone)),
                            ),
                          if (iAmLandlord && v.status == VisitStatus.pending) ...[
                            TextButton(
                                onPressed: () => _setStatus(v, VisitStatus.refused),
                                child: const Text('Refuser')),
                            FilledButton(
                                onPressed: () => _setStatus(v, VisitStatus.accepted),
                                child: const Text('Accepter')),
                          ],
                          if (!iAmLandlord && v.status == VisitStatus.pending)
                            TextButton(
                                onPressed: () => _setStatus(v, VisitStatus.cancelled),
                                child: const Text('Annuler')),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
