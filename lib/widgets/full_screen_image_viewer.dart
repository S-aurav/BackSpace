import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';

import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';

/// Full-screen zoomable media/image viewer with WhatsApp & iOS Photos styling.
/// Features:
/// - Pinch-to-zoom (up to 5x)
/// - Double-tap to zoom/unzoom
/// - Swipe down to dismiss
/// - Optional Save/Download to gallery
/// - Immersive edge-to-edge dark theme
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String title;
  final String subtitle;
  final BaseCacheManager? cacheManager;
  final bool showDownload;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag = '',
    this.title = '',
    this.subtitle = '',
    this.cacheManager,
    this.showDownload = true,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _animController;
  Animation<Matrix4>? _animation;

  TapDownDetails? _doubleTapDetails;
  bool _isSaving = false;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;

    if (_transformController.value != Matrix4.identity()) {
      _animation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
    } else {
      final zoomed = Matrix4.identity()
        ..translate(position.dx, position.dy)
        ..scale(2.5)
        ..translate(-position.dx, -position.dy);

      _animation = Matrix4Tween(
        begin: _transformController.value,
        end: zoomed,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
    }
  }

  Future<void> _saveImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final cacheMgr = widget.cacheManager ?? ChatImageCacheManager.instance;
      final fileInfo = await cacheMgr.getFileFromCache(widget.imageUrl);

      if (fileInfo != null) {
        await Gal.putImage(fileInfo.file.path);
      } else {
        await Gal.putImage(widget.imageUrl);
      }

      if (mounted) {
        Dialogs.showSnackbar(context, 'Image saved to gallery');
      }
    } catch (e) {
      log('Error saving image: $e');
      if (mounted) {
        Dialogs.showSnackbar(context, 'Failed to save image');
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
          if (widget.showDownload)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoActivityIndicator(color: Colors.white),
                  )
                : IconButton(
                    icon: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 22),
                    tooltip: 'Save to Gallery',
                    onPressed: _saveImage,
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        onVerticalDragUpdate: (details) {
          if (_transformController.value == Matrix4.identity()) {
            setState(() {
              _dragOffsetY += details.delta.dy;
            });
          }
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
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Hero(
                tag: widget.heroTag.isNotEmpty ? widget.heroTag : widget.imageUrl,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  cacheManager: widget.cacheManager ?? ChatImageCacheManager.instance,
                  fadeInDuration: Duration.zero,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CupertinoActivityIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    CupertinoIcons.photo,
                    size: 80,
                    color: Colors.white38,
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
