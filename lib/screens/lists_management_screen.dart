import 'package:elysian/models/models.dart';
import 'package:elysian/providers/providers.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:elysian/services/export_import_service.dart';
import 'package:elysian/widgets/add_link_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

class ListsManagementScreen extends StatefulWidget {
  const ListsManagementScreen({super.key});

  @override
  State<ListsManagementScreen> createState() => _ListsManagementScreenState();
}

class _ListsManagementScreenState extends State<ListsManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize providers if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listsProvider = context.read<ListsProvider>();
      final linksProvider = context.read<LinksProvider>();
      
      if (!listsProvider.isInitialized) {
        listsProvider.initialize();
      }
      if (!linksProvider.isInitialized) {
        linksProvider.initialize();
      }
    });
  }

  Future<void> _showAddLinkDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddLinkDialog(),
    );

    if (result == true) {
      // Refresh providers
      final listsProvider = context.read<ListsProvider>();
      final linksProvider = context.read<LinksProvider>();
      await Future.wait([
        listsProvider.loadLists(forceRefresh: true),
        linksProvider.loadLinks(forceRefresh: true),
      ]);
    }
  }

  Future<void> _createNewList() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
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
                controller: nameController,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final listsProvider = context.read<ListsProvider>();
        await listsProvider.createList(
          result['name']!,
          description: result['description']!.isEmpty
              ? null
              : result['description'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List created successfully'),
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
      }
    }
  }

  Future<void> _editList(UserList list) async {
    if (list.id == StorageService.defaultListId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit the default list')),
      );
      return;
    }

    final nameController = TextEditingController(text: list.name);
    final descriptionController = TextEditingController(
      text: list.description ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Edit List', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              }
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
      // Note: StorageService doesn't have update method, so we'll need to add it
      // For now, delete and recreate (not ideal but works)
      try {
        final links = await StorageService.getSavedLinksByList(list.id);

        // Delete old list
        await StorageService.deleteUserList(list.id);

        // Create new list with updated name
        final updatedList = await StorageService.createUserList(
          result['name']!,
          description: result['description']!.isEmpty
              ? null
              : result['description'],
        );

        // Move all links to new list
        for (var link in links) {
          await StorageService.deleteLink(link.id);
          final updatedLink = SavedLink(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            url: link.url,
            title: link.title,
            thumbnailUrl: link.thumbnailUrl,
            description: link.description,
            type: link.type,
            listIds: [updatedList.id], // Convert single listId to listIds
            savedAt: link.savedAt,
          );
          await StorageService.saveLink(updatedLink);
        }

        final listsProvider = context.read<ListsProvider>();
        final linksProvider = context.read<LinksProvider>();
        await Future.wait([
          listsProvider.loadLists(forceRefresh: true),
          linksProvider.loadLinks(forceRefresh: true),
        ]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating list: $e')));
        }
      }
    }
  }

  Future<void> _shareList(UserList list) async {
    try {
      final links = await StorageService.getSavedLinksByList(list.id);
      
      if (links.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This list is empty')),
        );
        return;
      }

      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Export list to file
      final filePath = await ExportImportService.exportListToFile(list.id);
      
      // Close loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (filePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error creating export file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Share the file
      final shared = await ExportImportService.shareListFile(filePath, list.name);
      
      if (!shared && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sharing file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing list: $e')),
        );
      }
    }
  }

  Future<void> _importList() async {
    debugPrint('Import List: Button pressed, function called');
    
    // Show immediate feedback that button was pressed
    if (!mounted) return;
    
    try {
      debugPrint('Import List: Starting file picker...');
      
      // Pick file using file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Elysian List File (.elysian)',
        allowMultiple: false,
      );

      debugPrint('Import List: File picker result: ${result != null}');

      if (result == null || result.files.isEmpty) {
        debugPrint('Import List: User cancelled or no file selected');
        return; // User cancelled
      }

      final filePath = result.files.single.path;
      debugPrint('Import List: Selected file path: $filePath');
      
      if (filePath == null) {
        debugPrint('Import List: File path is null');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Could not access file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate file format before importing
      debugPrint('Import List: Validating file format...');
      final isValid = await ExportImportService.isValidElysianFile(filePath);
      debugPrint('Import List: File is valid: $isValid');
      
      if (!isValid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid file format. Please select a valid .elysian list file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      debugPrint('Import List: Starting import...');
      // Import the list
      final importResult = await ExportImportService.importListFromFile(filePath);
      debugPrint('Import List: Import result - success: ${importResult.success}, error: ${importResult.error}');
      
      // Close loading
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Refresh providers
      debugPrint('Import List: Refreshing providers...');
      final listsProvider = context.read<ListsProvider>();
      final linksProvider = context.read<LinksProvider>();
      await Future.wait([
        listsProvider.loadLists(forceRefresh: true),
        linksProvider.loadLinks(forceRefresh: true),
      ]);

      if (mounted) {
        if (importResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message ?? 'List imported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.error ?? 'Error importing list'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Import List: Exception caught: $e');
      debugPrint('Import List: Stack trace: $stackTrace');
      if (context.mounted) {
        // Close loading if still open
        try {
          Navigator.pop(context);
        } catch (_) {
          // Dialog might not be open
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing list: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteList(UserList list) async {
    if (list.id == StorageService.defaultListId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the default list')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete List', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${list.name}"? All links in this list will be moved to "My List".',
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
        final listsProvider = context.read<ListsProvider>();
        final linksProvider = context.read<LinksProvider>();
        await listsProvider.deleteList(list.id);
        await linksProvider.loadLinks(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting list: $e')));
        }
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
        title: const Text('My Lists', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.link, color: Colors.white),
            onPressed: _showAddLinkDialog,
            tooltip: 'Add Link',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              debugPrint('Import List button pressed');
              _importList();
            },
            tooltip: 'Import List',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createNewList,
            tooltip: 'Create New List',
          ),
          Consumer<ListsProvider>(
            builder: (context, listsProvider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => listsProvider.loadLists(forceRefresh: true),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<ListsProvider>(
        builder: (context, listsProvider, child) {
          if (listsProvider.isLoading && !listsProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final lists = listsProvider.allLists;
          
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_add, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No lists yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showAddLinkDialog,
                        icon: const Icon(Icons.link),
                        label: const Text('Add Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _createNewList,
                        icon: const Icon(Icons.add),
                        label: const Text('Create List'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                final isDefault = list.id == StorageService.defaultListId;

                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SavedLinksScreen(
                            listId: list.id,
                            listName: list.name,
                        ),
                      ),
                    ).then((_) {
                      // Refresh lists when returning
                      context.read<ListsProvider>().loadLists(forceRefresh: true);
                    });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isDefault ? Icons.star : Icons.playlist_play,
                            color: isDefault ? Colors.amber : Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        list.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Default',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (list.description != null &&
                                    list.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    list.description!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '${list.itemCount} ${list.itemCount == 1 ? 'item' : 'items'}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isDefault)
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.white,
                              ),
                              color: Colors.grey[900],
                              onSelected: (value) {
                                switch (value) {
                                  case 'share':
                                    _shareList(list);
                                    break;
                                  case 'edit':
                                    _editList(list);
                                    break;
                                  case 'delete':
                                    _deleteList(list);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, color: Colors.white, size: 20),
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
                );
              },
            );
        },
      ),
    );
  }
}
