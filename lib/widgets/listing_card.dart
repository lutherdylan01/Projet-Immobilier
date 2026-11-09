import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../utils/format.dart';

/// Carte d'annonce dans une liste (photo réduite + infos principales).
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;
  final Widget? trailing;

  const ListingCard({super.key, required this.listing, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: listing.coverUrl == null
                  ? Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.home_outlined, size: 40),
                    )
                  : CachedNetworkImage(
                      imageUrl: listing.coverUrl!,
                      fit: BoxFit.cover,
                      // Image décodée en petit : moins de mémoire sur les petits téléphones.
                      memCacheWidth: 330,
                      placeholder: (_, _) =>
                          Container(color: theme.colorScheme.surfaceContainerHighest),
                      errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${formatFcfa(listing.priceMonthly)} / mois',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${listingTypeLabels[listing.type]} · ${listing.neighborhood}, ${listing.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                    if (listing.status != ListingStatus.disponible)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(listingStatusLabels[listing.status]!,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
