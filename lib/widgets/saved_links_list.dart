import 'dart:io';
import 'package:elysian/models/models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/thumbnail_service.dart';
import 'package:elysian/utils/kroute.dart';
import 'package:elysian/widgets/add_link_dialog.dart';
import 'package:elysian/widgets/multi_list_picker.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SavedLinksList extends StatefulWidget {
  final List<SavedLink> savedLinks;
  final String title;
  final VoidCallback? onRefresh;
  final bool enableSwipeActions; // Disable swipe for horizontal lists

  const SavedLinksList({
    super.key,
    required this.savedLinks,
    required this.title,
    this.onRefresh,
    this.enableSwipeActions = true, // Default to true for vertical lists
  });

  @override
  State<SavedLinksList> createState() => _SavedLinksListState();
}

class _SavedLinksListState extends State<SavedLinksList> {
  final Set<String> _dismissedLinkIds = {};

  @override
  void didUpdateWidget(SavedLinksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear dismissed set when widget updates (e.g., after refresh)
    if (oldWidget.savedLinks != widget.savedLinks) {
      _dismissedLinkIds.clear();
    }
  }

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

  Future<void> _handleFavoriteToggle(SavedLink link) async {
    final wasFavorite = link.isFavorite;
    final linksProvider = context.read<LinksProvider>();
    await linksProvider.toggleFavorite(link.id);
    widget.onRefresh?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite ? 'Removed from favorites' : 'Added to favorites',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await linksProvider.toggleFavorite(link.id);
              widget.onRefresh?.call();
            },
          ),
        ),
      );
    }
  }

  Future<void> _handleDelete(SavedLink link) async {
    try {
      final linksProvider = context.read<LinksProvider>();
      await linksProvider.deleteLink(link.id);
      widget.onRefresh?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('Link deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          navigatorKey.currentContext!,
        ).showSnackBar(SnackBar(content: Text('Error deleting link: $e')));
      }
    }
  }

  Future<void> _shareLink(SavedLink link) async {
    final shareText = '${link.title}\n${link.url}';
    if (link.description != null && link.description!.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(text: '$shareText\n\n${link.description}'),
      );
    } else {
      await SharePlus.instance.share(ShareParams(text: shareText));
    }
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
        final linksProvider = navigatorKey.currentContext!
            .read<LinksProvider>();
        await linksProvider.deleteLink(link.id);
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
    File? customThumbnailFile;
    String? customThumbnailUrl = link.customThumbnailPath == null
        ? link.thumbnailUrl
        : null;
    final ImagePicker imagePicker = ImagePicker();

    // Load existing custom thumbnail if it exists
    if (link.customThumbnailPath != null) {
      final thumbnailFile = await ThumbnailService.getThumbnailFile(
        link.customThumbnailPath,
      );
      if (thumbnailFile != null) {
        customThumbnailFile = thumbnailFile;
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: navigatorKey.currentContext!,
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
                const SizedBox(height: 16),
                // Custom Thumbnail Section
                Row(
                  children: [
                    const Text(
                      'Thumbnail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (customThumbnailFile != null ||
                        customThumbnailUrl != null)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            customThumbnailFile = null;
                            customThumbnailUrl = null;
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Thumbnail Preview
                if (customThumbnailFile != null || customThumbnailUrl != null)
                  Container(
                    height: 120,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: customThumbnailFile != null
                          ? Image.file(customThumbnailFile!, fit: BoxFit.cover)
                          : Image.network(
                              customThumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                            ),
                    ),
                  ),
                // Thumbnail Picker Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              setDialogState(() {
                                customThumbnailFile = File(image.path);
                                customThumbnailUrl = null;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(
                                navigatorKey.currentContext!,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text('Error picking image: $e'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await imagePicker.pickImage(
                              source: ImageSource.camera,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              setDialogState(() {
                                customThumbnailFile = File(image.path);
                                customThumbnailUrl = null;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(
                                navigatorKey.currentContext!,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text('Error taking photo: $e'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text(
                          'Camera',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final urlController = TextEditingController(
                            text: customThumbnailUrl,
                          );
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              title: const Text(
                                'Enter Thumbnail URL',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: TextField(
                                controller: urlController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'https://example.com/image.jpg',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey[700]!,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    context,
                                    urlController.text.trim(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          if (result != null) {
                            setDialogState(() {
                              if (result.isEmpty) {
                                customThumbnailUrl = null;
                              } else {
                                customThumbnailUrl = result;
                                customThumbnailFile = null;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text(
                          'URL',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
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
                            onPressed: isCreatingList
                                ? null
                                : () async {
                                    final name = newListNameController.text
                                        .trim();
                                    if (name.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please enter a list name',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isCreatingList = true);
                                    try {
                                      final description =
                                          newListDescriptionController.text
                                              .trim();
                                      final newList =
                                          await StorageService.createUserList(
                                            name,
                                            description: description.isEmpty
                                                ? null
                                                : description,
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
                                        ScaffoldMessenger.of(
                                          navigatorKey.currentContext!,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'List created successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(
                                        () => isCreatingList = false,
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          navigatorKey.currentContext!,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceAll(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                        activeThumbColor: Colors.amber,
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
                  'customThumbnailFile': customThumbnailFile,
                  'customThumbnailUrl': customThumbnailUrl,
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

        // Handle custom thumbnail
        String? customThumbnailPath;
        String? thumbnailUrl;
        final customThumbnailFile = result['customThumbnailFile'] as File?;
        final customThumbnailUrl = result['customThumbnailUrl'] as String?;

        if (customThumbnailFile != null) {
          // Delete old thumbnail if exists
          if (link.customThumbnailPath != null) {
            await ThumbnailService.deleteThumbnail(link.customThumbnailPath);
          }
          // Save new thumbnail
          customThumbnailPath = await ThumbnailService.saveThumbnail(
            customThumbnailFile,
            link.id,
          );
        } else if (customThumbnailUrl != null &&
            customThumbnailUrl.isNotEmpty) {
          // Use custom URL
          thumbnailUrl = customThumbnailUrl;
          // Delete old local thumbnail if exists
          if (link.customThumbnailPath != null) {
            await ThumbnailService.deleteThumbnail(link.customThumbnailPath);
          }
        } else {
          // Generate thumbnail based on link type or fetch metadata
          final metadata = await LinkParser.fetchMetadataFromUrl(
            newUrl,
            linkType,
          );
          thumbnailUrl = metadata['thumbnailUrl'];
          if (metadata['description'] != null &&
              result['description']!.isEmpty) {
            result['description'] = metadata['description'];
          }

          // If no metadata thumbnail, try YouTube default
          if (thumbnailUrl == null && linkType == LinkType.youtube) {
            final videoId = LinkParser.extractYouTubeVideoId(newUrl);
            if (videoId != null) {
              thumbnailUrl =
                  'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
            }
          }

          // Delete old local thumbnail if exists
          if (link.customThumbnailPath != null) {
            await ThumbnailService.deleteThumbnail(link.customThumbnailPath);
          }
        }

        String title = result['title']!;
        if (title.isEmpty) {
          title = await LinkParser.fetchTitleFromUrl(newUrl, linkType);
        }

        // Get selected list IDs from result
        final selectedListIds =
            result['listIds'] as List<String>? ?? link.listIds;

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
          id: link.id, // Keep same ID
          url: newUrl,
          title: title,
          thumbnailUrl: thumbnailUrl,
          customThumbnailPath: customThumbnailPath,
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
        final linksProvider = navigatorKey.currentContext!
            .read<LinksProvider>();
        await linksProvider.saveLink(updatedLink);
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
      // Refresh providers
      final linksProvider = navigatorKey.currentContext!.read<LinksProvider>();
      final listsProvider = navigatorKey.currentContext!.read<ListsProvider>();
      linksProvider.loadLinks(forceRefresh: true);
      listsProvider.loadLists(forceRefresh: true);
      widget.onRefresh?.call();
    }
  }

  String? _getThumbnailUrl(SavedLink link) {
    // First, try custom thumbnail (local file path takes priority)
    if (link.customThumbnailPath != null &&
        link.customThumbnailPath!.isNotEmpty) {
      return link.customThumbnailPath!;
    }

    // Then try saved thumbnail URL
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
            child: Builder(
              builder: (context) {
                // Calculate available links once, not in itemBuilder
                final availableLinks = widget.savedLinks
                    .where((l) => !_dismissedLinkIds.contains(l.id))
                    .take(10)
                    .toList();

                if (availableLinks.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No links to display',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 16.0,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: availableLinks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SavedLink link = availableLinks[index];
                    final thumbnailUrl = _getThumbnailUrl(link);

                    // Build the card widget
                    Widget card = _buildHorizontalLinkCard(
                      context,
                      link,
                      thumbnailUrl,
                    );

                    // Wrap in Dismissible only if swipe actions are enabled
                    if (!widget.enableSwipeActions) {
                      return card;
                    }

                    return Dismissible(
                      key: Key(link.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: link.isFavorite ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: Icon(
                          link.isFavorite ? Icons.star_border : Icons.star,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      secondaryBackground: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // For delete, show confirmation
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                            // Handle delete immediately
                            _handleDelete(link);
                          }
                          return confirmed ?? false;
                        } else if (direction == DismissDirection.startToEnd) {
                          // For favorite toggle, allow dismissal and handle in onDismissed
                          return true;
                        }
                        return false;
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.startToEnd) {
                          // Swipe right - Toggle favorite
                          // Mark as dismissed immediately to prevent Dismissible error
                          setState(() {
                            _dismissedLinkIds.add(link.id);
                          });
                          // Schedule async operation after current frame to ensure widget is removed
                          Future.microtask(() => _handleFavoriteToggle(link));
                        }
                      },
                      child: card,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLinkCard(
    BuildContext context,
    SavedLink link,
    String? thumbnailUrl,
  ) {
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
                    link.isFavorite
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',
                    style: TextStyle(
                      color: link.isFavorite ? Colors.amber : Colors.white,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final linksProvider = context.read<LinksProvider>();
                    await linksProvider.toggleFavorite(link.id);
                    widget.onRefresh?.call();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _shareLink(link);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
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
                  leading: const Icon(Icons.delete, color: Colors.red),
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
                  leading: const Icon(Icons.close, color: Colors.white),
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
            // Use ThumbnailImage widget for consistent thumbnail handling
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: ThumbnailImage(
                link: link,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Favorite button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  final linksProvider = context.read<LinksProvider>();
                  await linksProvider.toggleFavorite(link.id);
                  widget.onRefresh?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: link.isFavorite
                        ? Colors.amber.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: link.isFavorite
                          ? Colors.amber
                          : Colors.white.withValues(alpha: 0.3),
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
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.note, color: Colors.blue, size: 16),
                ),
              ),
            // Duration badge (for videos)
            if (link.duration != null && link.duration!.isNotEmpty)
              Positioned(
                bottom: 40,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        link.duration!,
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
                      Colors.black.withValues(alpha: 0.8),
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
  }
}
