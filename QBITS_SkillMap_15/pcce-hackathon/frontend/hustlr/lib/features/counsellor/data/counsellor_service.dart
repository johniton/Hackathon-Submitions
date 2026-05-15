import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CounsellorService {
  static String get _groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static Future<String> sendMessage(List<Map<String, String>> messages) async {
    if (_groqApiKey.isEmpty) {
      throw Exception('GROQ API key is missing.');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final apiKey = _groqApiKey;
    
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': messages,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to send message: ${response.statusCode} ${response.body}');
    }
  }
}
