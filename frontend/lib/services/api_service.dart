import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:8000/api/v1';
  
  String? _accessToken;
  
  void setAccessToken(String token) {
    _accessToken = token;
  }
  
  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    return headers;
  }
  
  Future<Map<String, dynamic>> sendMessage(String message, String? conversationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/message'),
      headers: _headers(),
      body: jsonEncode({
        'message': message,
        'conversation_id': conversationId,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
  
  Future<List<dynamic>> getConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get conversations');
    }
  }
  
  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversation/$conversationId'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get conversation');
    }
  }
  
  // Project endpoints
  
  Future<Map<String, dynamic>?> getActiveProject() async {
    final response = await http.get(
      Uri.parse('$baseUrl/project/active'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      final body = response.body;
      if (body == 'null' || body.isEmpty) {
        return null;
      }
      return jsonDecode(body);
    } else {
      throw Exception('Failed to get active project');
    }
  }
  
  Future<List<dynamic>> getAllProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/project/all'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get projects');
    }
  }
  
  Future<Map<String, dynamic>> createProject(String targetUrl, String? name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/create'),
      headers: _headers(),
      body: jsonEncode({
        'target_url': targetUrl,
        'name': name,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create project: ${response.body}');
    }
  }
  
  Future<List<dynamic>> getProjectKeywords(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/project/$projectId/keywords'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get project keywords');
    }
  }
  
  Future<Map<String, dynamic>> addKeywordToProject(
    String projectId,
    String keyword,
    int? searchVolume,
    String? competition,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/$projectId/keywords'),
      headers: _headers(),
      body: jsonEncode({
        'keyword': keyword,
        'search_volume': searchVolume,
        'competition': competition,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add keyword: ${response.body}');
    }
  }
  
  Future<void> refreshRankings(String projectId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/$projectId/refresh'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to refresh rankings');
    }
  }
  
  Future<Map<String, dynamic>> getKeywordHistory(String keywordId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/project/keywords/$keywordId/history'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get keyword history');
    }
  }
  
  Future<void> deleteConversation(String conversationId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/conversation/$conversationId'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation');
    }
  }
}

