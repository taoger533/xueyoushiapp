import 'package:flutter/material.dart';

class RefreshPagedList extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final bool isLoading;
  final bool hasMore;
  final Widget? empty;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final double loadMoreTriggerOffset;

  const RefreshPagedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.isLoading,
    required this.hasMore,
    this.empty,
    this.padding,
    this.physics,
    this.loadMoreTriggerOffset = 200,
  });

  @override
  State<RefreshPagedList> createState() => _RefreshPagedListState();
}

class _RefreshPagedListState extends State<RefreshPagedList> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoading) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - widget.loadMoreTriggerOffset) {
      widget.onLoadMore();
    }
  }

  int _computedItemCount() {
    final base = widget.itemCount == 0 ? 1 : widget.itemCount;
    final footer = widget.hasMore ? 1 : 0;
    return base + footer;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _computedItemCount(),
        itemBuilder: (context, index) {
          final baseCount = widget.itemCount;
          final hasFooter = widget.hasMore;
          final totalCount =
              (baseCount == 0 ? 1 : baseCount) + (hasFooter ? 1 : 0);

          // 空态（支持下拉）
          if (baseCount == 0) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: widget.isLoading
                      ? const CircularProgressIndicator()
                      : (widget.empty ?? const Text('暂无数据')),
                ),
              );
            }
            if (hasFooter && index == totalCount - 1) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
          }

          // 加载更多 footer
          if (hasFooter && index == totalCount - 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // 普通 item
          return widget.itemBuilder(context, index);
        },
      ),
    );
  }
}
