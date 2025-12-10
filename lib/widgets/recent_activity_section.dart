import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:flutter/material.dart';

class RecentActivitySection extends StatelessWidget {
  final List<SavedLink> recentLinks;
  final VoidCallback? onRefresh;

  const RecentActivitySection({
    super.key,
    required this.recentLinks,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (recentLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Continue Watching',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // Navigate to watch history screen (can be implemented later)
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: recentLinks.length > 10 ? 10 : recentLinks.length,
            itemBuilder: (context, index) {
              final link = recentLinks[index];
              return _buildLinkCard(context, link);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLinkCard(BuildContext context, SavedLink link) {
    final timeAgo = _getTimeAgo(link.lastViewedAt);
    
    return GestureDetector(
      onTap: () {
        LinkHandler.openLink(
          context,
          link.url,
          linkType: link.type,
          title: link.title,
          description: link.description,
          linkId: link.id,
        );
        onRefresh?.call();
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with time badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: link.thumbnailUrl != null
                      ? Image.network(
                          link.thumbnailUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: double.infinity,
                            height: 120,
                            color: Colors.grey[800],
                            child: Icon(
                              _getIconForType(link.type),
                              color: Colors.grey[600],
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 120,
                          color: Colors.grey[800],
                          child: Icon(
                            _getIconForType(link.type),
                            color: Colors.grey[600],
                            size: 40,
                          ),
                        ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      timeAgo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                if (link.viewCount > 1)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${link.viewCount}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getIconForType(link.type),
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTypeLabel(link.type),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getIconForType(LinkType type) {
    switch (type) {
      case LinkType.youtube:
        return Icons.play_circle_outline;
      case LinkType.instagram:
        return Icons.photo_outlined;
      case LinkType.vimeo:
        return Icons.play_circle_filled;
      case LinkType.googledrive:
        return Icons.cloud;
      case LinkType.directVideo:
        return Icons.video_library;
      case LinkType.web:
        return Icons.language;
      case LinkType.unknown:
        return Icons.link;
    }
  }

  String _getTypeLabel(LinkType type) {
    switch (type) {
      case LinkType.youtube:
        return 'YouTube';
      case LinkType.instagram:
        return 'Instagram';
      case LinkType.vimeo:
        return 'Vimeo';
      case LinkType.googledrive:
        return 'Google Drive';
      case LinkType.directVideo:
        return 'Video';
      case LinkType.web:
        return 'Web';
      case LinkType.unknown:
        return 'Link';
    }
  }
}

