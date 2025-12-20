// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/thumbnail_service.dart';
import 'package:elysian/widgets/multi_list_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddLinkDialog extends StatefulWidget {
  final String? initialListId;
  final String? initialTitle;

  const AddLinkDialog({super.key, this.initialListId, this.initialTitle});

  @override
  State<AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<AddLinkDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _newListNameController = TextEditingController();
  final TextEditingController _newListDescriptionController =
      TextEditingController();
  final GlobalKey _listPickerKey = GlobalKey();
  List<String> _selectedListIds = [];
  bool _isLoading = false;
  bool _isFetchingTitle = false;
  bool _isCreatingList = false;
  bool _showCreateListForm = false;
  bool _isFavorite = false;
  LinkType? _detectedLinkType;
  File? _customThumbnailFile;
  String? _customThumbnailUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedListIds = widget.initialListId != null
        ? [widget.initialListId!]
        : [StorageService.defaultListId];
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _newListNameController.dispose();
    _newListDescriptionController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      final linkType = LinkParser.parseLinkType(url);
      setState(() {
        _detectedLinkType = linkType;
      });

      // Auto-fetch title if URL is valid and title is empty
      if (linkType != null && _titleController.text.isEmpty) {
        _fetchTitle();
      }
    } else {
      setState(() {
        _detectedLinkType = null;
      });
    }
  }

  Future<void> _fetchTitle() async {
    if (_detectedLinkType == null) return;

    setState(() => _isFetchingTitle = true);
    try {
      final title = await LinkParser.fetchTitleFromUrl(
        _urlController.text.trim(),
        _detectedLinkType!,
      );
      if (mounted) {
        _titleController.text = title;
      }

      // Also fetch metadata (thumbnail, description) if not already set
      if (mounted &&
          _customThumbnailFile == null &&
          _customThumbnailUrl == null) {
        final metadata = await LinkParser.fetchMetadataFromUrl(
          _urlController.text.trim(),
          _detectedLinkType!,
        );
        if (mounted) {
          setState(() {
            if (metadata['thumbnailUrl'] != null &&
                _customThumbnailUrl == null) {
              _customThumbnailUrl = metadata['thumbnailUrl'];
            }
            if (metadata['description'] != null &&
                _descriptionController.text.isEmpty) {
              _descriptionController.text = metadata['description']!;
            }
          });
        }
      }
    } catch (e) {
      // Silently fail, user can enter title manually
    } finally {
      if (mounted) {
        setState(() => _isFetchingTitle = false);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _customThumbnailFile = File(image.path);
          _customThumbnailUrl = null; // Clear URL if file is selected
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _customThumbnailFile = File(image.path);
          _customThumbnailUrl = null; // Clear URL if file is selected
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
      }
    }
  }

  Future<void> _showThumbnailUrlDialog() async {
    final urlController = TextEditingController(text: _customThumbnailUrl);
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
              borderSide: BorderSide(color: Colors.grey[700]!),
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
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result.isEmpty) {
          _customThumbnailUrl = null;
        } else {
          _customThumbnailUrl = result;
          _customThumbnailFile = null; // Clear file if URL is set
        }
      });
    }
  }

  Future<void> _createNewList() async {
    final name = _newListNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a list name')));
      return;
    }

    setState(() => _isCreatingList = true);
    try {
      final description = _newListDescriptionController.text.trim();
      final newList = await StorageService.createUserList(
        name,
        description: description.isEmpty ? null : description,
      );

      // Add the newly created list to selected lists
      setState(() {
        _selectedListIds.add(newList.id);
        _showCreateListForm = false;
      });

      _newListNameController.clear();
      _newListDescriptionController.clear();

      // Refresh the list picker to show the new list
      final state = _listPickerKey.currentState;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingList = false);
      }
    }
  }

  Future<void> _saveLink() async {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a URL')));
      return;
    }

    if (_detectedLinkType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid URL. Must be YouTube or Instagram link.'),
        ),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (_selectedListIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one list')),
      );
      return;
    }

    // Check for duplicates
    final duplicates = await StorageService.findDuplicates(url);
    if (duplicates.isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Duplicate Link Found',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'This link already exists in your saved links:\n\n${duplicates.map((l) => l.title).join('\n')}\n\nDo you want to add it anyway?',
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final linkId = DateTime.now().millisecondsSinceEpoch.toString();

      // Handle custom thumbnail
      String? customThumbnailPath;
      String? thumbnailUrl;

      if (_customThumbnailFile != null) {
        // Save local thumbnail
        customThumbnailPath = await ThumbnailService.saveThumbnail(
          _customThumbnailFile!,
          linkId,
        );
      } else if (_customThumbnailUrl != null &&
          _customThumbnailUrl!.isNotEmpty) {
        // Use custom URL
        thumbnailUrl = _customThumbnailUrl;
      } else {
        // Generate thumbnail URL based on link type
        switch (_detectedLinkType!) {
          case LinkType.youtube:
            final videoId = LinkParser.extractYouTubeVideoId(url);
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
            // Try to fetch metadata for these types
            try {
              final metadata = await LinkParser.fetchMetadataFromUrl(
                url,
                _detectedLinkType!,
              );
              thumbnailUrl = metadata['thumbnailUrl'];
              if (metadata['description'] != null &&
                  _descriptionController.text.isEmpty) {
                _descriptionController.text = metadata['description']!;
              }
            } catch (e) {
              // Silently fail
            }
            break;
        }
      }

      final savedLink = SavedLink(
        id: linkId,
        url: url,
        title: title,
        thumbnailUrl: thumbnailUrl,
        customThumbnailPath: customThumbnailPath,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        type: _detectedLinkType!,
        listIds: _selectedListIds,
        savedAt: DateTime.now(),
        isFavorite: _isFavorite,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        duration: null, // Duration can be fetched separately if needed
      );

      await StorageService.saveLink(savedLink);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Link',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // URL Field
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'URL',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText:
                      'https://youtube.com/... or https://instagram.com/...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  suffixIcon: _isFetchingTitle
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _detectedLinkType != null
                      ? Icon(
                          _getIconForType(_detectedLinkType!),
                          color: Colors.green,
                        )
                      : null,
                ),
              ),
              if (_detectedLinkType != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getIconForType(_detectedLinkType!),
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_getTypeLabel(_detectedLinkType!)} link detected',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ],
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
                  if (_customThumbnailFile != null ||
                      _customThumbnailUrl != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _customThumbnailFile = null;
                          _customThumbnailUrl = null;
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
              if (_customThumbnailFile != null || _customThumbnailUrl != null)
                Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _customThumbnailFile != null
                        ? Image.file(
                            _customThumbnailFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.network(
                            _customThumbnailUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
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
                      onPressed: _pickImageFromGallery,
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
                      onPressed: _pickImageFromCamera,
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
                      onPressed: _showThumbnailUrlDialog,
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('URL', style: TextStyle(fontSize: 12)),
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
              // Title Field
              TextField(
                controller: _titleController,
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
              // Description Field
              TextField(
                controller: _descriptionController,
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
              // Notes Field
              TextField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: 'Add personal notes about this link...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
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
                    value: _isFavorite,
                    onChanged: (value) {
                      setState(() {
                        _isFavorite = value;
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
                      setState(() {
                        _showCreateListForm = !_showCreateListForm;
                      });
                    },
                    icon: Icon(
                      _showCreateListForm ? Icons.close : Icons.add,
                      size: 18,
                    ),
                    label: Text(
                      _showCreateListForm ? 'Cancel' : 'New List',
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
              if (_showCreateListForm) ...[
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
                        controller: _newListNameController,
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
                        controller: _newListDescriptionController,
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
                          onPressed: _isCreatingList ? null : _createNewList,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: _isCreatingList
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
                key: _listPickerKey,
                selectedListIds: _selectedListIds,
                onSelectionChanged: (listIds) {
                  setState(() {
                    _selectedListIds = listIds;
                  });
                },
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
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
