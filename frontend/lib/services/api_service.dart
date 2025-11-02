import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use relative URL since backend serves frontend
  static const String baseUrl = '/api/v1';
  
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
  
  Future<Map<String, dynamic>> sendMessage(String message, String? conversationId, {String mode = 'ask'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/message'),
      headers: _headers(),
      body: jsonEncode({
        'message': message,
        'conversation_id': conversationId,
        'mode': mode,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
  
  Stream<Map<String, dynamic>> sendMessageStream(
    String message, 
    String? conversationId, 
    {String mode = 'ask'}
  ) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/message/stream'));
    request.headers.addAll(_headers());
    request.body = jsonEncode({
      'message': message,
      'conversation_id': conversationId,
      'mode': mode,
    });
    
    final streamedResponse = await request.send();
    
    if (streamedResponse.statusCode != 200) {
      throw Exception('Failed to send message: ${streamedResponse.statusCode}');
    }
    
    // Buffer for incomplete lines
    String buffer = '';
    
    await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;
      
      // Process complete lines
      while (buffer.contains('\n\n')) {
        final endIndex = buffer.indexOf('\n\n');
        final line = buffer.substring(0, endIndex);
        buffer = buffer.substring(endIndex + 2);
        
        if (line.isEmpty) continue;
        
        // Parse SSE format: "event: <type>\ndata: <json>"
        final lines = line.split('\n');
        String? eventType;
        String? data;
        
        for (final l in lines) {
          if (l.startsWith('event: ')) {
            eventType = l.substring(7).trim();
          } else if (l.startsWith('data: ')) {
            data = l.substring(6).trim();
          }
        }
        
        if (eventType != null && data != null) {
          try {
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            yield {
              'event': eventType,
              'data': jsonData,
            };
          } catch (e) {
            print('Error parsing SSE data: $e');
          }
        }
      }
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
  
  Future<Map<String, dynamic>> getProjectBacklinks(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/backlinks/project/$projectId/submissions'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch backlinks');
    }
    
    return json.decode(response.body);
  }

  Future<void> deleteProject(String projectId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/project/$projectId'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete project');
    }
  }

  Future<void> updateBacklinkSubmission(String submissionId, String status, {String? notes}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/backlinks/submission/$submissionId'),
      headers: _headers(),
      body: jsonEncode({
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update submission');
    }
  }

  Future<Map<String, dynamic>> verifyBacklinkSubmission(String submissionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/backlinks/submission/$submissionId/verify'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to verify submission');
    }
    
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> verifyAllBacklinks(String projectId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/backlinks/project/$projectId/verify-all'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to verify backlinks');
    }
    
    return json.decode(response.body);
  }
}

