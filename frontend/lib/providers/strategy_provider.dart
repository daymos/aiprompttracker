import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Strategy {
  final String id;
  final String targetUrl;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  Strategy({
    required this.id,
    required this.targetUrl,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });
}

class TrackedKeyword {
  final String id;
  final String keyword;
  final int? searchVolume;
  final String? competition;
  final int? currentPosition;
  final int targetPosition;
  final DateTime createdAt;

  TrackedKeyword({
    required this.id,
    required this.keyword,
    this.searchVolume,
    this.competition,
    this.currentPosition,
    required this.targetPosition,
    required this.createdAt,
  });
}

class StrategyProvider with ChangeNotifier {
  Strategy? _activeStrategy;
  Strategy? _selectedStrategy; // Currently viewing strategy
  List<Strategy> _allStrategies = [];
  List<TrackedKeyword> _trackedKeywords = [];
  bool _isLoading = false;

  Strategy? get activeStrategy => _activeStrategy;
  Strategy? get selectedStrategy => _selectedStrategy;
  List<Strategy> get allStrategies => _allStrategies;
  List<TrackedKeyword> get trackedKeywords => _trackedKeywords;
  bool get isLoading => _isLoading;

  Future<void> loadActiveStrategy(ApiService apiService) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.getActiveStrategy();
      
      if (response != null) {
        _activeStrategy = Strategy(
          id: response['id'],
          targetUrl: response['target_url'],
          name: response['name'] ?? 'My Strategy',
          isActive: response['is_active'],
          createdAt: DateTime.parse(response['created_at']),
        );

        // Set as selected if no strategy is selected
        if (_selectedStrategy == null) {
          _selectedStrategy = _activeStrategy;
          await loadTrackedKeywords(apiService, _activeStrategy!.id);
        }
      } else {
        _activeStrategy = null;
        _trackedKeywords = [];
      }
    } catch (e) {
      _activeStrategy = null;
      _trackedKeywords = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> selectStrategy(ApiService apiService, Strategy strategy) async {
    _selectedStrategy = strategy;
    await loadTrackedKeywords(apiService, strategy.id);
  }
  
  Future<void> loadAllStrategies(ApiService apiService) async {
    try {
      final strategies = await apiService.getAllStrategies();
      
      _allStrategies = strategies.map((s) => Strategy(
        id: s['id'],
        targetUrl: s['target_url'],
        name: s['name'] ?? 'My Strategy',
        isActive: s['is_active'],
        createdAt: DateTime.parse(s['created_at']),
      )).toList();
      
      notifyListeners();
    } catch (e) {
      _allStrategies = [];
    }
  }

  Future<void> createStrategy(ApiService apiService, String targetUrl, String? name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.createStrategy(targetUrl, name);
      
      final newStrategy = Strategy(
        id: response['id'],
        targetUrl: response['target_url'],
        name: response['name'] ?? 'My Strategy',
        isActive: response['is_active'],
        createdAt: DateTime.parse(response['created_at']),
      );
      
      _activeStrategy = newStrategy;
      _selectedStrategy = newStrategy; // Auto-select the new strategy
      _trackedKeywords = [];
      await loadAllStrategies(apiService); // Refresh all strategies list
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrackedKeywords(ApiService apiService, String strategyId) async {
    try {
      final keywords = await apiService.getStrategyKeywords(strategyId);
      
      _trackedKeywords = keywords.map((k) => TrackedKeyword(
        id: k['id'],
        keyword: k['keyword'],
        searchVolume: k['search_volume'],
        competition: k['competition'],
        currentPosition: k['current_position'],
        targetPosition: k['target_position'],
        createdAt: DateTime.parse(k['created_at']),
      )).toList();
      
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> addKeyword(ApiService apiService, String keyword, int? searchVolume, String? competition, {String? strategyId}) async {
    final targetStrategyId = strategyId ?? _selectedStrategy?.id;
    if (targetStrategyId == null) return;

    try {
      final response = await apiService.addKeywordToStrategy(
        targetStrategyId,
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
        createdAt: DateTime.parse(response['created_at']),
      );

      // Only add to tracked keywords if it's the currently selected strategy
      if (targetStrategyId == _selectedStrategy?.id) {
        _trackedKeywords.add(newKeyword);
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refreshRankings(ApiService apiService) async {
    if (_selectedStrategy == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await apiService.refreshRankings(_selectedStrategy!.id);
      await loadTrackedKeywords(apiService, _selectedStrategy!.id); // Reload to get updated rankings
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

