import 'package:elysian/data/data.dart';
import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';

class ComingSoonScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const ComingSoonScreen({super.key, this.onNavigateToTab});

  @override
  ComingSoonScreenState createState() => ComingSoonScreenState();
}

class ComingSoonScreenState extends State<ComingSoonScreen> {
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.only(
                top: 100.0,
                left: 20.0,
                right: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'New releases coming to Elysian',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16.0),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20.0),
            sliver: SliverToBoxAdapter(
              child: ContentList(
                title: 'This Week',
                contentList: originals,
                isOriginals: false,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentList(
              title: 'Next Week',
              contentList: trending,
              isOriginals: false,
            ),
          ),
          SliverToBoxAdapter(
            child: ContentList(
              title: 'Later This Month',
              contentList: myList,
              isOriginals: false,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
            sliver: SliverToBoxAdapter(
              child: ContentList(
                title: 'Coming Next Month',
                contentList: previews,
                isOriginals: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
