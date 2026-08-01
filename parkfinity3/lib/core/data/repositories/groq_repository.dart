import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../features/owner/data/models/listing_model.dart';

final groqRepositoryProvider = Provider<GroqRepository>((ref) {
  return GroqRepository();
});

class GroqRepository {
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  String get _apiKey {
    return dotenv.env['GROQ_API_KEY'] ?? '';
  }

  Future<String> getSmartRecommendations(List<ListingModel> listings, String userPreference) async {
    if (_apiKey.isEmpty) return 'Please set GROQ_API_KEY in .env';

    final listingsData = listings.map((l) => 
      'ID: ${l.id}, Title: ${l.title}, Hourly: ৳${l.hourlyRate}, Covered: ${l.isCovered}, Security: ${l.hasSecurity}'
    ).join('\n');

    final prompt = '''
You are ParkFinity AI, a smart parking assistant.
Given the following available parking spots:
$listingsData

The user is looking for: "$userPreference"

Based on the user's preference, recommend the single best parking spot from the list above. 
Explain why you chose it in 1-2 short sentences. Do not mention the ID.
''';

    return _callGroq(prompt);
  }

  Future<String> summarizeReviews(List<dynamic> reviews) async {
    if (_apiKey.isEmpty) return 'Please set GROQ_API_KEY in .env';
    if (reviews.isEmpty) return 'No reviews to summarize.';

    final reviewsData = reviews.map((r) => 'Rating: ${r.rating}/5, Comment: ${r.comment}').join('\n');

    final prompt = '''
You are an AI assistant summarizing parking spot reviews.
Here are the recent reviews:
$reviewsData

Provide a 1-2 sentence summary of what people think about this parking spot. Highlight the main positives and any recurring negatives.
''';

    return _callGroq(prompt);
  }

  Future<String> _callGroq(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful and concise assistant.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        return 'AI Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Failed to reach AI: $e';
    }
  }
}
