import 'package:flutter/material.dart';
import '../models.dart';

class EpisodeCard extends StatelessWidget {
  final Series series;
  final Episode episode;
  final DateTime? today;
  final VoidCallback onSeriesTap;
  final VoidCallback onEpisodeTap;
  final VoidCallback onMarkWatched;

  const EpisodeCard({
    super.key,
    required this.series,
    required this.episode,
    this.today,
    required this.onSeriesTap,
    required this.onEpisodeTap,
    required this.onMarkWatched,
  });

  Widget _buildTrailingAction(BuildContext context) {
    if (today != null) {
      final currentDate = today ?? DateTime.now();
      final normalizedToday = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );

      final airDate = episode.airDate;
      final episodeDay = DateTime(airDate.year, airDate.month, airDate.day);
      final daysUntil = episodeDay.difference(normalizedToday).inDays;

      if (daysUntil > 0) {
        final labelText = daysUntil == 1 ? 'In 1 day' : 'In $daysUntil days';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
      icon: const Icon(Icons.check_circle_outline),
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
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  series.posterUrl,
                  width: 64,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 64,
                      height: 96,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 30,
                      ),
                    );
                  },
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
              _buildTrailingAction(context),
            ],
          ),
        ),
      ),
    );
  }
}
