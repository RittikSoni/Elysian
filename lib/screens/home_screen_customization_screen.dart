import 'package:elysian/models/home_screen_section.dart';
import 'package:elysian/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreenCustomizationScreen extends StatefulWidget {
  const HomeScreenCustomizationScreen({super.key});

  @override
  State<HomeScreenCustomizationScreen> createState() =>
      _HomeScreenCustomizationScreenState();
}

class _HomeScreenCustomizationScreenState
    extends State<HomeScreenCustomizationScreen> {
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
        title: const Text(
          'Customize Home Screen',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Consumer2<HomeScreenLayoutProvider, ListsProvider>(
            builder: (context, layoutProvider, listsProvider, child) {
              return IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Add List Section',
                onPressed: () {
                  _showAddListSectionDialog(context, layoutProvider, listsProvider);
                },
              );
            },
          ),
          Consumer<HomeScreenLayoutProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Reset to Default',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Reset Layout',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Are you sure you want to reset to default layout?',
                        style: TextStyle(color: Colors.white70),
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
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await provider.resetToDefault();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Layout reset to default'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<HomeScreenLayoutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final sections = provider.sections;

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            onReorder: (oldIndex, newIndex) {
              provider.reorderSections(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              return _SectionTile(
                key: ValueKey(section.id),
                section: section,
                onVisibilityChanged: (isVisible) {
                  provider.setSectionVisibility(section.id, isVisible);
                },
                onConfigure: () {
                  _showSectionConfigDialog(context, section, provider);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showSectionConfigDialog(
    BuildContext context,
    HomeScreenSection section,
    HomeScreenLayoutProvider provider,
  ) {
    if (section.type == HomeSectionType.userList) {
      _showUserListConfig(context, section, provider);
    } else if (section.type == HomeSectionType.header) {
      _showHeaderConfig(context, section, provider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This section cannot be configured'),
          backgroundColor: Colors.amber,
        ),
      );
    }
  }

  void _showHeaderConfig(
    BuildContext context,
    HomeScreenSection section,
    HomeScreenLayoutProvider provider,
  ) {
    final linksProvider = Provider.of<LinksProvider>(context, listen: false);
    final allLinks = linksProvider.allLinks;
    final currentLinkId = section.config?['linkId'] as String?;

    if (allLinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved links available. Add some links first.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Configure Featured Section',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Select Featured Link:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: allLinks.length,
                    itemBuilder: (context, index) {
                      final link = allLinks[index];
                      final isSelected = currentLinkId == link.id;
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Image.network(
                              link.thumbnailUrl ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.link, color: Colors.white),
                                );
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          link.title,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          link.description ?? link.url,
                          style: TextStyle(color: Colors.grey[400]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.amber)
                            : null,
                        onTap: () {
                          provider.updateSectionConfig(section.id, {
                            'linkId': link.id,
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserListConfig(
    BuildContext context,
    HomeScreenSection section,
    HomeScreenLayoutProvider provider,
  ) {
    final listsProvider = Provider.of<ListsProvider>(context, listen: false);
    final userLists = listsProvider.allLists;
    final currentListId = section.config?['listId'] as String?;
    final currentLayout = section.config?['layout'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Configure List Section',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List Selection
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Select List:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: userLists.length,
                    itemBuilder: (context, index) {
                      final list = userLists[index];
                      final isSelected = currentListId == list.id;
                      return ListTile(
                        title: Text(
                          list.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${list.itemCount} items',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.amber)
                            : null,
                        onTap: () {
                          final newConfig = Map<String, dynamic>.from(section.config ?? {});
                          newConfig['listId'] = list.id;
                          if (newConfig['layout'] == null) {
                            newConfig['layout'] = ListLayoutStyle.rectangle.toString();
                          }
                          provider.updateSectionConfig(section.id, newConfig);
                          Navigator.pop(context);
                          // Reopen dialog to show layout options
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (context.mounted) {
                              _showUserListConfig(context, section, provider);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Layout Selection
              if (currentListId != null) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Select Layout:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ListLayoutStyle.values.map((layout) {
                    final isSelected = currentLayout == layout.toString();
                    return ChoiceChip(
                      label: Text(_getLayoutName(layout)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          final newConfig = Map<String, dynamic>.from(section.config ?? {});
                          newConfig['layout'] = layout.toString();
                          provider.updateSectionConfig(section.id, newConfig);
                          Navigator.pop(context);
                        }
                      },
                      selectedColor: Colors.amber,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getLayoutName(ListLayoutStyle layout) {
    switch (layout) {
      case ListLayoutStyle.circular:
        return 'Circular';
      case ListLayoutStyle.rectangle:
        return 'Rectangle';
      case ListLayoutStyle.smaller:
        return 'Smaller';
      case ListLayoutStyle.medium:
        return 'Medium';
      case ListLayoutStyle.square:
        return 'Square';
      case ListLayoutStyle.large:
        return 'Large';
    }
  }

  void _showAddListSectionDialog(
    BuildContext context,
    HomeScreenLayoutProvider layoutProvider,
    ListsProvider listsProvider,
  ) {
    final userLists = listsProvider.allLists;
    if (userLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No lists available. Create a list first.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Add List Section',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: userLists.length,
            itemBuilder: (context, index) {
              final list = userLists[index];
              // Check if this list is already added
              final existingSection = layoutProvider.getSectionById('list_${list.id}');
              if (existingSection != null) {
                return const SizedBox.shrink();
              }

              return ListTile(
                title: Text(
                  list.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${list.itemCount} items',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await layoutProvider.addListContentSection(
                    list.id,
                    list.name,
                  );

                  // Update config with default layout
                  final newSection = layoutProvider.getSectionById('list_${list.id}');
                  if (newSection != null) {
                    await layoutProvider.updateSectionConfig(
                      newSection.id,
                      {
                        'listId': list.id,
                        'layout': ListLayoutStyle.rectangle.toString(),
                      },
                    );
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${list.name} added to home screen'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final HomeScreenSection section;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onConfigure;

  const _SectionTile({
    required this.section,
    required this.onVisibilityChanged,
    required this.onConfigure,
    super.key,
  });

  IconData _getSectionIcon(HomeSectionType type) {
    switch (type) {
      case HomeSectionType.header:
        return Icons.movie;
      case HomeSectionType.userList:
        return Icons.playlist_play;
      case HomeSectionType.favorites:
        return Icons.favorite;
      case HomeSectionType.recentActivity:
        return Icons.history;
      case HomeSectionType.suggestions:
        return Icons.lightbulb;
      case HomeSectionType.savedLinks:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getSectionIcon(section.type),
          color: section.isVisible ? Colors.white : Colors.grey[600],
        ),
        title: Text(
          section.title,
          style: TextStyle(
            color: section.isVisible ? Colors.white : Colors.grey[600],
            decoration: section.isVisible
                ? TextDecoration.none
                : TextDecoration.lineThrough,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Configure button (only for configurable sections)
            if (section.type == HomeSectionType.userList ||
                section.type == HomeSectionType.header)
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                onPressed: onConfigure,
                tooltip: 'Configure',
              ),
            // Visibility toggle
            Switch(
              value: section.isVisible,
              onChanged: onVisibilityChanged,
              activeColor: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

