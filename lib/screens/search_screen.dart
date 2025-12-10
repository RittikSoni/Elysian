import 'package:elysian/data/data.dart';
import 'package:elysian/models/models.dart';
import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';

class SearchScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const SearchScreen({super.key, this.onNavigateToTab});

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Content> _searchResults = [];
  bool _isSearching = false;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    } else {
      setState(() {
        _isSearching = true;
        _searchResults = _performSearch(query);
      });
    }
  }

  List<Content> _performSearch(String query) {
    final allContent = [
      ...previews,
      ...myList,
      ...originals,
      ...trending,
    ];
    return allContent
        .where((content) =>
            content.name.toLowerCase().contains(query) ||
            content.description.toLowerCase().contains(query))
        .toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return 6;
    } else if (Responsive.isTablet(context)) {
      return 4;
    } else {
      return 3;
    }
  }

  double _getMaxWidth(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return 1200.0;
    } else if (Responsive.isTablet(context)) {
      return 800.0;
    } else {
      return double.infinity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final maxWidth = _getMaxWidth(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size(MediaQuery.of(context).size.width, 50),
        child: CustomAppBar(
          scrollOffset: _scrollOffset,
          onNavigateToTab: widget.onNavigateToTab,
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
                vertical: isDesktop ? 120.0 : 100.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 16.0),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          hintText: 'Search for a show, movie, genre, etc.',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: value.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: isDesktop ? 20.0 : 16.0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!_isSearching)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Popular Searches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Wrap(
                          spacing: 10.0,
                          runSpacing: 10.0,
                          children: [
                            ...previews.take(isDesktop ? 12 : 6).map(
                                  (content) => _SearchChip(content: content),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_searchResults.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: isDesktop ? 80.0 : 64.0,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'No results found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isDesktop ? 20.0 : 18.0,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40.0 : 20.0,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(context),
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 10.0,
                        mainAxisSpacing: 10.0,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final content = _searchResults[index];
                        return GestureDetector(
                          onTap: () {
                            // Handle content tap
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4.0),
                              image: DecorationImage(
                                image: AssetImage(content.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
          ),
        ],
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final Content content;

  const _SearchChip({required this.content});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle chip tap - could populate search field
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Text(
          content.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
          ),
        ),
      ),
    );
  }
}

