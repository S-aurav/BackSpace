import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../api/apis.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../models/story.dart';
import '../widgets/adaptive_blur.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<UserStoriesGroup> userStoriesGroups;
  final int initialGroupIndex;

  const StoryViewerScreen({
    super.key,
    required this.userStoriesGroups,
    this.initialGroupIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  late AnimationController _animController;
  VideoPlayerController? _videoController;

  bool _isPaused = false;
  bool _isHolding = false;
  bool _isMediaLoaded = false;
  DateTime? _tapDownTime;

  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ValueNotifier<bool> _hasReplyTextNotifier = ValueNotifier<bool>(false);
  bool _isSendingReply = false;

  UserStoriesGroup get _currentGroup => widget.userStoriesGroups[_currentGroupIndex];
  Story get _currentStory => _currentGroup.stories[_currentStoryIndex];

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _replyFocusNode.addListener(_onReplyFocusChange);
    _replyController.addListener(() {
      final hasText = _replyController.text.trim().isNotEmpty;
      if (_hasReplyTextNotifier.value != hasText) {
        _hasReplyTextNotifier.value = hasText;
      }
    });

    _startStory();
  }

  void _onReplyFocusChange() {
    if (_replyFocusNode.hasFocus) {
      setState(() => _isPaused = true);
      _animController.stop();
      _videoController?.pause();
    } else {
      if (_isMediaLoaded && !_isHolding && !_isSendingReply) {
        setState(() => _isPaused = false);
        _videoController?.play();
        _animController.forward();
      }
    }
  }

  @override
  void dispose() {
    _replyFocusNode.removeListener(_onReplyFocusChange);
    _hasReplyTextNotifier.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    _disposeVideo();
    _animController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
  }

  void _startStory() {
    _disposeVideo();
    _animController.stop();
    _animController.reset();

    // Mark as viewed
    APIs.markStoryViewed(_currentStory.userId, _currentStory.id);

    if (_currentStory.isText) {
      _animController.duration = const Duration(seconds: 5);
      _isMediaLoaded = true;
      if (!_isHolding && !_isPaused) {
        _animController.forward();
      }
    } else if (_currentStory.isVideo) {
      _isMediaLoaded = false;
      _initVideoPlayer(_currentStory.mediaUrl);
    } else {
      // Photo story: default 5 seconds duration, wait for image to load
      _animController.duration = const Duration(seconds: 5);
      _isMediaLoaded = false;
    }
  }

  Future<void> _initVideoPlayer(String url) async {
    try {
      // Check if video file is already saved in local disk cache
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      File videoFile;
      if (fileInfo != null) {
        log('Playing video story from local disk cache: ${fileInfo.file.path}');
        videoFile = fileInfo.file;
      } else {
        log('Fetching and caching video story locally...');
        videoFile = await DefaultCacheManager().getSingleFile(url);
      }

      if (!mounted) return;
      _videoController = VideoPlayerController.file(videoFile)
        ..initialize().then((_) {
          if (!mounted) return;
          final videoDuration = _videoController!.value.duration;
          _animController.duration = videoDuration.inSeconds > 0
              ? videoDuration
              : const Duration(seconds: 15);

          _isMediaLoaded = true;
          if (!_isHolding && !_isPaused) {
            _videoController!.play();
            _animController.forward();
          }
          setState(() {});
        }).catchError((e) {
          log('Video file init error, trying fallback: $e');
          _fallbackNetworkVideo(url);
        });
    } catch (e) {
      log('Video cache exception, using network fallback: $e');
      _fallbackNetworkVideo(url);
    }
  }

  void _fallbackNetworkVideo(String url) {
    if (!mounted) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        final videoDuration = _videoController!.value.duration;
        _animController.duration = videoDuration.inSeconds > 0
            ? videoDuration
            : const Duration(seconds: 15);

        _isMediaLoaded = true;
        if (!_isHolding && !_isPaused) {
          _videoController!.play();
          _animController.forward();
        }
        setState(() {});
      }).catchError((_) {
        if (mounted) {
          _onMediaFullyLoaded();
        }
      });
  }

  void _onMediaFullyLoaded() {
    if (!_isMediaLoaded && mounted) {
      setState(() => _isMediaLoaded = true);
      if (!_isHolding && !_isPaused && !_animController.isAnimating) {
        _animController.forward();
      }
    }
  }

  void _nextStory() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startStory();
    } else if (_currentGroupIndex < widget.userStoriesGroups.length - 1) {
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _startStory();
    } else if (_currentGroupIndex > 0) {
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = widget.userStoriesGroups[_currentGroupIndex].stories.length - 1;
      });
      _startStory();
    } else {
      _startStory();
    }
  }

  // Tap & Hold Gestures (WhatsApp / Instagram style)
  void _handleTapDown(TapDownDetails details) {
    _tapDownTime = DateTime.now();
    _animController.stop();
    _videoController?.pause();
  }

  void _handleTapUp(TapUpDetails details) {
    final tapDuration = _tapDownTime != null
        ? DateTime.now().difference(_tapDownTime!)
        : Duration.zero;

    if (_isHolding) {
      setState(() => _isHolding = false);
      if (_isMediaLoaded && !_isPaused) {
        _videoController?.play();
        _animController.forward();
      }
      return;
    }

    // Quick tap (< 250ms): navigate between stories
    if (tapDuration.inMilliseconds < 250) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (details.globalPosition.dx < screenWidth * 0.3) {
        _previousStory();
      } else {
        _nextStory();
      }
    } else {
      if (_isMediaLoaded && !_isPaused) {
        _videoController?.play();
        _animController.forward();
      }
    }
  }

  void _handleTapCancel() {
    if (_isHolding) {
      setState(() => _isHolding = false);
    }
    if (_isMediaLoaded && !_isPaused) {
      _videoController?.play();
      _animController.forward();
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    setState(() => _isHolding = true);
    _animController.stop();
    _videoController?.pause();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() => _isHolding = false);
    if (_isMediaLoaded && !_isPaused) {
      _videoController?.play();
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMyStory = _currentStory.userId == APIs.user.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onLongPressStart: _handleLongPressStart,
        onLongPressEnd: _handleLongPressEnd,
        child: Stack(
          children: [
            // Story Media View (Text, Image, or Native Video)
            Positioned.fill(
              child: _currentStory.isText
                  ? _buildTextStoryContent(_currentStory)
                  : (_currentStory.isVideo
                      ? _buildVideoStoryContent(_currentStory)
                      : _buildImageStoryContent(_currentStory)),
            ),

            // Top Gradient Shadow & Controls (Auto-hides on Hold for clean viewing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _isHolding ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Bars
                      Row(
                        children: List.generate(
                          _currentGroup.stories.length,
                          (index) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _buildProgressBar(index),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white24,
                            backgroundImage: _currentGroup.userImage.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    APIs.getOptimizedImageUrl(_currentGroup.userImage, width: 120),
                                  )
                                : null,
                            child: _currentGroup.userImage.isEmpty
                                ? const Icon(CupertinoIcons.person_fill, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentGroup.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getTimeAgo(_currentStory.createdAt),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (isMyStory)
                            IconButton(
                              icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                              onPressed: _showDeleteDialog,
                            ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Caption Overlay (Clean Transparent with shadow, safe above navigation bar)
            if (_currentStory.caption.isNotEmpty)
              Positioned(
                bottom: isMyStory
                    ? MediaQuery.of(context).padding.bottom + 65.0
                    : MediaQuery.of(context).padding.bottom + 75.0,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _isHolding ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.transparent,
                    child: Text(
                      _currentStory.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 10,
                            offset: Offset(0, 1),
                          ),
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Viewers Sheet (For My Stories, Auto-hides on Hold, safe above navigation bar)
            if (isMyStory)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16.0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _isHolding ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Center(
                    child: GestureDetector(
                      onTap: _showViewersSheet,
                      child: AdaptiveBlur(
                        borderRadius: BorderRadius.circular(20),
                        sigma: 15,
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.eye_fill, color: Colors.white, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  '${_currentStory.views.length} Views',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Reply Bar (For Other Users' Stories)
            if (!isMyStory)
              _buildStoryReplyBar(),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReply(String text) async {
    final trimText = text.trim();
    if (trimText.isEmpty || _isSendingReply) return;

    setState(() => _isSendingReply = true);
    _replyFocusNode.unfocus();
    _replyController.clear();

    final success = await APIs.sendStoryReply(
      storyOwnerId: _currentStory.userId,
      replyText: trimText,
      storyCaption: _currentStory.caption,
      storyMediaUrl: _currentStory.mediaUrl,
      isVideo: _currentStory.isVideo,
      isText: _currentStory.isText,
      storyOwnerName: _currentGroup.userName,
    );

    if (mounted) {
      setState(() => _isSendingReply = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Reply sent to story!'),
              ],
            ),
            backgroundColor: Color(0xFF007AFF),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (_isMediaLoaded) {
        setState(() => _isPaused = false);
        _videoController?.play();
        _animController.forward();
      }
    }
  }

  Widget _buildStoryReplyBar() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 8.0,
      left: 12,
      right: 12,
      child: AnimatedOpacity(
        opacity: _isHolding ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Emoji Reaction Row with Haptic Feedback
            if (!_replyFocusNode.hasFocus)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '😂', '😮', '😢', '🙏', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _sendReply(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Compact Transparent Capsule Input (Chat Screen Style)
            Row(
              children: [
                Expanded(
                  child: AdaptiveBlur(
                    borderRadius: BorderRadius.circular(18),
                    sigma: 16,
                    child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.5),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _replyFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            cursorColor: const Color(0xFF007AFF),
                            textInputAction: TextInputAction.send,
                            onSubmitted: _sendReply,
                            decoration: InputDecoration(
                              hintText: 'Reply to ${_currentGroup.userName.isNotEmpty ? _currentGroup.userName : "Status"}...',
                              hintStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    if (_replyController.text.trim().isNotEmpty) {
                      HapticFeedback.lightImpact();
                      _sendReply(_replyController.text);
                    }
                  },
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hasReplyTextNotifier,
                    builder: (context, hasText, _) {
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasText
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF007AFF).withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up,
                          color: Colors.white,
                          size: 17,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(int index) {
    if (index < _currentStoryIndex) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (index == _currentStoryIndex) {
      return AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _animController.value,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 3,
            ),
          );
        },
      );
    } else {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white30,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
  }

  Widget _buildTextStoryContent(Story story) {
    final colors = _getGradientColors(story.bgColor);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            story.mediaUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.3,
              shadows: [
                Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageStoryContent(Story story) {
    final optimizedUrl = APIs.getOptimizedImageUrl(story.mediaUrl, width: 1080);

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: BoxFit.contain,
      imageBuilder: (context, imageProvider) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onMediaFullyLoaded();
        });
        return Image(image: imageProvider, fit: BoxFit.contain);
      },
      placeholder: (context, url) => const Center(
        child: CupertinoActivityIndicator(color: Color(0xFF007AFF), radius: 18),
      ),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onMediaFullyLoaded();
        });
        return const Center(
          child: Icon(CupertinoIcons.photo, color: Colors.white54, size: 64),
        );
      },
    );
  }

  Widget _buildVideoStoryContent(Story story) {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    return const Center(
      child: CupertinoActivityIndicator(color: Color(0xFF007AFF), radius: 20),
    );
  }

  List<Color> _getGradientColors(String key) {
    if (key.isEmpty) return [const Color(0xFF007AFF), const Color(0xFF00C6FF)];
    final hexCodes = key.split('_');
    return hexCodes.map((h) => Color(int.parse(h))).toList();
  }

  String _getTimeAgo(String timestamp) {
    final sent = DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    final diff = DateTime.now().difference(sent);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  void _showDeleteDialog() {
    _animController.stop();
    _videoController?.pause();
    setState(() => _isPaused = true);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Status'),
        content: const Text('Are you sure you want to delete this status update?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isPaused = false);
              if (_isMediaLoaded) {
                _videoController?.play();
                _animController.forward();
              }
            },
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await APIs.deleteStory(_currentStory.id, _currentStory.mediaUrl, _currentStory.isText);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showViewersSheet() {
    _animController.stop();
    _videoController?.pause();
    setState(() => _isPaused = true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AdaptiveBlur(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        sigma: 30,
        child: Container(
            color: ThemeController.cardColor.withValues(alpha: 0.95),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            padding: EdgeInsets.only(
              top: 10,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS Grabber Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: ThemeController.dividerColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet Header
                Row(
                  children: [
                    const Icon(CupertinoIcons.eye_fill, color: Color(0xFF007AFF), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Viewed by (${_currentStory.views.length})',
                      style: TextStyle(
                        color: ThemeController.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ThemeController.dividerColor.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          color: ThemeController.subtextColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: ThemeController.dividerColor, height: 1, thickness: 0.5),

                // Viewers List
                Flexible(
                  child: _currentStory.views.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Text(
                              'No views yet',
                              style: TextStyle(color: ThemeController.subtextColor, fontSize: 15),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: _currentStory.views.length,
                          separatorBuilder: (_, __) => Divider(
                            color: ThemeController.dividerColor.withValues(alpha: 0.4),
                            height: 1,
                            indent: 56,
                          ),
                          itemBuilder: (ctx, index) {
                            return _ViewerTile(viewerId: _currentStory.views[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
    ).then((_) {
      setState(() => _isPaused = false);
      if (_isMediaLoaded) {
        _videoController?.play();
        _animController.forward();
      }
    });
  }
}

class _ViewerTile extends StatelessWidget {
  final String viewerId;

  const _ViewerTile({required this.viewerId});

  @override
  Widget build(BuildContext context) {
    final isMe = viewerId == APIs.user.uid;

    if (isMe) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
          backgroundImage: APIs.me.image.isNotEmpty
              ? CachedNetworkImageProvider(
                  APIs.getOptimizedImageUrl(APIs.me.image, width: 80),
                )
              : null,
          child: APIs.me.image.isEmpty
              ? const Icon(CupertinoIcons.person_fill, color: Color(0xFF007AFF), size: 20)
              : null,
        ),
        title: Text(
          'You (Author)',
          style: TextStyle(
            color: ThemeController.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          APIs.me.email.isNotEmpty ? APIs.me.email : (APIs.me.about.isNotEmpty ? APIs.me.about : 'Story owner'),
          style: TextStyle(
            color: ThemeController.subtextColor,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return FutureBuilder<ChatUser?>(
      future: APIs.getUserById(viewerId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user != null && user.name.trim().isNotEmpty
            ? user.name
            : 'Contact';
        final image = user?.image ?? '';
        final subtitle = user != null && user.about.isNotEmpty
            ? user.about
            : (user != null && user.email.isNotEmpty ? user.email : 'Viewed');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
            backgroundImage: image.isNotEmpty
                ? CachedNetworkImageProvider(
                    APIs.getOptimizedImageUrl(image, width: 80),
                  )
                : null,
            child: image.isEmpty
                ? const Icon(CupertinoIcons.person_fill, color: Color(0xFF007AFF), size: 20)
                : null,
          ),
          title: Text(
            name,
            style: TextStyle(
              color: ThemeController.textColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: ThemeController.subtextColor,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
