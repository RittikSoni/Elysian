import 'dart:ui';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:elysian/utils/app_themes.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SuggestionsSection extends StatelessWidget {
  final List<SavedLink> suggestedLinks;
  final VoidCallback? onRefresh;

  const SuggestionsSection({
    super.key,
    required this.suggestedLinks,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestedLinks.isEmpty) {
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
                  Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'You Might Like',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: suggestedLinks.length > 10 ? 10 : suggestedLinks.length,
            itemBuilder: (context, index) {
              final link = suggestedLinks[index];
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
          linkId: link.id,
        );
        onRefresh?.call();
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
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: borderOpacity),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: opacity),
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
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
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
        Stack(
          children: [
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
            if (link.viewCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${link.viewCount}x',
                        style: const TextStyle(
                          color: Colors.black,
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
                          color:
                              Theme.of(context).brightness == Brightness.light
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
