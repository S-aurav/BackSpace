import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../helper/dialogs.dart';

/// Full-screen interactive video player with WhatsApp / iOS Video styling.
/// Features:
/// - Play / Pause, seeking scrubber, time elapsed / total
/// - Mute / Unmute audio
/// - Auto-hiding overlay controls
/// - Save / Download video to device gallery via Gal
/// - Swipe-down to dismiss
class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String heroTag;
  final String title;
  final String subtitle;

  const FullScreenVideoViewer({
    super.key,
    required this.videoUrl,
    this.heroTag = '',
    this.title = '',
    this.subtitle = '',
  });

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isSaving = false;
  bool _isMuted = false;
  Timer? _hideControlsTimer;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
          _startHideControlsTimer();
        }
      }).catchError((error) {
        log('Error initializing video player: $error');
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideControlsTimer?.cancel();
      } else {
        _controller.play();
        _startHideControlsTimer();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _saveVideo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = widget.videoUrl.split('.').last.split('?').first;
      final tempFilePath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final response = await http.get(Uri.parse(widget.videoUrl));
      final file = File(tempFilePath);
      await file.writeAsBytes(response.bodyBytes);

      await Gal.putVideo(tempFilePath);

      if (mounted) {
        Dialogs.showSnackbar(context, 'Video saved to gallery');
      }
    } catch (e) {
      log('Error saving video: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'Failed to save video');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - (_dragOffsetY.abs() / 300.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5 * bgOpacity),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title.isNotEmpty)
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : IconButton(
                  icon: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 22),
                  tooltip: 'Save to Gallery',
                  onPressed: _saveVideo,
                ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffsetY += details.delta.dy;
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY.abs() > 100) {
            Navigator.pop(context);
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragOffsetY),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Center Video Player
              Center(
                child: _isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CupertinoActivityIndicator(color: Colors.white, radius: 18),
              ),

              // Center Play/Pause Overlay Icon on pause
              if (_isInitialized && !_controller.value.isPlaying)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),

              // Bottom Control Bar
              if (_isInitialized && _showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress Slider
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF007AFF),
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),

                        // Time & Control buttons row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Play/Pause button
                            IconButton(
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? CupertinoIcons.pause_fill
                                    : CupertinoIcons.play_fill,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: _togglePlayPause,
                            ),

                            // Current time / Total duration
                            Text(
                              '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            // Mute/Unmute button
                            IconButton(
                              icon: Icon(
                                _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: _toggleMute,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
