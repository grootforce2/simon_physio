import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/session/session_player_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
    GoRoute(path: '/session', builder: (c, s) => const SessionPlayerScreen()),
  ],
);
