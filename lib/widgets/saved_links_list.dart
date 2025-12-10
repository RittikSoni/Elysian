import 'package:elysian/main.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/widgets/add_link_dialog.dart';
import 'package:elysian/widgets/multi_list_picker.dart';
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
      linkId: link.id, // Pass linkId to track views
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
    final notesController = TextEditingController(text: link.notes ?? '');
    final newListNameController = TextEditingController();
    final newListDescriptionController = TextEditingController();
    final listPickerKey = GlobalKey();
    List<String> selectedListIds = List<String>.from(link.listIds);
    bool isFavorite = link.isFavorite;
    bool isCreatingList = false;
    bool showCreateListForm = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Edit Link', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 24),
                // Lists Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lists',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          showCreateListForm = !showCreateListForm;
                        });
                      },
                      icon: Icon(
                        showCreateListForm ? Icons.close : Icons.add,
                        size: 18,
                      ),
                      label: Text(
                        showCreateListForm ? 'Cancel' : 'New List',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Create New List Form
                if (showCreateListForm) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: newListNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'List Name',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: newListDescriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isCreatingList ? null : () async {
                              final name = newListNameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a list name')),
                                );
                                return;
                              }

                              setDialogState(() => isCreatingList = true);
                              try {
                                final description = newListDescriptionController.text.trim();
                                final newList = await StorageService.createUserList(
                                  name,
                                  description: description.isEmpty ? null : description,
                                );
                                
                                setDialogState(() {
                                  selectedListIds.add(newList.id);
                                  showCreateListForm = false;
                                  isCreatingList = false;
                                });
                                
                                newListNameController.clear();
                                newListDescriptionController.clear();
                                
                                // Refresh the list picker
                                final state = listPickerKey.currentState;
                                if (state != null && state.mounted) {
                                  (state as dynamic).refreshLists();
                                }
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('List created successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isCreatingList = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            child: isCreatingList
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Create List'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Notes field
                  TextField(
                    controller: notesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: 'Add personal notes about this link...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Favorite toggle
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add to Favorites',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      Switch(
                        value: isFavorite,
                        onChanged: (value) {
                          setDialogState(() {
                            isFavorite = value;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Multi-List Picker
                MultiListPicker(
                  key: listPickerKey,
                  selectedListIds: selectedListIds,
                  onSelectionChanged: (listIds) {
                    setDialogState(() {
                      selectedListIds = listIds;
                    });
                  },
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
                  'notes': notesController.text.trim(),
                  'isFavorite': isFavorite,
                  'listIds': selectedListIds,
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

        // Get selected list IDs from result
        final selectedListIds = result['listIds'] as List<String>? ?? link.listIds;
        
        // Ensure at least one list is selected
        if (selectedListIds.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select at least one list.')),
            );
          }
          return;
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
          listIds: selectedListIds,
          savedAt: link.savedAt,
          isFavorite: result['isFavorite'] as bool? ?? link.isFavorite,
          notes: (result['notes'] as String?)?.isEmpty ?? true
              ? null
              : result['notes'] as String?,
          lastViewedAt: link.lastViewedAt,
          viewCount: link.viewCount,
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
      case LinkType.vimeo:
        final videoId = LinkParser.extractVimeoVideoId(link.url);
        if (videoId != null) {
          // Vimeo thumbnail API (requires API key for better quality)
          // For now, return null to use placeholder
          return null;
        }
        break;
      case LinkType.instagram:
      case LinkType.googledrive:
      case LinkType.directVideo:
      case LinkType.web:
      case LinkType.unknown:
        // These don't have easy thumbnail access
        return null;
    }
    return null;
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
                              leading: Icon(
                                link.isFavorite ? Icons.star : Icons.star_border,
                                color: link.isFavorite ? Colors.amber : Colors.white,
                              ),
                              title: Text(
                                link.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                                style: TextStyle(
                                  color: link.isFavorite ? Colors.amber : Colors.white,
                                ),
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await StorageService.toggleFavorite(link.id);
                                widget.onRefresh?.call();
                                onLinkSavedCallback?.call();
                              },
                            ),
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
                        // Favorite button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () async {
                              await StorageService.toggleFavorite(link.id);
                              widget.onRefresh?.call();
                              onLinkSavedCallback?.call();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: link.isFavorite 
                                    ? Colors.amber.withOpacity(0.9)
                                    : Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: link.isFavorite ? Colors.amber : Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                link.isFavorite ? Icons.star : Icons.star_border,
                                color: link.isFavorite ? Colors.black : Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        // Notes indicator
                        if (link.notes != null && link.notes!.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.note,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          ),
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
              _getTypeLabel(type),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
