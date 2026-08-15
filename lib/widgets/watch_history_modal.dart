import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_client.dart';

class WatchHistoryModal extends StatefulWidget {
  final Series series;
  final Episode episode;
  final VoidCallback onChanged;

  const WatchHistoryModal({
    super.key,
    required this.series,
    required this.episode,
    required this.onChanged,
  });

  static void show(
    BuildContext context,
    Series series,
    Episode episode, {
    required VoidCallback onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WatchHistoryModal(
        series: series, 
        episode: episode, 
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<WatchHistoryModal> createState() => _WatchHistoryModalState();
}

class _WatchHistoryModalState extends State<WatchHistoryModal> {
  bool _isLoading = true;
  Episode? _fullEpisode;

  @override
  void initState() {
    super.initState();
    _fetchFullHistory();
  }

  Future<void> _fetchFullHistory() async {
    setState(() => _isLoading = true);
    final enrichedEpisode = await ApiClient.instance.getEpisode(widget.episode.id);
    if (mounted) {
      setState(() {
        _fullEpisode = enrichedEpisode;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String progressId) async {
    final success = await ApiClient.instance.markEpisodeWatched(
      widget.episode.id,
      false,
      progressId: progressId,
    );

    if (success) {
      widget.onChanged();
      await _fetchFullHistory();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete record')),
        );
      }
    }
  }

  Future<void> _addRecord() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final success = await ApiClient.instance.markEpisodeWatched(
        widget.episode.id,
        true,
        watchedAt: picked,
      );

      if (success) {
        widget.onChanged();
        await _fetchFullHistory();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add record')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = DateConstants.monthsShort[localDate.month];
    final year = localDate.year;
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasHistory = _fullEpisode?.history.isNotEmpty ?? widget.episode.watched;
    final String buttonLabel = hasHistory ? 'Add Rewatch Date' : 'Add Watch Date';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Watch History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.series.title} • S${widget.episode.season.toString().padLeft(2, '0')}E${widget.episode.number.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_fullEpisode?.history.isEmpty ?? true)
                      ? const Center(child: Text('No watch history found.'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _fullEpisode!.history.length,
                          itemBuilder: (context, index) {
                            final record = _fullEpisode!.history[index];
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(_formatDate(record.watchedAt)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteRecord(record.id),
                              ),
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.paddingOf(context).bottom + 16.0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addRecord,
                  icon: const Icon(Icons.add),
                  label: Text(buttonLabel),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
