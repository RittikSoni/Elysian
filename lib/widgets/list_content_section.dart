import 'dart:ui';
import 'package:elysian/models/models.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ListContentSection extends StatelessWidget {
  final UserList list;
  final List<SavedLink> links;
  final VoidCallback? onRefresh;

  const ListContentSection({
    super.key,
    required this.list,
    required this.links,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

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
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                  if (list.id == StorageService.defaultListId)
                    const SizedBox(width: 8),
                  Text(
                    list.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${links.length})',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
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
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        // Links List
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: links.length > 10 ? 10 : links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              return _buildLinkCard(context, link);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLinkCard(BuildContext context, SavedLink link) {
    return GestureDetector(
      onTap: () {
        LinkHandler.openLink(
          context,
          link.url,
          linkType: link.type,
          title: link.title,
          description: link.description,
          linkId: link.id, // Pass linkId to track views
          savedLink: link, // Pass the full SavedLink object to preserve listIds
        );
      },
      child: Consumer<AppStateProvider>(
        builder: (context, appState, _) {
          final isLiquidGlass = appState.themeType == AppThemeType.liquidGlass;
          final theme = Theme.of(context);
          
          if (isLiquidGlass) {
            final liquidGlass = theme.extension<LiquidGlassTheme>();
            final blur = liquidGlass?.blurIntensity ?? 15.0;
            final opacity = liquidGlass?.glassOpacity ?? 0.18;
            final borderOpacity = liquidGlass?.borderOpacity ?? 0.25;
            
            return Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(borderOpacity),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildLinkCardContent(context, link),
                  ),
                ),
              ),
            );
          } else {
            return Container(
              width: 250,
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildLinkCardContent(context, link),
            );
          }
        },
      ),
    );
  }

  Widget _buildLinkCardContent(BuildContext context, SavedLink link) {
    return Column(
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
            height: 120,
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
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white,
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
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[600]
                          : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _getTypeLabel(link.type),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Colors.grey[600]
                              : Colors.grey[500],
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

