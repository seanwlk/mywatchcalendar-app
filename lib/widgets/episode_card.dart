import 'package:flutter/material.dart';
import '../models.dart';

class EpisodeCard extends StatelessWidget {
  final Series series;
  final Episode episode;
  final VoidCallback onSeriesTap;
  final VoidCallback onEpisodeTap;
  final VoidCallback onMarkWatched;

  const EpisodeCard({
    super.key,
    required this.series,
    required this.episode,
    required this.onSeriesTap,
    required this.onEpisodeTap,
    required this.onMarkWatched,
  });

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
              IconButton(
                icon: Icon(
                  episode.watched
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: episode.watched ? Colors.green : null,
                ),
                onPressed: onMarkWatched,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
