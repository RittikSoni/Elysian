import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for streaming local video files over HTTP
class VideoStreamingService {
  static final VideoStreamingService _instance =
      VideoStreamingService._internal();
  factory VideoStreamingService() => _instance;
  VideoStreamingService._internal();

  HttpServer? _videoServer;
  int? _videoServerPort;
  String? _currentVideoPath;
  String? _hostIp;

  /// Check if a URL is a local file path
  static bool isLocalFile(String url) {
    return url.startsWith('/') &&
        !url.startsWith('http') &&
        !url.startsWith('file://');
  }

  /// Start streaming a local video file
  /// Returns the network URL that can be used to access the video
  Future<String?> startStreaming({
    required String videoPath,
    required String hostIp,
    int? preferredPort,
  }) async {
    try {
      // If already streaming the same video, return existing URL
      if (_videoServer != null &&
          _currentVideoPath == videoPath &&
          _videoServerPort != null) {
        return 'http://$hostIp:$_videoServerPort/video';
      }

      // Stop existing server if any
      await stopStreaming();

      _currentVideoPath = videoPath;
      _hostIp = hostIp;

      // Check if file exists
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('Video file does not exist: $videoPath');
        return null;
      }

      // Start HTTP server
      final port = preferredPort ?? 0; // 0 means auto-assign
      _videoServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _videoServerPort = _videoServer!.port;

      debugPrint('Video streaming server started on port $_videoServerPort');

      // Handle requests
      _videoServer!.listen((HttpRequest request) async {
        await _handleVideoRequest(request, file);
      });

      return 'http://$hostIp:$_videoServerPort/video';
    } catch (e) {
      debugPrint('Error starting video streaming server: $e');
      _currentVideoPath = null;
      _videoServerPort = null;
      return null;
    }
  }

  /// Handle video streaming requests
  Future<void> _handleVideoRequest(HttpRequest request, File videoFile) async {
    try {
      final path = request.uri.path;

      if (path == '/video' || path == '/video/') {
        // Serve the video file with proper headers for streaming
        final fileLength = await videoFile.length();
        final rangeHeader = request.headers.value('range');

        if (rangeHeader != null) {
          // Handle range requests for video seeking
          final rangeMatch = RegExp(
            r'bytes=(\d+)-(\d*)',
          ).firstMatch(rangeHeader);
          if (rangeMatch != null) {
            final start = int.parse(rangeMatch.group(1)!);
            final end = rangeMatch.group(2)!.isEmpty
                ? fileLength - 1
                : int.parse(rangeMatch.group(2)!);

            final contentLength = end - start + 1;
            final fileStream = videoFile.openRead(start, end + 1);

            request.response
              ..statusCode = HttpStatus.partialContent
              ..headers.add('Content-Type', _getContentType(videoFile.path))
              ..headers.add('Content-Length', contentLength.toString())
              ..headers.add('Content-Range', 'bytes $start-$end/$fileLength')
              ..headers.add('Accept-Ranges', 'bytes')
              ..headers.add('Cache-Control', 'no-cache')
              ..addStream(fileStream)
              ..close();
            return;
          }
        }

        // Serve full file
        final fileStream = videoFile.openRead();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.add('Content-Type', _getContentType(videoFile.path))
          ..headers.add('Content-Length', fileLength.toString())
          ..headers.add('Accept-Ranges', 'bytes')
          ..headers.add('Cache-Control', 'no-cache')
          ..addStream(fileStream)
          ..close();
      } else {
        // 404 for other paths
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    } catch (e) {
      debugPrint('Error handling video request: $e');
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..close();
    }
  }

  /// Get content type based on file extension
  String _getContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'ogg':
      case 'ogv':
        return 'video/ogg';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'm4v':
        return 'video/mp4';
      case '3gp':
        return 'video/3gpp';
      default:
        return 'video/mp4'; // Default to mp4
    }
  }

  /// Stop streaming and close the server
  Future<void> stopStreaming() async {
    try {
      await _videoServer?.close(force: true);
      _videoServer = null;
      _videoServerPort = null;
      _currentVideoPath = null;
      debugPrint('Video streaming server stopped');
    } catch (e) {
      debugPrint('Error stopping video streaming server: $e');
    }
  }

  /// Get the current streaming URL if active
  String? get streamingUrl {
    if (_videoServer != null && _videoServerPort != null && _hostIp != null) {
      return 'http://$_hostIp:$_videoServerPort/video';
    }
    return null;
  }

  /// Check if currently streaming
  bool get isStreaming => _videoServer != null;
}
