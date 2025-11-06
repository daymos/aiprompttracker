import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Project {
  final String id;
  final String targetUrl;
  final String name;
  final DateTime createdAt;
  final String? gscPropertyUrl; // Google Search Console property URL

  Project({
    required this.id,
    required this.targetUrl,
    required this.name,
    required this.createdAt,
    this.gscPropertyUrl,
  });

  bool get isGSCLinked => gscPropertyUrl != null && gscPropertyUrl!.isNotEmpty;
}

class TrackedKeyword {
  final String id;
  final String keyword;
  final int? searchVolume;
  final String? competition;
  final int? currentPosition;
  final int targetPosition;
  final String source; // "manual" or "auto_detected"
  final bool isActive; // true if actively tracked, false if just a suggestion
  final DateTime createdAt;

  TrackedKeyword({
    required this.id,
    required this.keyword,
    this.searchVolume,
    this.competition,
    this.currentPosition,
    required this.targetPosition,
    this.source = 'manual', // Default for backward compatibility
    this.isActive = true, // Default for backward compatibility
    required this.createdAt,
  });
  
  bool get isActivated => isActive;
  bool get isSuggestion => !isActive && source == 'auto_detected';
}

class ProjectProvider with ChangeNotifier {
  Project? _activeProject;
  Project? _selectedProject; // Currently viewing project
  List<Project> _allProjects = [];
  List<TrackedKeyword> _trackedKeywords = [];
  Map<String, dynamic>? _backlinksData; // Backlinks data for selected project
  bool _isLoading = false;

  Project? get activeProject => _activeProject;
  Project? get selectedProject => _selectedProject;
  List<Project> get allProjects => _allProjects;
  List<TrackedKeyword> get trackedKeywords => _trackedKeywords;
  Map<String, dynamic>? get backlinksData => _backlinksData;
  bool get isLoading => _isLoading;

  Future<void> loadActiveProject(ApiService apiService) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.getActiveProject();
      
      if (response != null) {
        _activeProject = Project(
          id: response['id'],
          targetUrl: response['target_url'],
          name: response['name'] ?? 'My Project',
          createdAt: DateTime.parse(response['created_at']),
          gscPropertyUrl: response['gsc_property_url'],
        );

        // Set as selected if no project is selected
        if (_selectedProject == null) {
          _selectedProject = _activeProject;
          await loadTrackedKeywords(apiService, _activeProject!.id);
        }
      } else {
        _activeProject = null;
        _trackedKeywords = [];
      }
    } catch (e) {
      _activeProject = null;
      _trackedKeywords = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> selectProject(ApiService apiService, Project project) async {
    _selectedProject = project;
    _backlinksData = null; // Clear previous backlinks data
    await loadTrackedKeywords(apiService, project.id);
    // Load backlinks data in background
    loadBacklinksData(apiService, project.id).catchError((e) {
      // Silently handle errors for background loading
      print('Error loading backlinks data: $e');
    });
  }
  
  Future<void> loadAllProjects(ApiService apiService) async {
    try {
      final projects = await apiService.getAllProjects();
      
      _allProjects = projects.map((s) => Project(
        id: s['id'],
        targetUrl: s['target_url'],
        name: s['name'] ?? 'My Project',
        createdAt: DateTime.parse(s['created_at']),
        gscPropertyUrl: s['gsc_property_url'],
      )).toList();
      
      notifyListeners();
    } catch (e) {
      _allProjects = [];
    }
  }

  Future<void> createProject(ApiService apiService, String targetUrl, String? name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.createProject(targetUrl, name);
      
      final newProject = Project(
        id: response['id'],
        targetUrl: response['target_url'],
        name: response['name'] ?? 'My Project',
        createdAt: DateTime.parse(response['created_at']),
        gscPropertyUrl: response['gsc_property_url'],
      );
      
      _activeProject = newProject;
      _selectedProject = newProject; // Auto-select the new project
      await loadAllProjects(apiService); // Refresh all projects list
      
      // Load any auto-detected keywords that were created
      await loadTrackedKeywords(apiService, newProject.id);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrackedKeywords(ApiService apiService, String projectId) async {
    try {
      final keywords = await apiService.getProjectKeywords(projectId);
      
      _trackedKeywords = keywords.map((k) => TrackedKeyword(
        id: k['id'],
        keyword: k['keyword'],
        searchVolume: k['search_volume'],
        competition: k['competition'],
        currentPosition: k['current_position'],
        targetPosition: k['target_position'],
        source: k['source'] ?? 'manual', // Default to manual if not present
        isActive: k['is_active'] ?? true, // Default to true if not present
        createdAt: DateTime.parse(k['created_at']),
      )).toList();
      
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> addKeyword(ApiService apiService, String keyword, int? searchVolume, String? competition, {String? projectId}) async {
    final targetProjectId = projectId ?? _selectedProject?.id;
    if (targetProjectId == null) return;

    try {
      final response = await apiService.addKeywordToProject(
        targetProjectId,
        keyword,
        searchVolume,
        competition,
      );

      final newKeyword = TrackedKeyword(
        id: response['id'],
        keyword: response['keyword'],
        searchVolume: response['search_volume'],
        competition: response['competition'],
        currentPosition: response['current_position'],
        targetPosition: response['target_position'],
        source: response['source'] ?? 'manual', // Default to manual if not present
        isActive: response['is_active'] ?? true, // Default to true if not present
        createdAt: DateTime.parse(response['created_at']),
      );

      // Only add to tracked keywords if it's the currently selected project
      if (targetProjectId == _selectedProject?.id) {
        _trackedKeywords.add(newKeyword);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteKeyword(ApiService apiService, String keywordId) async {
    try {
      await apiService.deleteKeyword(keywordId);
      
      // Remove from local list
      _trackedKeywords.removeWhere((k) => k.id == keywordId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteMultipleKeywords(ApiService apiService, List<String> keywordIds) async {
    if (keywordIds.isEmpty) return;
    
    try {
      // Delete keywords one by one to handle partial failures better
      final errors = <String>[];
      for (final id in keywordIds) {
        try {
          await apiService.deleteKeyword(id);
        } catch (e) {
          errors.add(id);
        }
      }
      
      // Remove successfully deleted keywords from local list
      final successfullyDeleted = keywordIds.where((id) => !errors.contains(id)).toList();
      if (successfullyDeleted.isNotEmpty) {
        _trackedKeywords.removeWhere((k) => successfullyDeleted.contains(k.id));
        notifyListeners();
      }
      
      // If there were errors, throw with details
      if (errors.isNotEmpty) {
        throw Exception('Failed to delete ${errors.length} keyword(s)');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshRankings(ApiService apiService) async {
    if (_selectedProject == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await apiService.refreshRankings(_selectedProject!.id);
      await loadTrackedKeywords(apiService, _selectedProject!.id); // Reload to get updated rankings
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedProject() {
    _selectedProject = null;
    _backlinksData = null; // Clear backlinks data too
    notifyListeners();
  }

  Future<void> loadBacklinksData(ApiService apiService, String projectId, {bool refresh = false}) async {
    try {
      _backlinksData = await apiService.analyzeProjectBacklinks(projectId, refresh: refresh);
      notifyListeners();
    } catch (e) {
      _backlinksData = null;
      rethrow;
    }
  }

  Future<void> refreshBacklinks(ApiService apiService, String projectId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch fresh data from RapidAPI (not cached)
      await loadBacklinksData(apiService, projectId, refresh: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

