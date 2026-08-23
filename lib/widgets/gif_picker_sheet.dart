import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helper/theme_controller.dart';
import '../models/gif_item.dart';
import '../services/gif_service.dart';

class GifPickerSheet extends StatefulWidget {
  final Function(GifItem gif) onGifSelected;
  final GifRepository? gifRepository;

  const GifPickerSheet({
    super.key,
    required this.onGifSelected,
    this.gifRepository,
  });

  static void show({
    required BuildContext context,
    required Function(GifItem gif) onGifSelected,
    GifRepository? gifRepository,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => GifPickerSheet(
        onGifSelected: onGifSelected,
        gifRepository: gifRepository,
      ),
    );
  }

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  late final GifRepository _gifService;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _gridScrollController = ScrollController();
  List<GifItem> _gifItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedCategory = 'Trending';

  // Category emojis paired with KLIPY query terms
  static const List<({String label, String emoji, String query})> _categories = [
    (label: 'Trending', emoji: '🔥', query: ''),
    (label: 'Haha', emoji: '😂', query: 'haha'),
    (label: 'Love', emoji: '❤️', query: 'love'),
    (label: 'Applause', emoji: '👏', query: 'applause'),
    (label: 'Yes', emoji: '👍', query: 'yes'),
    (label: 'No', emoji: '👎', query: 'no'),
    (label: 'Sad', emoji: '😢', query: 'sad'),
    (label: 'Dance', emoji: '💃', query: 'dance'),
    (label: 'Angry', emoji: '😡', query: 'angry'),
    (label: 'Surprised', emoji: '😮', query: 'surprised'),
    (label: 'Wink', emoji: '😉', query: 'wink'),
  ];

  @override
  void initState() {
    super.initState();
    _gifService = widget.gifRepository ?? KlipyGifService();
    _loadGifs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGifs([String query = '', bool forceRefresh = false]) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Scroll to top when category changes
    if (_gridScrollController.hasClients) {
      _gridScrollController.jumpTo(0);
    }

    try {
      final items = query.trim().isEmpty
          ? await _gifService.fetchTrending(forceRefresh: forceRefresh)
          : await _gifService.searchGifs(query, forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _gifItems = items;
          _isLoading = false;
          _hasError = items.isEmpty;
        });
      }
    } catch (e, st) {
      debugPrint('[GifPicker] error: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;
    final mq = MediaQuery.of(context);

    // iMessage-style sheet colors
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final secondaryBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    const iBlue = Color(0xFF007AFF);
    final labelColor = isDark ? Colors.white : Colors.black;
    final secondaryLabel = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return Container(
      height: mq.size.height * 0.75,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Drag indicator ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: secondaryLabel.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // ── Header: title + close ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'GIF',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                // KLIPY badge — required attribution
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: iBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'KLIPY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: iBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                // iMessage-style close button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: secondaryBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar (CupertinoSearchTextField style) ──────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: secondaryBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(CupertinoIcons.search, size: 16, color: secondaryLabel),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 15, color: labelColor),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search GIFs',
                        hintStyle: TextStyle(fontSize: 15, color: secondaryLabel),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        // Rebuild only to toggle the clear (X) icon visibility
                        setState(() {});
                      },
                      onSubmitted: (value) {
                        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                        final query = value.trim();
                        if (query.isEmpty) {
                          setState(() => _selectedCategory = 'Trending');
                          _loadGifs();
                        } else {
                          setState(() => _selectedCategory = '');
                          _loadGifs(query);
                        }
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                        setState(() => _selectedCategory = 'Trending');
                        _loadGifs();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: secondaryLabel),
                      ),
                    )
                  else
                    const SizedBox(width: 10),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Category pill chips ──────────────────────────────────
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.label;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _searchController.clear();
                    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                    setState(() => _selectedCategory = cat.label);
                    _loadGifs(cat.query);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? iBlue : secondaryBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── GIF Grid ─────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLoading
                  ? Center(
                      key: const ValueKey('loading'),
                      child: CupertinoActivityIndicator(color: secondaryLabel),
                    )
                  : _hasError
                      ? _buildErrorState(secondaryLabel, iBlue)
                      : _buildGrid(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(bool isDark) {
    final leftColumn = <GifItem>[];
    final rightColumn = <GifItem>[];

    // Distribute into 2 columns for a seamless Discord-style masonry layout
    for (int i = 0; i < _gifItems.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(_gifItems[i]);
      } else {
        rightColumn.add(_gifItems[i]);
      }
    }

    return SingleChildScrollView(
      key: const ValueKey('discord_masonry_grid'),
      controller: _gridScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftColumn
                  .map((gif) => _GifTile(
                        gif: gif,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onGifSelected(gif);
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: rightColumn
                  .map((gif) => _GifTile(
                        gif: gif,
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          widget.onGifSelected(gif);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color secondaryLabel, Color iBlue) {
    return Center(
      key: const ValueKey('error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.wifi_exclamationmark, size: 36, color: secondaryLabel),
          const SizedBox(height: 8),
          Text(
            'Could not load GIFs',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: secondaryLabel,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again',
            style: TextStyle(fontSize: 13, color: secondaryLabel.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: iBlue,
            borderRadius: BorderRadius.circular(22),
            onPressed: () => _loadGifs(
              _selectedCategory.toLowerCase() == 'trending'
                  ? ''
                  : _categories.firstWhere((c) => c.label == _selectedCategory, orElse: () => _categories.first).query,
              true,
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Individual GIF tile with press animation and Discord-style natural aspect ratio
class _GifTile extends StatefulWidget {
  final GifItem gif;
  final bool isDark;
  final VoidCallback onTap;

  const _GifTile({required this.gif, required this.isDark, required this.onTap});

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedRatio = widget.gif.aspectRatio.clamp(0.45, 2.2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) async {
          await _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: clampedRatio,
              child: CachedNetworkImage(
                imageUrl: widget.gif.previewUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  child: Icon(
                    CupertinoIcons.photo,
                    color: Colors.grey.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
