import 'package:elysian/models/models.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';

/// Unified widget for displaying user lists with different layout styles
class UserListSectionWidget extends StatelessWidget {
  final UserList list;
  final List<SavedLink> links;
  final ListLayoutStyle layoutStyle;
  final VoidCallback? onRefresh;

  const UserListSectionWidget({
    super.key,
    required this.list,
    required this.links,
    required this.layoutStyle,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (list.id == StorageService.defaultListId)
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  if (list.id == StorageService.defaultListId)
                    const SizedBox(width: 8),
                  Text(
                    list.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${links.length})',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedLinksScreen(
                        listId: list.id,
                        listName: list.name,
                      ),
                    ),
                  ).then((_) => onRefresh?.call());
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content based on layout style
        _buildContent(context),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final displayLinks = links.take(20).toList(); // Limit for performance

    switch (layoutStyle) {
      case ListLayoutStyle.circular:
        return _buildCircularLayout(context, displayLinks);
      case ListLayoutStyle.rectangle:
        return _buildRectangleLayout(context, displayLinks);
      case ListLayoutStyle.smaller:
        return _buildSmallerLayout(context, displayLinks);
      case ListLayoutStyle.medium:
        return _buildMediumLayout(context, displayLinks);
      case ListLayoutStyle.square:
        return _buildSquareLayout(context, displayLinks);
      case ListLayoutStyle.large:
        return _buildLargeLayout(context, displayLinks);
    }
  }

  Widget _buildCircularLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 200.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        itemCount: links.length,
        itemBuilder: (context, index) {
          final link = links[index];
          return GestureDetector(
            onTap: () {
              LinkHandler.openLink(
                context,
                link.url,
                linkType: link.type,
                title: link.title,
                description: link.description,
                linkId: link.id,
                savedLink: link,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular image with gradient border
                  Container(
                    height: 130,
                    width: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber,
                          Colors.orange,
                          Colors.deepOrange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ThumbnailImage(link: link, width: 130, height: 130),
                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Flexible(
                    child: Text(
                      link.title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRectangleLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: links.length,
        itemBuilder: (context, index) {
          return _buildLinkCard(context, links[index], width: 250, height: 200);
        },
      ),
    );
  }

  Widget _buildSmallerLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: links.length,
        itemBuilder: (context, index) {
          return _buildLinkCard(context, links[index], width: 180, height: 150);
        },
      ),
    );
  }

  Widget _buildMediumLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: links.length,
        itemBuilder: (context, index) {
          return _buildLinkCard(context, links[index], width: 300, height: 250);
        },
      ),
    );
  }

  Widget _buildSquareLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: links.length,
        itemBuilder: (context, index) {
          return _buildLinkCard(context, links[index], width: 200, height: 200);
        },
      ),
    );
  }

  Widget _buildLargeLayout(BuildContext context, List<SavedLink> links) {
    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: links.length,
        itemBuilder: (context, index) {
          return _buildLinkCard(context, links[index], width: 280, height: 400);
        },
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context,
    SavedLink link, {
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: () {
        LinkHandler.openLink(
          context,
          link.url,
          linkType: link.type,
          title: link.title,
          description: link.description,
          linkId: link.id,
          savedLink: link,
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: ThumbnailImage(
                link: link,
                width: double.infinity,
                height: height * 0.6,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        link.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                        Flexible(
                          child: Text(
                            _getTypeLabel(link.type),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
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
