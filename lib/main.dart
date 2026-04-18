import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/database.dart';
import 'core/theme.dart';
import 'screens/card_editor_screen.dart';
import 'screens/deck_screen.dart';
import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'screens/stats_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open (and on first launch, create + seed) the DB before first frame.
  await AppDatabase.instance.database;
  runApp(const StudyDeckApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomeScreen(),
    ),
    GoRoute(
      path: '/stats',
      builder: (_, _) => const StatsScreen(),
    ),
    GoRoute(
      path: '/deck/:deckId',
      builder: (_, state) {
        final id = int.parse(state.pathParameters['deckId']!);
        return DeckScreen(deckId: id);
      },
    ),
    GoRoute(
      path: '/deck/:deckId/review',
      builder: (_, state) {
        final id = int.parse(state.pathParameters['deckId']!);
        return ReviewScreen(deckId: id);
      },
    ),
    GoRoute(
      path: '/deck/:deckId/card/new',
      builder: (_, state) {
        final id = int.parse(state.pathParameters['deckId']!);
        return CardEditorScreen(deckId: id);
      },
    ),
    GoRoute(
      path: '/deck/:deckId/card/:cardId/edit',
      builder: (_, state) {
        final deckId = int.parse(state.pathParameters['deckId']!);
        final cardId = int.parse(state.pathParameters['cardId']!);
        return CardEditorScreen(deckId: deckId, cardId: cardId);
      },
    ),
  ],
);

class StudyDeckApp extends StatelessWidget {
  const StudyDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StudyDeck',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
