import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class MediaChatBubble extends StatefulWidget {
  final String mediaURL;
  final String mediaType;
  final String? thumbnailURL;
  final String? message;
  final bool isSender;
  final DateTime timestamp;

  const MediaChatBubble({
    Key? key,
    required this.mediaURL,
    required this.mediaType,
    this.thumbnailURL,
    this.message,
    required this.isSender,
    required this.timestamp,
  }) : super(key: key);

  @override
  State<MediaChatBubble> createState() => _MediaChatBubbleState();
}

class _MediaChatBubbleState extends State<MediaChatBubble> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initVideoPlayer();
    }
  }

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaURL))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleVideoPlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _videoController?.play();
      } else {
        _videoController?.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isSender 
            ? Theme.of(context).colorScheme.primary 
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media content
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildMediaContent(),
          ),
          
          // Message text (if any)
          if (widget.message != null && widget.message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.message!,
                style: TextStyle(
                  color: widget.isSender ? Colors.white : Colors.black,
                ),
              ),
            ),
          
          // Timestamp
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                DateFormat('h:mm a').format(widget.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isSender ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (widget.mediaType) {
      case 'image':
        return GestureDetector(
          onTap: () => _showFullScreenImage(context),
          child: CachedNetworkImage(
            imageUrl: widget.mediaURL,
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Icon(Icons.error),
            ),
            fit: BoxFit.cover,
          ),
        );
        
      case 'video':
        if (_videoController != null && _videoController!.value.isInitialized) {
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              GestureDetector(
                onTap: _toggleVideoPlayback,
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Show thumbnail while video is loading
          return GestureDetector(
            onTap: _toggleVideoPlayback,
            child: Stack(
              alignment: Alignment.center,
              children: [
                widget.thumbnailURL != null
                    ? CachedNetworkImage(
                        imageUrl: widget.thumbnailURL!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                      ),
                const Icon(
                  Icons.play_arrow,
                  size: 50,
                  color: Colors.white,
                ),
              ],
            ),
          );
        }
        
      default:
        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[200],
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file),
              const SizedBox(width: 8),
              Expanded(
                child: Text('File attachment', 
                  style: TextStyle(
                    color: widget.isSender ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.mediaURL,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}