import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/character_model.dart';
import '../models/episode_model.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RickMortyApiService {
  RickMortyApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String _host = 'rickandmortyapi.com';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;

  Future<PaginatedCharacters> fetchCharacters({
    String? status,
    String? name,
    int page = 1,
  }) async {
    final queryParams = <String, String>{};
    if (page > 1) {
      queryParams['page'] = '$page';
    }
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      queryParams['status'] = status.toLowerCase();
    }
    if (name != null && name.trim().isNotEmpty) {
      queryParams['name'] = name.trim();
    }

    final uri = Uri.https(
      _host,
      '/api/character',
      queryParams.isEmpty ? null : queryParams,
    );

    final response = await _get(uri, allowNotFoundEmpty: queryParams.containsKey('status') || queryParams.containsKey('name'));
    if (response == null) {
      return const PaginatedCharacters(
        characters: [],
        hasNextPage: false,
        totalCount: 0,
      );
    }

    final info = response['info'] as Map<String, dynamic>?;
    final results = response['results'] as List<dynamic>? ?? const [];

    final characters = results
        .whereType<Map>()
        .map((item) => CharacterModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return PaginatedCharacters(
      characters: characters,
      hasNextPage: info?['next'] != null,
      totalCount: (info?['count'] as num?)?.toInt() ?? characters.length,
    );
  }

  Future<CharacterModel> fetchCharacterDetail(int id) async {
    final uri = Uri.https(_host, '/api/character/$id');
    final data = await _get(uri);
    if (data == null) {
      throw const ApiException('Data karakter tidak ditemukan.');
    }
    return CharacterModel.fromJson(data);
  }

  Future<PaginatedEpisodes> fetchEpisodes({int page = 1}) async {
    final queryParams = page > 1 ? {'page': '$page'} : null;
    final uri = Uri.https(_host, '/api/episode', queryParams);
    final response = await _get(uri);
    if (response == null) {
      return const PaginatedEpisodes(
        episodes: [],
        hasNextPage: false,
        totalCount: 0,
      );
    }

    final info = response['info'] as Map<String, dynamic>?;
    final results = response['results'] as List<dynamic>? ?? const [];

    final episodes = results
        .whereType<Map>()
        .map((item) => EpisodeModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return PaginatedEpisodes(
      episodes: episodes,
      hasNextPage: info?['next'] != null,
      totalCount: (info?['count'] as num?)?.toInt() ?? episodes.length,
    );
  }

  Future<Map<String, dynamic>?> _get(
    Uri uri, {
    bool allowNotFoundEmpty = false,
  }) async {
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw const ApiException('Format respons server tidak sesuai.');
      }
      if (res.statusCode == 404 && allowNotFoundEmpty) {
        return null;
      }
      if (res.statusCode == 404) {
        throw const ApiException('Data tidak ditemukan.');
      }
      throw ApiException('Gagal memuat data (kode ${res.statusCode}).');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Koneksi habis waktu. Periksa jaringan Anda lalu coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (_) {
      throw const ApiException('Terjadi kesalahan saat mengambil data dari server.');
    }
  }
}
