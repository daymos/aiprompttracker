import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Point to backend API server (separate from Flutter dev server)
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
  
  Stream<Map<String, dynamic>> sendMessageStream(
    String message, 
    String? conversationId, {
    String? projectId,
    String? agentMode,
  }) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/message/stream'));
    request.headers.addAll(_headers());
    
    final body = {
      'message': message,
      'conversation_id': conversationId,
    };
    
    if (projectId != null) {
      body['project_id'] = projectId;
    }
    if (agentMode != null) {
      body['agent_mode'] = agentMode;
    }
    
    request.body = jsonEncode(body);
    
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
  
  Future<Map<String, dynamic>> toggleKeywordActive(String keywordId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/project/keywords/$keywordId/toggle'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to toggle keyword: ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> addKeywordToProject(
    String projectId,
    String keyword,
    int? searchVolume,
    String? competition,
    int? seoDifficulty,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/$projectId/keywords'),
      headers: _headers(),
      body: jsonEncode({
        'keyword': keyword,
        'search_volume': searchVolume,
        'competition': competition,
        'seo_difficulty': seoDifficulty,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add keyword: ${response.body}');
    }
  }
  
  Future<void> deleteKeyword(String keywordId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/project/keywords/$keywordId'),
      headers: _headers(),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to delete keyword: ${response.body}');
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

  Future<void> renameConversation(String conversationId, String newTitle) async {
    final response = await http.put(
      Uri.parse('$baseUrl/chat/conversation/$conversationId/rename'),
      headers: _headers(),
      body: jsonEncode({'title': newTitle}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to rename conversation');
    }
  }

  Future<Map<String, dynamic>> deleteAllConversations() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/conversations/all'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete all conversations');
    }
  }
  
  Future<Map<String, dynamic>> analyzeProjectBacklinks(String projectId, {bool refresh = false}) async {
    final uri = Uri.parse('$baseUrl/backlinks/project/$projectId/analyze').replace(
      queryParameters: {'refresh': refresh.toString()},
    );
    
    final response = await http.get(
      uri,
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to analyze backlinks: ${response.body}');
    }
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

  Future<Map<String, dynamic>> pinItem({
    String? projectId,
    required String contentType,
    required String title,
    required String content,
    String? sourceMessageId,
    String? sourceConversationId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/pin'),
      headers: _headers(),
      body: jsonEncode({
        'project_id': projectId,
        'content_type': contentType,
        'title': title,
        'content': content,
        'source_message_id': sourceMessageId,
        'source_conversation_id': sourceConversationId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to pin item');
    }

    return json.decode(response.body);
  }

  Future<List<Map<String, dynamic>>> getPinnedItems({String? projectId}) async {
    final uri = projectId != null
        ? Uri.parse('$baseUrl/project/pins?project_id=$projectId')
        : Uri.parse('$baseUrl/project/pins');

    final response = await http.get(
      uri,
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get pinned items');
    }

    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  Future<void> unpinItem(String pinId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/project/pins/$pinId'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unpin item');
    }
  }

  Future<Map<String, dynamic>> pinConversation({
    required String conversationId,
    String? projectId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/project/pin-conversation'),
      headers: _headers(),
      body: jsonEncode({
        'conversation_id': conversationId,
        'project_id': projectId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to pin conversation');
    }

    return json.decode(response.body);
  }

  String getFaviconUrl(String url) {
    // The backend now proxies the favicon, so we just return the endpoint URL
    return '$baseUrl/project/favicon?url=${Uri.encodeComponent(url)}';
  }

  // Google Search Console endpoints

  Future<List<Map<String, dynamic>>> getGSCProperties() async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/properties'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['properties']);
    } else {
      throw Exception('Failed to get GSC properties: ${response.body}');
    }
  }

  Future<void> linkProjectToGSCProperty(String projectId, String propertyUrl) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gsc/project/link'),
      headers: _headers(),
      body: jsonEncode({
        'project_id': projectId,
        'property_url': propertyUrl,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to link GSC property: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGSCAnalytics(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/project/$projectId/analytics'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get GSC analytics: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getGSCTopQueries(String projectId, {int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/project/$projectId/queries?limit=$limit'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['queries']);
    } else {
      throw Exception('Failed to get top queries: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getGSCTopPages(String projectId, {int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/project/$projectId/pages?limit=$limit'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['pages']);
    } else {
      throw Exception('Failed to get top pages: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getGSCSitemaps(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/project/$projectId/sitemaps'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['sitemaps']);
    } else {
      throw Exception('Failed to get sitemaps: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getGSCIndexing(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/gsc/project/$projectId/indexing'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get indexing status: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to GET $path: ${response.body}');
    }
  }
}


