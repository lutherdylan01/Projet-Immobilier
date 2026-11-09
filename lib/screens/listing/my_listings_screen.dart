import 'package:flutter/material.dart';

import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../services/supabase_client.dart';
import '../../widgets/listing_card.dart';
import 'listing_detail_screen.dart';
import 'listing_form_screen.dart';

/// Onglet du bailleur : la liste de ses logements + bouton d'ajout.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _service = ListingService();
  late Future<List<Listing>> _future = _service.myListings();

  Future<void> _reload() async {
    setState(() => _future = _service.myListings());
    await _future;
  }

  Future<void> _openForm([Listing? existing]) async {
    final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ListingFormScreen(existing: existing)));
    if (changed == true) _reload();
  }

  Future<void> _action(Listing l, String action) async {
    try {
      switch (action) {
        case 'loue':
          await _service.setStatus(l.id, ListingStatus.loue);
        case 'retire':
          await _service.setStatus(l.id, ListingStatus.retire);
        case 'disponible':
          await _service.setStatus(l.id, ListingStatus.disponible);
        case 'edit':
          final full = await _service.getById(l.id);
          await _openForm(full);
          return;
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Supprimer ce logement ?'),
              content: const Text('L\'annonce et ses photos seront définitivement effacées.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer')),
              ],
            ),
          );
          if (ok != true) return;
          await _service.delete(l);
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes logements')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Listing>>(
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
                  child: Text(
                    'Vous n\'avez pas encore de logement.\n'
                    'Touchez « Ajouter » pour publier votre première annonce.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final l = items[i];
                return ListingCard(
                  listing: l,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ListingDetailScreen(listingId: l.id))),
                  trailing: l.status == ListingStatus.suspendu
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (a) => _action(l, a),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            if (l.status != ListingStatus.disponible)
                              const PopupMenuItem(
                                  value: 'disponible', child: Text('Remettre disponible')),
                            if (l.status == ListingStatus.disponible)
                              const PopupMenuItem(value: 'loue', child: Text('Marquer comme loué')),
                            if (l.status == ListingStatus.disponible)
                              const PopupMenuItem(value: 'retire', child: Text('Retirer l\'annonce')),
                            const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                          ],
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
