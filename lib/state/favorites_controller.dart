import 'package:flutter/foundation.dart';

import '../models/character_model.dart';
import '../services/session_service.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({required this._sessionService});

  final SessionService _sessionService;

  final List<CharacterModel> _favorites = [];
  String? _activeUsername;

  List<CharacterModel> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;

  bool isFavorite(int characterId) {
    return _favorites.any((c) => c.id == characterId);
  }

  Future<void> syncForUser(String? username) async {
    if (username == null || username.isEmpty) {
      _activeUsername = null;
      _favorites.clear();
      notifyListeners();
      return;
    }

    if (_activeUsername == username) return;

    _activeUsername = username;
    final loaded = await _sessionService.loadFavorites(username);
    _favorites
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Toggles favorite status and returns `true` if added, `false` if removed.
  Future<bool> toggleFavorite(CharacterModel character) async {
    final existingIndex = _favorites.indexWhere((c) => c.id == character.id);
    late final bool added;
    if (existingIndex >= 0) {
      _favorites.removeAt(existingIndex);
      added = false;
    } else {
      _favorites.insert(0, character);
      added = true;
    }
    notifyListeners();
    await _persist();
    return added;
  }

  Future<void> removeFavorite(int characterId) async {
    final beforeLength = _favorites.length;
    _favorites.removeWhere((c) => c.id == characterId);
    if (_favorites.length != beforeLength) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() async {
    final user = _activeUsername;
    if (user == null || user.isEmpty) return;
    await _sessionService.saveFavorites(user, _favorites);
  }
}
