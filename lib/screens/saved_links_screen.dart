import 'package:elysian/main.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:flutter/material.dart';

class SavedLinksScreen extends StatefulWidget {
  final String? listId;
  final String? listName;

  const SavedLinksScreen({
    super.key,
    this.listId,
    this.listName,
  });

  @override
  State<SavedLinksScreen> createState() => _SavedLinksScreenState();
}

class _SavedLinksScreenState extends State<SavedLinksScreen> {
  List<SavedLink> _savedLinks = [];
  bool _isLoading = true;
  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.listId;
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = _selectedListId != null
          ? await StorageService.getSavedLinksByList(_selectedListId!)
          : await StorageService.getSavedLinks();
      setState(() {
        _savedLinks = links;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLink(SavedLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Link',
          style: TextStyle(color: Colors.white),
        ),
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
        await _loadLinks();
        // Refresh home screen
        onLinkSavedCallback?.call();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting link: $e')),
          );
        }
      }
    }
  }

  Future<void> _editLink(SavedLink link) async {
    final titleController = TextEditingController(text: link.title);
    final urlController = TextEditingController(text: link.url);
    final descriptionController = TextEditingController(text: link.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Edit Link',
          style: TextStyle(color: Colors.white),
        ),
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
        // Validate URL and get link type
        final newUrl = result['url']!;
        final linkType = LinkParser.parseLinkType(newUrl);
        if (linkType == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid URL. Must be YouTube or Instagram link.')),
            );
          }
          return;
        }

        // Generate thumbnail if YouTube
        String? thumbnailUrl;
        if (linkType == LinkType.youtube) {
          final videoId = LinkParser.extractYouTubeVideoId(newUrl);
          if (videoId != null) {
            thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          }
        }

        // Fetch title if not provided
        String title = result['title']!;
        if (title.isEmpty) {
          title = await LinkParser.fetchTitleFromUrl(newUrl, linkType);
        }

        // Delete old link and create updated one
        await StorageService.deleteLink(link.id);
        final updatedLink = SavedLink(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: newUrl,
          title: title,
          thumbnailUrl: thumbnailUrl,
          description: result['description']!.isEmpty ? null : result['description'],
          type: linkType,
          listId: link.listId,
          savedAt: link.savedAt,
        );
        await StorageService.saveLink(updatedLink);
        await _loadLinks();
        // Refresh home screen
        onLinkSavedCallback?.call();

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating link: $e')),
          );
        }
      }
    }
  }

  Future<void> _refreshTitle(SavedLink link) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final title = await LinkParser.fetchTitleFromUrl(link.url, link.type);
      
      // Generate thumbnail if YouTube
      String? thumbnailUrl = link.thumbnailUrl;
      if (link.type == LinkType.youtube) {
        final videoId = LinkParser.extractYouTubeVideoId(link.url);
        if (videoId != null) {
          thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        }
      }

      // Delete old and create updated link
      await StorageService.deleteLink(link.id);
      final updatedLink = SavedLink(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: link.url,
        title: title,
        thumbnailUrl: thumbnailUrl,
        description: link.description,
        type: link.type,
        listId: link.listId,
        savedAt: link.savedAt,
      );
      await StorageService.saveLink(updatedLink);
      await _loadLinks();
      // Refresh home screen
      onLinkSavedCallback?.call();

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Title refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing title: $e')),
        );
      }
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
        title: Text(
          widget.listName ?? 'Saved Links',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_savedLinks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadLinks,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedLinks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved links',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedLinks.length,
                  itemBuilder: (context, index) {
                    final link = _savedLinks[index];
                    final thumbnailUrl = link.thumbnailUrl;
                    final videoId = link.type == LinkType.youtube
                        ? LinkParser.extractYouTubeVideoId(link.url)
                        : null;

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => LinkHandler.openLink(
                          context,
                          link.url,
                          linkType: link.type,
                          title: link.title,
                          description: link.description,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Thumbnail
                              Container(
                                width: 120,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: thumbnailUrl != null || videoId != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          thumbnailUrl ??
                                              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              link.type == LinkType.youtube
                                                  ? Icons.play_circle_outline
                                                  : Icons.photo_outlined,
                                              color: Colors.grey[600],
                                              size: 40,
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        link.type == LinkType.youtube
                                            ? Icons.play_circle_outline
                                            : Icons.photo_outlined,
                                        color: Colors.grey[600],
                                        size: 40,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      link.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (link.description != null &&
                                        link.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        link.description!,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          link.type == LinkType.youtube
                                              ? Icons.play_circle_outline
                                              : Icons.photo_outlined,
                                          color: Colors.grey[500],
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          link.type == LinkType.youtube
                                              ? 'YouTube'
                                              : 'Instagram',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Actions
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                color: Colors.grey[900],
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      _editLink(link);
                                      break;
                                    case 'refresh':
                                      _refreshTitle(link);
                                      break;
                                    case 'delete':
                                      _deleteLink(link);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit', style: TextStyle(color: Colors.white)),
                                  ),
                                  const PopupMenuItem(
                                    value: 'refresh',
                                    child: Text('Refresh Title', style: TextStyle(color: Colors.white)),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

