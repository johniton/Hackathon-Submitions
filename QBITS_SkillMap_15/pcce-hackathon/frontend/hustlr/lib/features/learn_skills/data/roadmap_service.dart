import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a single topic or subtopic in a roadmap
class RoadmapTopic {
  final String id;
  final String label;
  final String type; // 'topic' or 'subtopic'
  final List<RoadmapTopic> subtopics;
  bool isCompleted;

  RoadmapTopic({
    required this.id,
    required this.label,
    required this.type,
    this.subtopics = const [],
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type,
        'isCompleted': isCompleted,
        'subtopics': subtopics.map((s) => s.toJson()).toList(),
      };

  factory RoadmapTopic.fromJson(Map<String, dynamic> json) => RoadmapTopic(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        type: json['type'] ?? 'topic',
        isCompleted: json['isCompleted'] ?? false,
        subtopics: (json['subtopics'] as List?)
                ?.map((s) => RoadmapTopic.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Represents a user-added roadmap with optional goal context
class UserRoadmap {
  final String name;
  final String slug;
  List<RoadmapTopic>? topics;
  bool isLoaded;

  // Goal context (personalised roadmap)
  String? targetRole;
  String? targetCompany;
  String? targetSkill;
  List<String> skillGaps;

  UserRoadmap({
    required this.name,
    required this.slug,
    this.topics,
    this.isLoaded = false,
    this.targetRole,
    this.targetCompany,
    this.targetSkill,
    this.skillGaps = const [],
  });

  /// Get the current (first unlocked incomplete) topic index
  int get currentTopicIndex {
    if (topics == null) return 0;
    for (int i = 0; i < topics!.length; i++) {
      final topic = topics![i];
      if (topic.subtopics.isEmpty) {
        if (!topic.isCompleted) return i;
      } else {
        if (!topic.subtopics.every((s) => s.isCompleted)) return i;
      }
    }
    return topics!.length; // all complete
  }

  /// Get the label of the current topic being studied
  String? get currentTopicLabel {
    if (topics == null || currentTopicIndex >= topics!.length) return null;
    return topics![currentTopicIndex].label;
  }
}

class RoadmapService {
  static const String _baseUrl = 'https://roadmap.sh';

  /// Common name-to-slug mappings to help users find roadmaps.
  /// This is NOT a display list — it's only used for slug resolution
  /// when a user types a skill name.
  static const Map<String, String> _slugMappings = {
    'frontend': 'frontend',
    'backend': 'backend',
    'full stack': 'full-stack',
    'fullstack': 'full-stack',
    'devops': 'devops',
    'devsecops': 'devsecops',
    'android': 'android',
    'ios': 'ios',
    'data analyst': 'data-analyst',
    'ai engineer': 'ai-engineer',
    'ai': 'ai-engineer',
    'data scientist': 'ai-data-scientist',
    'data engineer': 'data-engineer',
    'machine learning': 'machine-learning',
    'ml': 'machine-learning',
    'cyber security': 'cyber-security',
    'cybersecurity': 'cyber-security',
    'blockchain': 'blockchain',
    'qa': 'qa',
    'software architect': 'software-architect',
    'ux design': 'ux-design',
    'ux': 'ux-design',
    'game developer': 'game-developer',
    'game dev': 'game-developer',
    'product manager': 'product-manager',
    'mlops': 'mlops',
    'engineering manager': 'engineering-manager',
    'technical writer': 'technical-writer',
    'devrel': 'devrel',
    'developer relations': 'devrel',
    'react': 'react',
    'vue': 'vue',
    'angular': 'angular',
    'javascript': 'javascript',
    'js': 'javascript',
    'typescript': 'typescript',
    'ts': 'typescript',
    'node': 'nodejs',
    'nodejs': 'nodejs',
    'node.js': 'nodejs',
    'python': 'python',
    'java': 'java',
    'flutter': 'flutter',
    'react native': 'react-native',
    'go': 'golang',
    'golang': 'golang',
    'rust': 'rust',
    'c++': 'cpp',
    'cpp': 'cpp',
    'sql': 'sql',
    'docker': 'docker',
    'kubernetes': 'kubernetes',
    'k8s': 'kubernetes',
    'aws': 'aws',
    'mongodb': 'mongodb',
    'mongo': 'mongodb',
    'postgresql': 'postgresql-dba',
    'postgres': 'postgresql-dba',
    'graphql': 'graphql',
    'git': 'git-github',
    'github': 'git-github',
    'git & github': 'git-github',
    'linux': 'linux',
    'system design': 'system-design',
    'dsa': 'datastructures-and-algorithms',
    'data structures': 'datastructures-and-algorithms',
    'algorithms': 'datastructures-and-algorithms',
    'spring boot': 'spring-boot',
    'spring': 'spring-boot',
    'asp.net': 'aspnet-core',
    'aspnet': 'aspnet-core',
    '.net': 'aspnet-core',
    'prompt engineering': 'prompt-engineering',
    'kotlin': 'kotlin',
    'php': 'php',
    'terraform': 'terraform',
    'redis': 'redis',
    'next.js': 'nextjs',
    'nextjs': 'nextjs',
    'api design': 'api-design',
    'design system': 'design-system',
    'computer science': 'computer-science',
    'cs': 'computer-science',
    'html': 'html',
    'css': 'css',
    'swift': 'swift-ui',
    'swiftui': 'swift-ui',
    'laravel': 'laravel',
    'django': 'django',
    'ruby': 'ruby',
    'ruby on rails': 'ruby-on-rails',
    'rails': 'ruby-on-rails',
    'scala': 'scala',
    'cloudflare': 'cloudflare',
    'elasticsearch': 'elasticsearch',
    'wordpress': 'wordpress',
    'bash': 'shell-bash',
    'shell': 'shell-bash',
    'code review': 'code-review',
    'network engineer': 'network-engineer',
    'bi analyst': 'bi-analyst',
  };

  /// Resolve a user-typed skill name into a roadmap.sh slug.
  /// Returns the slug if found, otherwise tries the input as-is.
  static String resolveSlug(String input) {
    final normalized = input.trim().toLowerCase();
    // Direct mapping match
    if (_slugMappings.containsKey(normalized)) {
      return _slugMappings[normalized]!;
    }
    // Try as-is (lowercase, replace spaces with hyphens)
    return normalized.replaceAll(' ', '-');
  }

  /// Get a display-friendly name from a slug
  static String displayName(String slug) {
    // Try reverse lookup in mappings
    for (final entry in _slugMappings.entries) {
      if (entry.value == slug) {
        // Return the first "nice" key (capitalize properly)
        final words = entry.key.split(' ');
        return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
      }
    }
    // Fallback: convert slug to title case
    return slug
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Fetch and parse roadmap data from roadmap.sh.
  /// Returns null if the roadmap doesn't exist.
  static Future<List<RoadmapTopic>?> fetchRoadmap(String slug) async {
    try {
      final url = Uri.parse('$_baseUrl/$slug.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null; // Roadmap not found
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseRoadmapNodes(data);
    } catch (e) {
      debugPrint('Error fetching roadmap: $e');
      return null;
    }
  }

  /// Parse the nodes from roadmap JSON into structured topics
  static List<RoadmapTopic> _parseRoadmapNodes(Map<String, dynamic> data) {
    final nodes = data['nodes'] as List<dynamic>? ?? [];

    // Separate topics and subtopics
    final topics = <RoadmapTopic>[];
    final subtopicNodes = <Map<String, dynamic>>[];

    for (final node in nodes) {
      final nodeMap = node as Map<String, dynamic>;
      final type = nodeMap['type'] as String? ?? '';
      final nodeData = nodeMap['data'] as Map<String, dynamic>? ?? {};
      final label = nodeData['label'] as String? ?? '';

      if (label.isEmpty) continue;

      if (type == 'topic') {
        topics.add(RoadmapTopic(
          id: nodeMap['id'] as String? ?? '',
          label: label,
          type: 'topic',
          subtopics: [],
        ));
      } else if (type == 'subtopic') {
        subtopicNodes.add(nodeMap);
      }
    }

    // Sort topics by their vertical position (y coordinate)
    topics.sort((a, b) {
      final aNode = nodes.firstWhere(
        (n) => (n as Map<String, dynamic>)['id'] == a.id,
        orElse: () => <String, dynamic>{},
      ) as Map<String, dynamic>;
      final bNode = nodes.firstWhere(
        (n) => (n as Map<String, dynamic>)['id'] == b.id,
        orElse: () => <String, dynamic>{},
      ) as Map<String, dynamic>;

      final aPos = aNode['position'] as Map<String, dynamic>? ?? {};
      final bPos = bNode['position'] as Map<String, dynamic>? ?? {};
      final aY = (aPos['y'] as num?)?.toDouble() ?? 0;
      final bY = (bPos['y'] as num?)?.toDouble() ?? 0;
      return aY.compareTo(bY);
    });

    // Associate subtopics with their nearest topic by y-position
    for (final subtopicNode in subtopicNodes) {
      final subData = subtopicNode['data'] as Map<String, dynamic>? ?? {};
      final subLabel = subData['label'] as String? ?? '';
      if (subLabel.isEmpty) continue;

      final subPos = subtopicNode['position'] as Map<String, dynamic>? ?? {};
      final subY = (subPos['y'] as num?)?.toDouble() ?? 0;

      RoadmapTopic? bestTopic;
      double bestDist = double.infinity;

      for (final topic in topics) {
        final topicNode = nodes.firstWhere(
          (n) => (n as Map<String, dynamic>)['id'] == topic.id,
          orElse: () => <String, dynamic>{},
        ) as Map<String, dynamic>;
        final topicPos = topicNode['position'] as Map<String, dynamic>? ?? {};
        final topicY = (topicPos['y'] as num?)?.toDouble() ?? 0;

        final dist = (subY - topicY).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestTopic = topic;
        }
      }

      if (bestTopic != null) {
        bestTopic.subtopics.add(RoadmapTopic(
          id: subtopicNode['id'] as String? ?? '',
          label: subLabel,
          type: 'subtopic',
        ));
      }
    }

    return topics;
  }
}
