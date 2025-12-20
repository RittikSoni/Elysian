import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:flutter/material.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await StorageService.getStatistics();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistics', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStatistics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Links',
                          value: '${_stats!['totalLinks']}',
                          icon: Icons.link,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Total Lists',
                          value: '${_stats!['totalLists']}',
                          icon: Icons.folder,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Favorites',
                          value: '${_stats!['favoriteLinks']}',
                          icon: Icons.star,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Total Views',
                          value: '${_stats!['totalViews']}',
                          icon: Icons.play_arrow,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Links by Type
                  const Text(
                    'Links by Type',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(_stats!['typeCounts'] as Map<String, dynamic>).entries
                      .map((entry) {
                        final typeName = entry.key.replaceAll('LinkType.', '');
                        final count = entry.value as int;
                        final total = _stats!['totalLinks'] as int;
                        final percentage = total > 0
                            ? (count / total * 100).toStringAsFixed(1)
                            : '0.0';

                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              _getIconForType(typeName),
                              color: Colors.white,
                            ),
                            title: Text(
                              typeName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: LinearProgressIndicator(
                              value: total > 0 ? count / total : 0,
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getColorForType(typeName),
                              ),
                            ),
                            trailing: Text(
                              '$count ($percentage%)',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      }),
                  const SizedBox(height: 24),
                  // Most Viewed
                  const Text(
                    'Most Viewed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...((_stats!['mostViewed'] as List).take(5).map((linkJson) {
                    final link = SavedLink.fromJson(
                      linkJson as Map<String, dynamic>,
                    );
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getIconForType(
                            link.type.toString().replaceAll('LinkType.', ''),
                          ),
                          color: Colors.white,
                        ),
                        title: Text(
                          link.title,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${link.viewCount} views',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  })),
                ],
              ),
            ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_outline;
      case 'instagram':
        return Icons.photo_outlined;
      case 'vimeo':
        return Icons.play_circle_filled;
      case 'googledrive':
        return Icons.cloud;
      case 'directvideo':
        return Icons.video_library;
      case 'web':
        return Icons.language;
      default:
        return Icons.link;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'youtube':
        return Colors.red;
      case 'instagram':
        return Colors.purple;
      case 'vimeo':
        return Colors.blue;
      case 'googledrive':
        return Colors.green;
      case 'directvideo':
        return Colors.orange;
      case 'web':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
