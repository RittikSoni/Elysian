import 'package:flutter/material.dart';
import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/link_parser.dart';

class ListSelectionDialog extends StatefulWidget {
  final String sharedUrl;
  final String? sharedTitle;
  final VoidCallback? onLinkSaved;

  const ListSelectionDialog({
    super.key,
    required this.sharedUrl,
    this.sharedTitle,
    this.onLinkSaved,
  });

  @override
  State<ListSelectionDialog> createState() => _ListSelectionDialogState();
}

class _ListSelectionDialogState extends State<ListSelectionDialog> {
  List<UserList> _lists = [];
  bool _isLoading = true;
  bool _isCreatingList = false;
  final TextEditingController _newListNameController = TextEditingController();
  final TextEditingController _newListDescriptionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await StorageService.getUserLists();
      setState(() {
        _lists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
      await StorageService.createUserList(
        name,
        description: description.isEmpty ? null : description,
      );
      _newListNameController.clear();
      _newListDescriptionController.clear();
      await _loadLists();
      setState(() => _isCreatingList = false);
      Navigator.of(context).pop(); // Close create dialog
    } catch (e) {
      setState(() => _isCreatingList = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _saveToList(String listId) async {
    // Verify the list exists before saving
    try {
      final allLists = await StorageService.getUserLists();
      if (!allLists.any((l) => l.id == listId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List not found. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final linkType = LinkParser.parseLinkType(widget.sharedUrl);
      if (linkType == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid link type')));
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Fetch actual title from URL
      String title = widget.sharedTitle ?? 'Shared Link';
      try {
        title = await LinkParser.fetchTitleFromUrl(widget.sharedUrl, linkType);
      } catch (e) {
        // Use fallback title if fetch fails
        print('Error fetching title: $e');
      }

      // Fetch metadata (thumbnail, description) from URL
      final metadata = await LinkParser.fetchMetadataFromUrl(widget.sharedUrl, linkType);
      final thumbnailUrl = metadata['thumbnailUrl'];
      final description = metadata['description'];

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      final savedLink = SavedLink(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: widget.sharedUrl,
        title: title,
        thumbnailUrl: thumbnailUrl,
        description: description,
        type: linkType,
        listIds: [listId], // Convert single listId to listIds
        savedAt: DateTime.now(),
      );

      await StorageService.saveLink(savedLink);
      
      if (mounted) {
        Navigator.of(context).pop();

        // Trigger refresh callback
        widget.onLinkSaved?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close list selection dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving link: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showCreateListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Create New List',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newListNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'List Name',
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
                controller: _newListDescriptionController,
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
            onPressed: () {
              Navigator.of(context).pop();
              _newListNameController.clear();
              _newListDescriptionController.clear();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCreatingList ? null : _createNewList,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: _isCreatingList
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newListNameController.dispose();
    _newListDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save to List',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.sharedTitle ?? 'Shared Link',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lists.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _lists.length) {
                      return ListTile(
                        leading: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Create New List',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: _showCreateListDialog,
                      );
                    }

                    final list = _lists[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.playlist_add,
                        color: Colors.white,
                      ),
                      title: Text(
                        list.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${list.itemCount} items',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: list.id == StorageService.defaultListId
                          ? const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            )
                          : null,
                      onTap: () => _saveToList(list.id),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
