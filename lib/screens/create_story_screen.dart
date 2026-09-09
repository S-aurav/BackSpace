import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../widgets/adaptive_blur.dart';

/// Clean, beautiful, modern iOS-style Status/Story Creator.
/// Supports rich gradient Text Statuses, Photos, and Videos (up to 100MB native quality).
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  bool _isTextStory = true;
  File? _mediaFile;
  XFile? _mediaXFile;
  Uint8List? _mediaBytes;
  bool _isVideo = false;
  VideoPlayerController? _videoPlayerController;

  final _textController = TextEditingController();
  final _captionController = TextEditingController();
  bool _isUploading = false;

  // Curated modern iOS-style gradient palettes
  final List<String> _bgGradients = [
    '0xFF007AFF_0xFF00C6FF', // iOS Electric Blue
    '0xFF8A2387_0xFFE94057_0xFFF27121', // Sunset Coral
    '0xFF5B247A_0xFF1BCEDF', // Cosmic Cyan
    '0xFF11998E_0xFF38EF7D', // Mint Emerald
    '0xFFFC466B_0xFF3F5EFB', // Neon Rose
    '0xFF1A1A24_0xFF2A2D3E', // Midnight Pitch Dark
    '0xFFF7971E_0xFFFFD200', // Solar Amber
  ];
  int _selectedGradientIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    _captionController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _disposeVideoPlayer() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: _isTextStory ? Colors.black : ThemeController.bgColor,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,

          // Frosted Glass Top Bar
          appBar: AppBar(
            toolbarHeight: 60,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AdaptiveBlur(
              sigmaX: 25,
              sigmaY: 25,
              child: Container(
                color: Colors.black.withValues(alpha: kIsWeb ? 0.85 : 0.35),
              ),
            ),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            title: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _isTextStory,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: const Color(0xFF007AFF),
              children: {
                true: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.textformat,
                        size: 16,
                        color: _isTextStory ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Text',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isTextStory ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                false: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.photo_fill,
                        size: 16,
                        color: !_isTextStory ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Media',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: !_isTextStory ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              },
              onValueChanged: (val) {
                if (val != null) {
                  setState(() => _isTextStory = val);
                }
              },
            ),
            centerTitle: true,
            actions: [
              // Share Button
              if (!_isUploading)
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _postStory,
                    child: const Text(
                      'Share',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),

          body: Stack(
            children: [
              // Main Story Content Canvas
              Positioned.fill(
                child: _isTextStory ? _buildTextStoryView(mq) : _buildMediaStoryView(mq),
              ),

              // Uploading overlay indicator
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(color: Color(0xFF007AFF), radius: 18),
                          SizedBox(height: 16),
                          Text(
                            'Sharing to Status...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom Interactive Controls Toolbar
              if (!_isUploading)
                Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      (MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : MediaQuery.of(context).padding.bottom + 16),
                  left: 16,
                  right: 16,
                  child: AdaptiveBlur(
                    borderRadius: BorderRadius.circular(24),
                    sigmaX: 20,
                    sigmaY: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: kIsWeb ? 0.9 : 0.45),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: _isTextStory ? _buildGradientChips() : _buildMediaControls(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Text Status Canvas
  Widget _buildTextStoryView(Size mq) {
    final colors = _getGradientColors(_bgGradients[_selectedGradientIndex]);
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
          padding: EdgeInsets.symmetric(horizontal: mq.width * 0.08),
          child: TextField(
            controller: _textController,
            maxLines: null,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.3,
              shadows: [
                Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            decoration: InputDecoration(
              hintText: 'What\'s on your mind?',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  // Photo / Video Status Canvas
  Widget _buildMediaStoryView(Size mq) {
    if (_mediaBytes != null || _mediaFile != null || _mediaXFile != null) {
      if (_isVideo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
        );
      } else if (!_isVideo) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: _mediaBytes != null
              ? Image.memory(_mediaBytes!, fit: BoxFit.contain)
              : (_mediaFile != null
                  ? Image.file(_mediaFile!, fit: BoxFit.contain)
                  : const SizedBox.shrink()),
        );
      }
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Icon(
                CupertinoIcons.photo_on_rectangle,
                size: 42,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No photo or video selected',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose photo or video (up to 100MB, full HD)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(CupertinoIcons.photo, size: 16),
                  label: const Text('Photo'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _pickVideo(ImageSource.gallery),
                  icon: const Icon(CupertinoIcons.film, size: 16),
                  label: const Text('Video'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(CupertinoIcons.camera, size: 16),
                  label: const Text('Snap'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _pickVideo(ImageSource.camera),
                  icon: const Icon(CupertinoIcons.videocam_fill, size: 16),
                  label: const Text('Record'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Gradient Selector Chips for Text Status
  Widget _buildGradientChips() {
    return Row(
      children: [
        const Icon(CupertinoIcons.color_filter, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_bgGradients.length, (index) {
                final colors = _getGradientColors(_bgGradients[index]);
                final isSelected = index == _selectedGradientIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGradientIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: colors.first.withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // Bottom Input Controls for Media Status (Caption, Pickers)
  Widget _buildMediaControls() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(CupertinoIcons.photo_on_rectangle, color: Color(0xFF007AFF), size: 22),
          onPressed: () => _pickImage(ImageSource.gallery),
          tooltip: 'Photo Library',
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.film, color: Color(0xFF007AFF), size: 22),
          onPressed: () => _pickVideo(ImageSource.gallery),
          tooltip: 'Video Library',
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.camera_fill, color: Color(0xFF007AFF), size: 22),
          onPressed: () => _pickImage(ImageSource.camera),
          tooltip: 'Take Photo',
        ),
        IconButton(
          icon: const Icon(CupertinoIcons.videocam_fill, color: Color(0xFF007AFF), size: 22),
          onPressed: () => _pickVideo(ImageSource.camera),
          tooltip: 'Record Video',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Caption...',
                hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(String key) {
    final hexCodes = key.split('_');
    return hexCodes.map((h) => Color(int.parse(h))).toList();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      _disposeVideoPlayer();
      final bytes = await image.readAsBytes();
      setState(() {
        _mediaXFile = image;
        _mediaBytes = bytes;
        if (!kIsWeb) _mediaFile = File(image.path);
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: source);
    if (video != null) {
      final sizeInBytes = await video.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      log('Picked video for story size: ${sizeInMB.toStringAsFixed(2)}MB');

      // 100MB limit for stories
      if (sizeInMB > 100) {
        if (mounted) {
          Dialogs.showSnackbar(
            context,
            'Video size exceeds 100MB limit (${sizeInMB.toStringAsFixed(1)}MB)',
          );
        }
        return;
      }

      _disposeVideoPlayer();
      if (kIsWeb) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(video.path));
      } else {
        _videoPlayerController = VideoPlayerController.file(File(video.path));
      }
      _videoPlayerController!
        .initialize().then((_) {
          _videoPlayerController!.setLooping(true);
          _videoPlayerController!.play();
          if (mounted) setState(() {});
        });

      setState(() {
        _mediaXFile = video;
        if (!kIsWeb) _mediaFile = File(video.path);
        _isVideo = true;
      });
    }
  }

  Future<void> _postStory() async {
    if (_isTextStory) {
      if (_textController.text.trim().isEmpty) {
        Dialogs.showSnackbar(context, 'Please enter some text for your status');
        return;
      }
      setState(() => _isUploading = true);
      final success = await APIs.postTextStory(
        _textController.text.trim(),
        _bgGradients[_selectedGradientIndex],
      );
      setState(() => _isUploading = false);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          Dialogs.showSnackbar(context, 'Failed to post status');
        }
      }
    } else {
      final mediaToUpload = _mediaXFile ?? _mediaFile;
      if (mediaToUpload == null) {
        Dialogs.showSnackbar(context, 'Please select a photo or video first');
        return;
      }
      setState(() => _isUploading = true);
      final success = await APIs.uploadStoryMedia(
        mediaToUpload,
        _captionController.text.trim(),
        isVideo: _isVideo,
      );
      setState(() => _isUploading = false);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          Dialogs.showSnackbar(context, 'Failed to upload status');
        }
      }
    }
  }
}
