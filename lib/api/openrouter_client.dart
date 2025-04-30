import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenRouterClient {
  String? _apiKey;
  String? get apiKey => _apiKey;

  String? _baseUrl;
  String? get baseUrl => _baseUrl;

  final Map<String, String> headers = {
    'Content-Type': 'application/json',
    'X-Title': 'AI Chat Flutter',
  };

  static final OpenRouterClient _instance = OpenRouterClient._internal();
  factory OpenRouterClient() => _instance;

  OpenRouterClient._internal() {
    _baseUrl = 'https://openrouter.ai/api/v1';
  }

  void setApiKey(String key) {
    _apiKey = key;
    headers['Authorization'] = 'Bearer $key';

    if (key.startsWith('sk-or-vv-')) {
      _baseUrl = 'https://api.vsegpt.ru/v1';
    } else if (key.startsWith('sk-or-v1-')) {
      _baseUrl = 'https://openrouter.ai/api/v1';
    }
  }

  Future<String> getBalance() async {
    try {
      final endpoint =
          _baseUrl?.contains('vsegpt.ru') == true ? 'balance' : 'credits';

      final response = await http.get(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          if (_baseUrl?.contains('vsegpt.ru') == true) {
            // Для VSEGPT преобразуем credits в число
            final credits =
                double.tryParse(data['data']['credits']?.toString() ?? '0.0');
            return '${credits?.toStringAsFixed(2) ?? '0.00'}₽';
          } else {
            // Для OpenRouter
            final credits = data['data']['total_credits'] ?? 0;
            final usage = data['data']['total_usage'] ?? 0;
            return '\$${(credits - usage).toStringAsFixed(2)}';
          }
        }
      }
      return _baseUrl?.contains('vsegpt.ru') == true ? '0.00₽' : '\$0.00';
    } catch (e) {
      debugPrint('Error getting balance: $e');
      return 'Error';
    }
  }

  // Остальные методы остаются без изменений
  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final modelsData = json.decode(response.body);
        if (modelsData['data'] != null) {
          return (modelsData['data'] as List).map((model) {
            return {
              'id': model['id'] as String,
              'name': model['name'] as String,
              'pricing': {
                'prompt': model['pricing']['prompt'] as String,
                'completion': model['pricing']['completion'] as String,
              },
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting models: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    try {
      final data = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': message}
        ],
        'max_tokens': 1000,
        'temperature': 0.7,
        'stream': false,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return {'error': 'API request failed'};
    } catch (e) {
      debugPrint('Error sending message: $e');
      return {'error': e.toString()};
    }
  }

  String formatPricing(double pricing) {
    if (_baseUrl?.contains('vsegpt.ru') == true) {
      return '${pricing.toStringAsFixed(3)}₽/K';
    }
    return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
  }
}
