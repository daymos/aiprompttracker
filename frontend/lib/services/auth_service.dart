import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Use relative URL since backend serves frontend
  static const String baseUrl = '/api/v1';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '149794489949-n76062u9scrnki2sbp22aaivat2eccri.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/webmasters.readonly',  // GSC access
    ],
  );
  
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null; // User canceled sign-in
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Send both tokens to backend (web uses access token, native uses id token)
      final Map<String, dynamic> authData = {
        'id_token': googleAuth.idToken ?? googleAuth.accessToken ?? '',
        'access_token': googleAuth.accessToken,
        'gsc_access_token': googleAuth.accessToken,  // Same token for GSC
      };
      
      // Only add gsc_refresh_token if available (not available in web flow)
      if (googleAuth.serverAuthCode != null) {
        authData['gsc_refresh_token'] = googleAuth.serverAuthCode;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(authData),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('user_id', data['user_id']);
        await prefs.setString('email', data['email']);
        await prefs.setString('name', data['name']);
        
        return data;
      } else {
        throw Exception('Failed to authenticate: ${response.body}');
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  Future<Map<String, String>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token == null) return null;
    
    return {
      'access_token': token,
      'user_id': prefs.getString('user_id') ?? '',
      'email': prefs.getString('email') ?? '',
      'name': prefs.getString('name') ?? '',
    };
  }
}

