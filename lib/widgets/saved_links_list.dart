import 'package:elysian/main.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/add_link_dialog.dart';
import 'package:flutter/material.dart';

class SavedLinksList extends StatefulWidget {
  final List<SavedLink> savedLinks;
  final String title;
  final VoidCallback? onRefresh;

  const SavedLinksList({
    super.key,
    required this.savedLinks,
    required this.title,
    this.onRefresh,
  });

  @override
  State<SavedLinksList> createState() => _SavedLinksListState();
}

class _SavedLinksListState extends State<SavedLinksList> {
  Future<void> _openLink(BuildContext context, SavedLink link) async {
    await LinkHandler.openLink(
      context,
      link.url,
      linkType: link.type,
      title: link.title,
      description: link.description,
    );
  }

  Future<void> _deleteLink(SavedLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Link', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${link.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StorageService.deleteLink(link.id);
        // Refresh home screen
        onLinkSavedCallback?.call();
        widget.onRefresh?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting link: $e')));
        }
      }
    }
  }

  Future<void> _editLink(SavedLink link) async {
    final titleController = TextEditingController(text: link.title);
    final urlController = TextEditingController(text: link.url);
    final descriptionController = TextEditingController(
      text: link.description ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit Link', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'URL',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'url': urlController.text.trim(),
                'description': descriptionController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final newUrl = result['url']!;
        final linkType = LinkParser.parseLinkType(newUrl);
        if (linkType == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid URL. Must be YouTube or Instagram link.',
                ),
              ),
            );
          }
          return;
        }

        String? thumbnailUrl;
        if (linkType == LinkType.youtube) {
          final videoId = LinkParser.extractYouTubeVideoId(newUrl);
          if (videoId != null) {
            thumbnailUrl =
                'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          }
        }

        String title = result['title']!;
        if (title.isEmpty) {
          title = await LinkParser.fetchTitleFromUrl(newUrl, linkType);
        }

        await StorageService.deleteLink(link.id);
        final updatedLink = SavedLink(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: newUrl,
          title: title,
          thumbnailUrl: thumbnailUrl,
          description: result['description']!.isEmpty
              ? null
              : result['description'],
          type: linkType,
          listId: link.listId,
          savedAt: link.savedAt,
        );
        await StorageService.saveLink(updatedLink);

        // Refresh home screen
        onLinkSavedCallback?.call();
        widget.onRefresh?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating link: $e')));
        }
      }
    }
  }

  Future<void> _showAddLinkDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddLinkDialog(),
    );

    if (result == true) {
      // Refresh home screen
      onLinkSavedCallback?.call();
      widget.onRefresh?.call();
    }
  }

  String? _getThumbnailUrl(SavedLink link) {
    // First, try to use saved thumbnail URL
    if (link.thumbnailUrl != null && link.thumbnailUrl!.isNotEmpty) {
      return link.thumbnailUrl!;
    }

    // Generate thumbnail URL based on link type
    switch (link.type) {
      case LinkType.youtube:
        final videoId = LinkParser.extractYouTubeVideoId(link.url);
        if (videoId != null) {
          // Try maxresdefault first, fallback to hqdefault if needed
          return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        }
        break;
      case LinkType.instagram:
        // Instagram thumbnails require API, use placeholder
        return null;
      case LinkType.unknown:
        break;
    }
    return null;
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
    if (widget.savedLinks.isEmpty) {
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
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _showAddLinkDialog,
                    tooltip: 'Add Link',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(Icons.link_off, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No saved links yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showAddLinkDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Your First Link',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _showAddLinkDialog,
                      tooltip: 'Add Link',
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedLinksScreen(),
                          ),
                        );
                        // Refresh will happen automatically via didChangeDependencies
                      },
                      child: const Text(
                        'See All',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220.0,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 16.0,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: widget.savedLinks.length > 10
                  ? 10
                  : widget.savedLinks.length,
              itemBuilder: (BuildContext context, int index) {
                final SavedLink link = widget.savedLinks[index];
                final thumbnailUrl = _getThumbnailUrl(link);

                return GestureDetector(
                  onLongPress: () {
                    // Show edit/delete menu on long press
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.grey[900],
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.edit,
                                color: Colors.white,
                              ),
                              title: const Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _editLink(link);
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _deleteLink(link);
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              title: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onTap: () async {
                    await _openLink(context, link);
                  },
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
                        if (thumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Try fallback thumbnail for YouTube
                                if (link.type == LinkType.youtube) {
                                  final videoId =
                                      LinkParser.extractYouTubeVideoId(
                                        link.url,
                                      );
                                  if (videoId != null) {
                                    return Image.network(
                                      'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return _buildPlaceholder(link.type);
                                          },
                                    );
                                  }
                                }
                                return _buildPlaceholder(link.type);
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[900],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
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
            Icon(_getIconForType(type), color: Colors.grey[600], size: 40),
            const SizedBox(height: 8),
            Text(
              type == LinkType.youtube ? 'YouTube' : 'Instagram',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
