import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models.dart';

class EpisodeCard extends StatelessWidget {
  final Series series;
  final Episode episode;
  final DateTime? today;
  final VoidCallback onSeriesTap;
  final VoidCallback onEpisodeTap;
  final VoidCallback onMarkWatched;
  final bool showAirTime;

  const EpisodeCard({
    super.key,
    required this.series,
    required this.episode,
    this.today,
    required this.onSeriesTap,
    required this.onEpisodeTap,
    required this.onMarkWatched,
    this.showAirTime = false,
  });

  String _formatLocal24hTime(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildTimeChip(BuildContext context) {
    final timeString = _formatLocal24hTime(episode.airDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingAction(BuildContext context) {
    if (today != null) {
      final currentDate = today ?? DateTime.now();
      final normalizedToday = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      final airDate = episode.airDate.toLocal();
      final episodeDay = DateTime(airDate.year, airDate.month, airDate.day);
      final daysUntil = episodeDay.difference(normalizedToday).inDays;

      if (daysUntil > 0) {
        final labelText = daysUntil == 1 ? 'In 1 day' : 'In $daysUntil days';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            labelText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    }

    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(
        episode.watched ? Icons.check_circle : Icons.check_circle_outline,
        color: episode.watched ? Colors.green : null,
      ),
      onPressed: onMarkWatched,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onEpisodeTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: series.posterUrl,
                  width: 64,
                  height: 96,
                  fit: BoxFit.cover,
                  memCacheWidth: 192,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) =>
                      Container(width: 64, height: 96, color: Colors.grey[900]),
                  errorWidget: (context, url, error) => Container(
                    width: 64,
                    height: 96,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onSeriesTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          series.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'S${episode.season.toString().padLeft(2, '0')} ~ E${episode.number.toString().padLeft(2, '0')}${episode.episodesLeft > 0 ? '  +${episode.episodesLeft}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      episode.title,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 96,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    if (showAirTime) _buildTimeChip(context),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [_buildTrailingAction(context)],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
