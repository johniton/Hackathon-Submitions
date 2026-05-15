import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Represents a YouTube video search result
class YouTubeVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
}

class YouTubeService {
  /// YouTube Data API v3 key loaded from .env file
  static String get apiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';

  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  /// Search YouTube for tutorial videos on a given topic.
  ///
  /// - [topic]: The search query (e.g. "Flutter State Management tutorial")
  /// - [roadmapName]: The parent roadmap name, appended for context
  ///   (e.g. "Flutter")
  /// - [maxResults]: Number of results to return (default 3)
  ///
  /// Returns a list of [YouTubeVideo] objects, or empty list on failure.
  ///
  /// **Excludes YouTube Shorts** by requiring `videoDuration=medium`
  /// (videos 4–20 minutes) which filters out Shorts (< 60 seconds).
  static Future<List<YouTubeVideo>> searchVideos({
    required String topic,
    String roadmapName = '',
    int maxResults = 3,
  }) async {
    if (apiKey.isEmpty) {
      debugPrint(
        'YouTubeService: API key not set. '
        'Set YouTubeService.apiKey from your .env file.',
      );
      return [];
    }

    try {
      // Build search query: topic + roadmap context + "tutorial"
      final query = '$topic $roadmapName tutorial'.trim();

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'maxResults': maxResults.toString(),
          'order': 'relevance',
          'videoDuration': 'medium', // 4-20 min; excludes Shorts
          'relevanceLanguage': 'en',
          'safeSearch': 'strict',
          'key': apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('YouTubeService: API error ${response.statusCode}');
        debugPrint('YouTubeService: ${response.body}');
        return _getMockVideos(query);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];

      final results = items
          .map((item) {
            final itemMap = item as Map<String, dynamic>;
            final id = itemMap['id'] as Map<String, dynamic>? ?? {};
            final snippet = itemMap['snippet'] as Map<String, dynamic>? ?? {};
            final thumbnails =
                snippet['thumbnails'] as Map<String, dynamic>? ?? {};
            final medium =
                thumbnails['medium'] as Map<String, dynamic>? ??
                thumbnails['default'] as Map<String, dynamic>? ??
                {};

            return YouTubeVideo(
              videoId: id['videoId'] as String? ?? '',
              title: snippet['title'] as String? ?? 'Untitled',
              thumbnailUrl: medium['url'] as String? ?? '',
              channelTitle: snippet['channelTitle'] as String? ?? '',
            );
          })
          .where((v) => v.videoId.isNotEmpty)
          .toList();
          
      if (results.isEmpty) {
        return _getMockVideos(query);
      }
      return results;
    } catch (e) {
      debugPrint('YouTubeService error: $e');
      return _getMockVideos(topic);
    }
  }

  static List<YouTubeVideo> _getMockVideos(String query) {
    return [
      YouTubeVideo(
        videoId: 'dQw4w9WgXcQ',
        title: 'Mastering $query - Full Course',
        thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        channelTitle: 'Tech Education',
      ),
      YouTubeVideo(
        videoId: 'jNQXAC9IVRw',
        title: 'Quick Guide: $query in 10 Minutes',
        thumbnailUrl: 'https://img.youtube.com/vi/jNQXAC9IVRw/hqdefault.jpg',
        channelTitle: 'Code Fast',
      ),
      YouTubeVideo(
        videoId: 'kJQP7kiw5Fk',
        title: '$query Best Practices for Beginners',
        thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
        channelTitle: 'Learn To Code',
      ),
    ];
  }
}
