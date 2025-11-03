import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  bool _isAuthenticated = false;
  String? _userId;
  String? _email;
  String? _name;
  bool _isLoading = false;
  
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get email => _email;
  String? get name => _name;
  bool get isLoading => _isLoading;
  ApiService get apiService => _apiService;
  
  AuthProvider() {
    _checkSavedAuth();
  }
  
  Future<void> _checkSavedAuth() async {
    final savedUser = await _authService.getSavedUser();
    
    if (savedUser != null) {
      _isAuthenticated = true;
      _userId = savedUser['user_id'];
      _email = savedUser['email'];
      _name = savedUser['name'];
      _apiService.setAccessToken(savedUser['access_token']!);
      notifyListeners();
    }
  }
  
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await _authService.signInWithGoogle();
      
      if (result != null) {
        _isAuthenticated = true;
        _userId = result['user_id'];
        _email = result['email'];
        _name = result['name'];
        _apiService.setAccessToken(result['access_token']);
      }
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> signOut() async {
    await _authService.signOut();
    _isAuthenticated = false;
    _userId = null;
    _email = null;
    _name = null;
    notifyListeners();
  }
}





