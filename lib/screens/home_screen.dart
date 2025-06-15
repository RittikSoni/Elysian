import 'package:elysian/data/data.dart';
import 'package:flutter/material.dart';
import 'package:elysian/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  double _scollOffset = 0.0;
  @override
  void initState() {
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scollOffset = _scrollController.offset;
        });
        // context.bloc<AppBarCubit>().setOffset(_scrollController.offset);
      });
    super.initState();
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
        child: CustomAppBar(scrollOffset: _scollOffset),
        preferredSize: Size(MediaQuery.of(context).size.width, 50),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: ContentHeader(featuredContent: sintelContent),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 0),
            sliver: SliverToBoxAdapter(
              child: Previews(
                key: PageStorageKey(
                  'previews',
                ), //(maintain scroll postions) used to maintain the page current state if we change tab it will reamin same as we leave this page
                title: 'previews',
                contentList: previews,
              ),
            ),
          ),
          SliverToBoxAdapter(
            key: PageStorageKey('mylist'),
            child: ContentList(
              title: 'My List',
              contentList: myList,
              isOriginals: false,
            ),
          ),
          SliverToBoxAdapter(
            key: PageStorageKey('originals'),
            child: ContentList(
              title: 'Netflix Originals',
              contentList: originals,
              isOriginals: true,
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: 20.0),
            sliver: SliverToBoxAdapter(
              child: ContentList(
                key: PageStorageKey('trending'),
                title: 'Trending',
                contentList: trending,
                isOriginals: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
