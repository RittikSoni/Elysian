// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:elysian/models/models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/services/link_handler.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/thumbnail_service.dart';
import 'package:elysian/widgets/multi_list_picker.dart';
import 'package:elysian/widgets/thumbnail_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SavedLinksScreen extends StatefulWidget {
  final String? listId;
  final String? listName;

  const SavedLinksScreen({super.key, this.listId, this.listName});

  @override
  State<SavedLinksScreen> createState() => _SavedLinksScreenState();
}

class _SavedLinksScreenState extends State<SavedLinksScreen> {
  List<SavedLink> _savedLinks = [];
  List<SavedLink> _filteredLinks = [];
  final Set<String> _selectedLinkIds = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  String? _selectedListId;
  String _sortBy = 'date'; // 'date', 'title', 'type'
  String _filterBy = 'all'; // 'all', 'favorites', 'type'
  LinkType? _filterType;

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
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    var filtered = List<SavedLink>.from(_savedLinks);

    // Apply filters
    if (_filterBy == 'favorites') {
      filtered = filtered.where((link) => link.isFavorite).toList();
    } else if (_filterBy == 'type' && _filterType != null) {
      filtered = filtered.where((link) => link.type == _filterType).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'title':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'type':
        filtered.sort((a, b) => a.type.toString().compareTo(b.type.toString()));
        break;
      case 'date':
      default:
        filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt)); // Newest first
        break;
    }

    setState(() {
      _filteredLinks = filtered;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedLinkIds.clear();
      }
    });
  }

  void _toggleLinkSelection(String linkId) {
    setState(() {
      if (_selectedLinkIds.contains(linkId)) {
        _selectedLinkIds.remove(linkId);
      } else {
        _selectedLinkIds.add(linkId);
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedLinkIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Links',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedLinkIds.length} link(s)?',
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
        final linksProvider = context.read<LinksProvider>();
        await linksProvider.deleteLinks(_selectedLinkIds.toList());
        await _loadLinks();
        setState(() {
          _selectedLinkIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedLinkIds.length} link(s) deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting links: $e')));
        }
      }
    }
  }

  Future<void> _bulkMoveToLists() async {
    if (_selectedLinkIds.isEmpty) return;

    List<String> selectedListIds = [];

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Move to Lists',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: MultiListPicker(
            selectedListIds: selectedListIds,
            onSelectionChanged: (listIds) {
              selectedListIds = listIds;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedListIds),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await StorageService.moveLinksToLists(
          _selectedLinkIds.toList(),
          result,
        );
        final linksProvider = context.read<LinksProvider>();
        await linksProvider.loadLinks(forceRefresh: true);
        await _loadLinks();
        setState(() {
          _selectedLinkIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Links moved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error moving links: $e')));
        }
      }
    }
  }

  Future<void> _bulkToggleFavorites(bool isFavorite) async {
    if (_selectedLinkIds.isEmpty) return;

    try {
      await StorageService.toggleFavoritesForLinks(
        _selectedLinkIds.toList(),
        isFavorite,
      );
      final linksProvider = context.read<LinksProvider>();
      await linksProvider.loadLinks(forceRefresh: true);
      await _loadLinks();
      setState(() {
        _selectedLinkIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite ? 'Added to favorites' : 'Removed from favorites',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorites: $e')));
      }
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
        await StorageService.deleteLink(link.id);
        final linksProvider = context.read<LinksProvider>();
        await linksProvider.loadLinks(forceRefresh: true);
        await _loadLinks();
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
                              ScaffoldMessenger.of(context).showSnackBar(
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
                              ScaffoldMessenger.of(context).showSnackBar(
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
                const SizedBox(height: 16),
                // Notes Field
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
                                          context,
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
                                          context,
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
        // Validate URL and get link type
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

        // Fetch title if not provided
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

        // Delete old link and create updated one
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
        await StorageService.saveLink(updatedLink);
        final linksProvider = context.read<LinksProvider>();
        await linksProvider.loadLinks(forceRefresh: true);
        await _loadLinks();

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

  Future<void> _handleFavoriteToggle(SavedLink link) async {
    final wasFavorite = link.isFavorite;
    // Update state immediately to prevent Dismissible error
    setState(() {
      final index = _filteredLinks.indexWhere((l) => l.id == link.id);
      if (index != -1) {
        _filteredLinks[index] = link.copyWith(isFavorite: !link.isFavorite);
      }
    });

    // Then do the async operation
    final linksProvider = context.read<LinksProvider>();
    await linksProvider.toggleFavorite(link.id);
    await _loadLinks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite ? 'Removed from favorites' : 'Added to favorites',
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              final linksProvider = context.read<LinksProvider>();
              await linksProvider.toggleFavorite(link.id);
              await _loadLinks();
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
      await _loadLinks();
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

  Future<void> _shareLink(SavedLink link) async {
    final shareText = '${link.title}\n${link.url}';
    if (link.description != null && link.description!.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          subject: link.title,
          text: '$shareText\n\n${link.description}',
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(subject: link.title, text: shareText),
      );
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
      switch (link.type) {
        case LinkType.youtube:
          final videoId = LinkParser.extractYouTubeVideoId(link.url);
          if (videoId != null) {
            thumbnailUrl =
                'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          }
          break;
        case LinkType.vimeo:
        case LinkType.googledrive:
        case LinkType.instagram:
        case LinkType.directVideo:
        case LinkType.web:
        case LinkType.unknown:
          // These don't have easy thumbnail access
          break;
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
        listIds: link.listIds, // Keep existing listIds
        savedAt: link.savedAt,
        isFavorite: link.isFavorite,
        notes: link.notes,
        lastViewedAt: link.lastViewedAt,
        viewCount: link.viewCount,
      );
      await StorageService.saveLink(updatedLink);
      final linksProvider = context.read<LinksProvider>();
      await linksProvider.loadLinks(forceRefresh: true);
      await _loadLinks();

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing title: $e')));
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
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            if (_isSelectionMode) {
              _toggleSelectionMode();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSelectionMode
            ? Text(
                '${_selectedLinkIds.length} selected',
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                widget.listName ?? 'Saved Links',
                style: const TextStyle(color: Colors.white),
              ),
        actions: _isSelectionMode
            ? [
                if (_selectedLinkIds.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.star_border, color: Colors.amber),
                    onPressed: () => _bulkToggleFavorites(true),
                    tooltip: 'Add to Favorites',
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder, color: Colors.white),
                    onPressed: _bulkMoveToLists,
                    tooltip: 'Move to Lists',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _bulkDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ]
            : [
                // Sort/Filter menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  color: Colors.grey[900],
                  onSelected: (value) {
                    if (value.startsWith('sort_')) {
                      setState(() {
                        _sortBy = value.replaceFirst('sort_', '');
                        _applyFiltersAndSort();
                      });
                    } else if (value.startsWith('filter_')) {
                      setState(() {
                        _filterBy = value.replaceFirst('filter_', '');
                        if (_filterBy == 'type') {
                          _showTypeFilterDialog();
                        } else {
                          _filterType = null;
                          _applyFiltersAndSort();
                        }
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'Sort By',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_date',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'date' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Date',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_title',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'title' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Title',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_type',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'type' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Type',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'Filter By',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'filter_all',
                      child: Row(
                        children: [
                          Icon(
                            _filterBy == 'all' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'All',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'filter_favorites',
                      child: Row(
                        children: [
                          Icon(
                            _filterBy == 'favorites' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Favorites',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'filter_type',
                      child: Row(
                        children: [
                          Icon(
                            _filterBy == 'type' ? Icons.check : null,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'By Type',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Selection mode toggle
                IconButton(
                  icon: const Icon(Icons.checklist, color: Colors.white),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Select Multiple',
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredLinks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No saved links',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredLinks.length,
              itemBuilder: (context, index) {
                final link = _filteredLinks[index];
                final isSelected = _selectedLinkIds.contains(link.id);

                return Dismissible(
                  key: Key(link.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: link.isFavorite ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(4),
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
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
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
                      // Remove from list immediately to prevent Dismissible error
                      setState(() {
                        _filteredLinks.removeWhere((l) => l.id == link.id);
                      });
                      // Schedule async operation after current frame to ensure widget is removed
                      Future.microtask(() => _handleFavoriteToggle(link));
                    }
                  },
                  child: Card(
                    color: isSelected
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.grey[900],
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: _isSelectionMode
                          ? () => _toggleLinkSelection(link.id)
                          : () => LinkHandler.openLink(
                              context,
                              link.url,
                              linkType: link.type,
                              title: link.title,
                              description: link.description,
                              linkId: link.id,
                            ),
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          _toggleSelectionMode();
                          _toggleLinkSelection(link.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selection checkbox
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (value) =>
                                      _toggleLinkSelection(link.id),
                                  activeColor: Colors.blue,
                                ),
                              ),
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: ThumbnailImage(
                                link: link,
                                width: 120,
                                height: 90,
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
                                        _getIconForType(link.type),
                                        color: Colors.grey[500],
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTypeLabel(link.type),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (link.duration != null &&
                                          link.duration!.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.grey[500],
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              link.duration!,
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Actions
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              color: Colors.grey[900],
                              onSelected: (value) {
                                switch (value) {
                                  case 'share':
                                    _shareLink(link);
                                    break;
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
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.share,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Share',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'refresh',
                                  child: Text(
                                    'Refresh Title',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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

  Future<void> _showTypeFilterDialog() async {
    final result = await showDialog<LinkType>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Filter by Type',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LinkType.values.map((type) {
            return ListTile(
              leading: Icon(_getIconForType(type), color: Colors.white),
              title: Text(
                _getTypeLabel(type),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, type),
            );
          }).toList(),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _filterType = result;
        _applyFiltersAndSort();
      });
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
