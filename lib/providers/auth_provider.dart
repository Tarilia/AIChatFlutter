import 'package:flutter/material.dart';
import '../api/openrouter_client.dart';
import '../services/database_service.dart';

class AuthProvider with ChangeNotifier {
  final OpenRouterClient _apiClient = OpenRouterClient();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider();

  Future<bool> validateKey(String apiKey) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _apiClient.setApiKey(apiKey);
      final balance = await _apiClient.getBalance();

      if (balance == 'Error') {
        throw Exception('Неверный API ключ');
      }

      final pin = _generatePin();
      await _dbService.saveAuthData(apiKey, pin);

      _isLoading = false;
      _errorMessage = 'Ваш PIN код: $pin';
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> validatePin(String pin) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final savedPin = await _dbService.getPin();
      if (savedPin == pin) {
        final apiKey = await _dbService.getApiKey();
        _apiClient.setApiKey(apiKey!);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Неверный PIN код');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void resetAuth() async {
    await _dbService.clearAuthData();
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  String _generatePin() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 9000 + 1000).toString();
  }

  Future<bool> checkAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();

      final apiKey = await _dbService.getApiKey();
      final pin = await _dbService.getPin();

      if (apiKey != null && pin != null) {
        _apiClient.setApiKey(apiKey);
        _isAuthenticated = true;
        return true;
      }
      _isAuthenticated = false;
      return false;
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      _isAuthenticated = false;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
