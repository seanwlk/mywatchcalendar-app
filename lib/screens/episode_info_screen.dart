import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';

class EpisodeInfoScreen extends StatefulWidget {
  final Series? series;
  final Episode? episode;
  final String? seriesId;
  final String? episodeId;

  const EpisodeInfoScreen({
    super.key,
    this.series,
    this.episode,
    this.seriesId,
    this.episodeId,
  }) : assert((series != null && episode != null) || (seriesId != null && episodeId != null));

  @override
  State<EpisodeInfoScreen> createState() => _EpisodeInfoScreenState();
}

class _EpisodeInfoScreenState extends State<EpisodeInfoScreen> {
  Series? _series;
  Episode? _episode;
  bool _isWatched = false;
  bool _isLoading = false;
  bool _isFetchingData = false;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _episode = widget.episode;

    if (_episode != null && _series != null) {
      _isWatched = _episode!.watched;
    } else {
      _fetchEnrichedData();
    }
  }

  Future<void> _fetchEnrichedData() async {
    setState(() => _isFetchingData = true);
    try {
      final fetchedSeries =
          await ApiClient.instance.fetchSeriesbyId(widget.seriesId!);
      final fetchedEpisode =
          await ApiClient.instance.getEpisode(widget.episodeId!);

      if (mounted) {
        setState(() {
          _series = fetchedSeries;
          _episode = fetchedEpisode;
          _isWatched = _episode?.watched ?? false;
          _isFetchingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load episode data')),
        );
      }
    }
  }

  Future<void> _toggleWatched() async {
    if (_episode == null) return;
    setState(() => _isLoading = true);

    final success = await ApiClient.instance.markEpisodeWatched(
      _episode!.id,
      !_isWatched,
    );

    if (success) {
      setState(() => _isWatched = !_isWatched);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingData || _episode == null || _series == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: CachedNetworkImage(
              imageUrl: _episode!.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 1080,
              errorWidget: (_, _, _) => const Icon(Icons.broken_image),
            ),
          ),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 250)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'S${_episode!.season.toString().padLeft(2, '0')} E${_episode!.number.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _episode!.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _toggleWatched,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _isWatched
                                          ? Icons.check_circle
                                          : Icons.visibility_off,
                                    ),
                              label: Text(
                                _isWatched ? 'Watched' : 'Mark Watched',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Air date ${_episode!.airDate?.toLocal().toString().split(' ')[0] ?? 'TBD'}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Overview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _episode!.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
