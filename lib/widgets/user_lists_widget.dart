import 'package:elysian/models/models.dart';
import 'package:elysian/screens/saved_links_screen.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:flutter/material.dart';

class UserListsWidget extends StatefulWidget {
  final VoidCallback? onRefresh;

  const UserListsWidget({
    super.key,
    this.onRefresh,
  });

  @override
  State<UserListsWidget> createState() => _UserListsWidgetState();
}

class _UserListsWidgetState extends State<UserListsWidget> {
  List<UserList> _lists = [];
  List<UserList> _filteredLists = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLists();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterLists();
    });
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      _filteredLists = List.from(_lists);
    } else {
      _filteredLists = _lists
          .where((list) =>
              list.name.toLowerCase().contains(_searchQuery) ||
              (list.description?.toLowerCase().contains(_searchQuery) ?? false))
          .toList();
    }
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await StorageService.getUserLists();
      // Sort lists: default list first, then by name
      lists.sort((a, b) {
        if (a.id == StorageService.defaultListId) return -1;
        if (b.id == StorageService.defaultListId) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      setState(() {
        _lists = lists;
        _filterLists();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _refresh() {
    _loadLists();
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Lists',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  // Search Icon Button
                  IconButton(
                    icon: Icon(
                      _searchQuery.isNotEmpty
                          ? Icons.close
                          : Icons.search,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_searchQuery.isNotEmpty) {
                        _searchController.clear();
                      }
                    },
                  ),
                  // Refresh Icon Button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refresh,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search Bar (if searching)
        if (_searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search lists...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
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
            ),
          ),
        // Lists Content
        if (_isLoading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredLists.isEmpty)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_outlined,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No lists found'
                        : 'No lists yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: _filteredLists.length,
              itemBuilder: (context, index) {
                final list = _filteredLists[index];
                return _buildListCard(list);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildListCard(UserList list) {
    final isDefault = list.id == StorageService.defaultListId;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavedLinksScreen(
              listId: list.id,
              listName: list.name,
            ),
          ),
        ).then((_) => _refresh());
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDefault ? Colors.amber : Colors.grey[800]!,
            width: isDefault ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and Star (for default list)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDefault ? Colors.amber.withOpacity(0.2) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder,
                      color: isDefault ? Colors.amber : Colors.white,
                      size: 24,
                    ),
                  ),
                  if (isDefault)
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 20,
                    ),
                ],
              ),
            ),
            // List Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                list.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Item Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                '${list.itemCount} ${list.itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            // Description (if available)
            if (list.description != null && list.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  list.description!,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

}

