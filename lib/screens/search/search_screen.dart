import 'package:flutter/material.dart';

import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../services/supabase_client.dart';
import '../../config.dart';
import '../../utils/format.dart';
import '../../widgets/listing_card.dart';
import '../listing/listing_detail_screen.dart';

/// Recherche de logements par ville, quartier et budget.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = ListingService();
  final _neighborhood = TextEditingController();
  final _maxPrice = TextEditingController();
  final _scroll = ScrollController();

  String? _city;
  ListingType? _type;
  final List<Listing> _results = [];
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _search();
  }

  ListingFilter get _filter => ListingFilter(
        city: _city,
        neighborhood: _neighborhood.text,
        maxPrice: int.tryParse(_maxPrice.text.replaceAll(RegExp(r'\D'), '')),
        type: _type,
      );

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _results.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final items = await _service.search(_filter, page: _page);
      setState(() {
        _results.addAll(items);
        _page++;
        _hasMore = items.length == AppConfig.pageSize;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _neighborhood.dispose();
    _maxPrice.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _city,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ville', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Toutes')),
                  ...cameroonCities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _city = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<ListingType?>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  ...ListingType.values.map((t) =>
                      DropdownMenuItem(value: t, child: Text(listingTypeLabels[t]!))),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _neighborhood,
                decoration: const InputDecoration(labelText: 'Quartier', isDense: true),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _maxPrice,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Budget max (FCFA)', isDense: true),
                onSubmitted: (_) => _search(),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trouver un logement')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView.builder(
          controller: _scroll,
          itemCount: _results.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return _filters();
            if (i == _results.length + 1) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _search, child: const Text('Réessayer')),
                  ]),
                );
              }
              if (_results.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Aucun logement ne correspond à ces critères.',
                      textAlign: TextAlign.center),
                );
              }
              return const SizedBox(height: 24);
            }
            final listing = _results[i - 1];
            return ListingCard(
              listing: listing,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listingId: listing.id))),
            );
          },
        ),
      ),
    );
  }
}
