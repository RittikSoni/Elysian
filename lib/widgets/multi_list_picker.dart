import 'package:elysian/models/models.dart';
import 'package:elysian/services/storage_service.dart';
import 'package:flutter/material.dart';

class MultiListPicker extends StatefulWidget {
  final List<String> selectedListIds;
  final Function(List<String>) onSelectionChanged;
  final GlobalKey? listPickerKey;

  const MultiListPicker({
    super.key,
    required this.selectedListIds,
    required this.onSelectionChanged,
    this.listPickerKey,
  });

  @override
  State<MultiListPicker> createState() => _MultiListPickerState();
}

class _MultiListPickerState extends State<MultiListPicker> {
  List<UserList> _lists = [];
  List<String> _selectedListIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedListIds = List<String>.from(widget.selectedListIds);
    _loadLists();
  }

  @override
  void didUpdateWidget(MultiListPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected list IDs if they changed externally
    if (oldWidget.selectedListIds != widget.selectedListIds) {
      _selectedListIds = List<String>.from(widget.selectedListIds);
    }
  }

  // Public method to refresh lists
  void refreshLists() {
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    final lists = await StorageService.getUserLists();
    
    // Sort lists: selected ones first, then alphabetically
    lists.sort((a, b) {
      final aSelected = _selectedListIds.contains(a.id);
      final bSelected = _selectedListIds.contains(b.id);
      
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      
      // Both selected or both not selected - sort alphabetically
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    
    setState(() {
      _lists = lists;
      _isLoading = false;
    });
  }

  void _toggleListSelection(String listId) {
    setState(() {
      if (_selectedListIds.contains(listId)) {
        // Don't allow deselecting if it's the only selected list
        if (_selectedListIds.length > 1) {
          _selectedListIds.remove(listId);
        }
      } else {
        _selectedListIds.add(listId);
      }
      
      // Re-sort with selected lists on top
      _lists.sort((a, b) {
        final aSelected = _selectedListIds.contains(a.id);
        final bSelected = _selectedListIds.contains(b.id);
        
        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;
        
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      widget.onSelectionChanged(List<String>.from(_selectedListIds));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lists.isEmpty) {
      return const Center(
        child: Text(
          'No lists available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Use Column instead of ListView.builder to avoid viewport issues
    // when nested inside SingleChildScrollView
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _lists.map((list) {
        final isSelected = _selectedListIds.contains(list.id);
        final isOnlySelection = _selectedListIds.length == 1 && isSelected;

        return CheckboxListTile(
          value: isSelected,
          onChanged: isOnlySelection
              ? null // Disable if it's the only selected list
              : (value) => _toggleListSelection(list.id),
          title: Text(
            list.name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: list.itemCount > 0
              ? Text(
                  '${list.itemCount} item${list.itemCount == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                )
              : null,
          activeColor: Colors.white,
          checkColor: Colors.black,
          tileColor: isSelected ? Colors.grey[800] : Colors.transparent,
          selected: isSelected,
        );
      }).toList(),
    );
  }
}

