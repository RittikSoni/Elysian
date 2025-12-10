import 'package:elysian/models/models.dart';
import 'package:elysian/services/link_parser.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:flutter/material.dart';

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
  List<UserList> _lists = [];
  String? _selectedListId;
  bool _isLoading = false;
  bool _isFetchingTitle = false;
  LinkType? _detectedLinkType;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId ?? StorageService.defaultListId;
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    _loadLists();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
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
    } catch (e) {
      // Silently fail, user can enter title manually
    } finally {
      if (mounted) {
        setState(() => _isFetchingTitle = false);
      }
    }
  }

  Future<void> _loadLists() async {
    try {
      final lists = await StorageService.getUserLists();
      setState(() {
        _lists = lists;
        if (_selectedListId == null && lists.isNotEmpty) {
          _selectedListId = lists.first.id;
        }
      });
    } catch (e) {
      // Handle error
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

    if (_selectedListId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a list')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Generate thumbnail URL based on link type
      String? thumbnailUrl;
      if (_detectedLinkType == LinkType.youtube) {
        final videoId = LinkParser.extractYouTubeVideoId(url);
        if (videoId != null) {
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        }
      }

      final savedLink = SavedLink(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: url,
        title: title,
        thumbnailUrl: thumbnailUrl,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        type: _detectedLinkType!,
        listId: _selectedListId!,
        savedAt: DateTime.now(),
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
                          _detectedLinkType == LinkType.youtube
                              ? Icons.play_circle_outline
                              : Icons.photo_outlined,
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
                      _detectedLinkType == LinkType.youtube
                          ? Icons.play_circle_outline
                          : Icons.photo_outlined,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _detectedLinkType == LinkType.youtube
                          ? 'YouTube link detected'
                          : 'Instagram link detected',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ],
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
              // List Selection
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _selectedListId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Save to List',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  items: _lists.map((list) {
                    return DropdownMenuItem<String>(
                      value: list.id,
                      child: Row(
                        children: [
                          if (list.id == StorageService.defaultListId)
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                          if (list.id == StorageService.defaultListId)
                            const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              list.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${list.itemCount})',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedListId = value;
                    });
                  },
                ),
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
}
