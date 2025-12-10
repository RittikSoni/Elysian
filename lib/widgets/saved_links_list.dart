import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:flutter/material.dart';

class SavedLinksList extends StatelessWidget {
  final List<SavedLink> savedLinks;
  final String title;

  const SavedLinksList({
    super.key,
    required this.savedLinks,
    required this.title,
  });

  Future<void> _openLink(BuildContext context, String url, LinkType type) async {
    await LinkHandler.openLink(context, url, linkType: type);
  }

  String _getThumbnailUrl(SavedLink link) {
    if (link.thumbnailUrl != null && link.thumbnailUrl!.isNotEmpty) {
      return link.thumbnailUrl!;
    }

    // Generate thumbnail URL based on link type
    switch (link.type) {
      case LinkType.youtube:
        final videoId = LinkParser.extractYouTubeVideoId(link.url);
        if (videoId != null) {
          return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        }
        break;
      case LinkType.instagram:
        // Instagram thumbnails require API, use placeholder for now
        return '';
      case LinkType.unknown:
        break;
    }
    return '';
  }

  IconData _getIconForType(LinkType type) {
    switch (type) {
      case LinkType.youtube:
        return Icons.play_circle_outline;
      case LinkType.instagram:
        return Icons.photo_outlined;
      case LinkType.unknown:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (savedLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (savedLinks.length > 5)
                  TextButton(
                    onPressed: () {
                      // Navigate to full list view
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 220.0,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: savedLinks.length > 10 ? 10 : savedLinks.length,
              itemBuilder: (BuildContext context, int index) {
                final SavedLink link = savedLinks[index];
                final thumbnailUrl = _getThumbnailUrl(link);
                
                return GestureDetector(
                  onTap: () => _openLink(context, link.url, link.type),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    height: 200.0,
                    width: 130.0,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: Colors.grey[800]!, width: 1),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnailUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholder(link.type);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildPlaceholder(link.type);
                              },
                            ),
                          )
                        else
                          _buildPlaceholder(link.type),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(4.0),
                                bottomRight: Radius.circular(4.0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getIconForType(link.type),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        link.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(LinkType type) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForType(type),
              color: Colors.grey[600],
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              type == LinkType.youtube ? 'YouTube' : 'Instagram',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

