import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth_repo.dart';
import '../features/admin/masters/masters_screen.dart';
import '../features/admin/users/users_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}

/// Pure route guard helper used by [routerProvider] and unit tests.
String? resolveRouteRedirect({
  required String matchedLocation,
  required bool isAuthenticated,
  required bool? isAdmin,
}) {
  final isLoggingIn = matchedLocation == '/login';

  if (!isAuthenticated) {
    return isLoggingIn ? null : '/login';
  }
  if (isLoggingIn) {
    return '/';
  }
  if (matchedLocation.startsWith('/admin') && isAdmin == false) {
    return '/';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = ref.read(authRepoProvider).currentUser;
      final profileAsync = ref.read(currentProfileProvider);
      final isAdmin = profileAsync.hasValue
          ? (profileAsync.value?.isAdmin ?? false)
          : null;
      return resolveRouteRedirect(
        matchedLocation: state.matchedLocation,
        isAuthenticated: user != null,
        isAdmin: isAdmin,
      );
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: '/admin/masters',
        builder: (context, state) => const MastersScreen(),
      ),
    ],
  );
});
