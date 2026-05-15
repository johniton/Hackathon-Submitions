import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hustlr/config.dart';

class CounsellorService {
  static Future<String> sendMessage(List<Map<String, String>> messages) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/ai-tools/chat');
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'];
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
}
