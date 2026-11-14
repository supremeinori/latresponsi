import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:latres/main.dart';
import 'package:latres/models/user_model.dart';
import 'package:latres/services/local_db_service.dart';
import 'package:latres/services/rick_morty_api_service.dart';
import 'package:latres/services/session_service.dart';
import 'package:latres/state/auth_controller.dart';
import 'package:latres/state/favorites_controller.dart';

class InMemoryAuthDatabase implements AuthDatabase {
  final Map<String, Map<String, String>> _users = {};
  int _nextId = 1;

  @override
  Future<UserModel> registerUser({
    required String name,
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (_users.containsKey(normalized)) {
      throw const AuthException('Username sudah terdaftar.');
    }
    final id = _nextId++;
    _users[normalized] = {
      'id': '$id',
      'name': name.trim(),
      'username': normalized,
      'password': password,
    };
    return UserModel(id: id, name: name.trim(), username: normalized);
  }

  @override
  Future<UserModel?> authenticateUser({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();
    final record = _users[normalized];
    if (record == null || record['password'] != password) {
      return null;
    }
    return UserModel(
      id: int.parse(record['id']!),
      name: record['name']!,
      username: record['username']!,
    );
  }
}

Map<String, dynamic> _characterJson({
  required int id,
  required String name,
  required String status,
  String species = 'Human',
  String gender = 'Male',
  String origin = 'Earth (C-137)',
  String location = 'Citadel of Ricks',
}) {
  return {
    'id': id,
    'name': name,
    'status': status,
    'species': species,
    'gender': gender,
    'origin': {'name': origin},
    'location': {'name': location},
    'image': '',
  };
}

MockClient _createMockApiClient({
  List<String>? recordedUrls,
  bool failCharacters = false,
}) {
  final rick = _characterJson(
    id: 1,
    name: 'Rick Sanchez',
    status: 'Alive',
    species: 'Human',
    gender: 'Male',
    origin: 'Earth (C-137)',
    location: 'Citadel of Ricks',
  );
  final birdperson = _characterJson(
    id: 2,
    name: 'Birdperson',
    status: 'Dead',
    species: 'Alien',
    gender: 'Male',
    origin: 'Bird World',
    location: 'Planet Squanch',
  );
  final mystery = _characterJson(
    id: 3,
    name: 'Ghostly Entity',
    status: 'unknown',
    species: 'Mythological Creature',
    gender: 'unknown',
    origin: 'unknown',
    location: 'unknown',
  );

  final allChars = [rick, birdperson, mystery];

  return MockClient((request) async {
    recordedUrls?.add(request.url.toString());

    if (request.url.path == '/api/character') {
      if (failCharacters) {
        throw const SocketException('No internet');
      }
      final status = request.url.queryParameters['status'];
      final name = request.url.queryParameters['name']?.toLowerCase();
      var filtered = allChars.where((c) {
        final matchStatus = status == null ||
            (c['status'] as String).toLowerCase() == status.toLowerCase();
        final matchName = name == null ||
            (c['name'] as String).toLowerCase().contains(name);
        return matchStatus && matchName;
      }).toList();

      if (filtered.isEmpty) {
        return http.Response(jsonEncode({'error': 'There is nothing here'}), 404);
      }

      return http.Response(
        jsonEncode({
          'info': {'count': filtered.length, 'pages': 1, 'next': null},
          'results': filtered,
        }),
        200,
      );
    }

    if (request.url.path == '/api/character/1') {
      return http.Response(jsonEncode(rick), 200);
    }

    if (request.url.path == '/api/episode') {
      return http.Response(
        jsonEncode({
          'info': {'count': 2, 'pages': 1, 'next': null},
          'results': [
            {
              'id': 1,
              'name': 'Pilot',
              'air_date': 'December 2, 2013',
              'episode': 'S01E01',
            },
            {
              'id': 2,
              'name': 'Lawnmower Dog',
              'air_date': 'December 9, 2013',
              'episode': 'S01E02',
            },
          ],
        }),
        200,
      );
    }

    return http.Response('Not Found', 404);
  });
}

Future<({
  AuthController authController,
  FavoritesController favoritesController,
  RickMortyApiService apiService,
})> _createAppDeps({
  AuthDatabase? db,
  http.Client? httpClient,
}) async {
  final sessionService = SessionService();
  final authDatabase = db ?? InMemoryAuthDatabase();
  final apiService = RickMortyApiService(client: httpClient ?? _createMockApiClient());
  final authController = AuthController(
    database: authDatabase,
    sessionService: sessionService,
  );
  final favoritesController = FavoritesController(
    sessionService: sessionService,
  );
  await authController.restoreSession();
  await favoritesController.syncForUser(authController.currentUser?.username);

  return (
    authController: authController,
    favoritesController: favoritesController,
    apiService: apiService,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Auth flow: register, access home, logout, login again',
    (WidgetTester tester) async {
      final db = InMemoryAuthDatabase();
      final deps = await _createAppDeps(db: db);

      await tester.pumpWidget(
        RickMortyApp(
          authController: deps.authController,
          favoritesController: deps.favoritesController,
          apiService: deps.apiService,
        ),
      );
      await tester.pumpAndSettle();

      // Starts on Login Screen
      expect(find.text('Rick & Morty Explorer'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);

      // Navigate to Register Screen
      await tester.tap(find.text('Belum punya akun? Daftar'));
      await tester.pumpAndSettle();
      expect(find.text('Buat Akun Baru'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Lengkap'),
        'Morty Smith',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'morty',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Konfirmasi Password'),
        'secret123',
      );

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.pumpAndSettle();

      // Now inside MainShellScreen
      expect(find.text('Rick & Morty'), findsOneWidget);
      expect(find.text('Rick Sanchez'), findsOneWidget);

      // Logout via AppBar button -> dialog confirm -> back to LoginScreen
      await tester.tap(find.byTooltip('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Rick & Morty Explorer'), findsOneWidget);

      // Login again with wrong password -> error
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'morty',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpass',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Username atau password salah.'), findsOneWidget);

      // Login with valid password -> enters Home
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Rick Sanchez'), findsOneWidget);
    },
  );

  testWidgets(
    'Filter status, search by name, Detail Screen favorite & Favorite swipe sync',
    (WidgetTester tester) async {
      final db = InMemoryAuthDatabase();
      final user = await db.registerUser(
        name: 'Rick',
        username: 'rick',
        password: 'password123',
      );
      final session = SessionService();
      await session.saveSession(user);

      final recordedUrls = <String>[];
      final deps = await _createAppDeps(
        db: db,
        httpClient: _createMockApiClient(recordedUrls: recordedUrls),
      );

      await tester.pumpWidget(
        RickMortyApp(
          authController: deps.authController,
          favoritesController: deps.favoritesController,
          apiService: deps.apiService,
        ),
      );
      await tester.pumpAndSettle();

      // Characters loaded
      expect(find.text('Rick Sanchez'), findsOneWidget);
      expect(find.text('Birdperson'), findsOneWidget);

      // Filter by Dead -> calls ?status=dead
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dead'));
      await tester.pumpAndSettle();
      expect(
        recordedUrls.any((u) => u.contains('/api/character?status=dead')),
        isTrue,
      );
      expect(find.text('Birdperson'), findsOneWidget);
      expect(find.text('Rick Sanchez'), findsNothing);

      // Reset to All & Search Rick
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cari nama karakter...'),
        'Rick',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        recordedUrls.any((u) => u.contains('/api/character?name=Rick')),
        isTrue,
      );
      expect(find.text('Rick Sanchez'), findsOneWidget);

      // Open Detail Screen
      await tester.tap(find.text('Rick Sanchez'));
      await tester.pumpAndSettle();
      expect(find.text('Human'), findsOneWidget);
      expect(find.text('Earth (C-137)'), findsOneWidget);
      expect(find.text('Citadel of Ricks'), findsOneWidget);

      // Toggle Favorite from Detail Screen -> updates icon & shows Snackbar
      await tester.tap(find.byTooltip('Tambah ke favorit'));
      await tester.pumpAndSettle();
      expect(find.text('Rick Sanchez ditambahkan ke favorit'), findsOneWidget);
      expect(find.byTooltip('Hapus dari favorit'), findsWidgets);

      // Go back to Home Screen -> heart icon should immediately be filled
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsWidgets);

      // Switch to Favorites tab
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Rick Sanchez'), findsOneWidget);

      // Swipe to delete favorite -> shows Snackbar & shows empty state
      await tester.drag(
        find.byKey(const ValueKey('favorite_1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rick Sanchez dihapus dari favorit'), findsOneWidget);
      expect(find.text('Daftar Favorit Kosong'), findsOneWidget);

      // Switch back to Characters tab -> favorite icon reverted to outline
      await tester.tap(find.text('Characters'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tambah ke favorit'), findsOneWidget);

      // Switch to Episodes tab -> shows name & air_date
      await tester.tap(find.text('Episodes'));
      await tester.pumpAndSettle();
      expect(find.text('Pilot'), findsOneWidget);
      expect(find.text('December 2, 2013'), findsOneWidget);
      expect(find.text('Lawnmower Dog'), findsOneWidget);
    },
  );

  testWidgets(
    'Shows error view with retry when character API fails',
    (WidgetTester tester) async {
      final db = InMemoryAuthDatabase();
      final user = await db.registerUser(
        name: 'Summer',
        username: 'summer',
        password: 'password123',
      );
      await SessionService().saveSession(user);

      final deps = await _createAppDeps(
        db: db,
        httpClient: _createMockApiClient(failCharacters: true),
      );

      await tester.pumpWidget(
        RickMortyApp(
          authController: deps.authController,
          favoritesController: deps.favoritesController,
          apiService: deps.apiService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal Memuat Data'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    },
  );
}
