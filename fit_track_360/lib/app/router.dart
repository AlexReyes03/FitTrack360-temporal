import 'package:go_router/go_router.dart';

import '../core/session_storage.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/home/presentation/home_shell_page.dart';
import '../features/progress/presentation/progress_photo_page.dart';
import '../features/workouts/domain/workout_session_draft.dart';
import '../features/workouts/presentation/workouts_page.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};

final SessionStorage _sessionStorage = SessionStorage();

/// Rutas del shell. El redirect decide por presencia de access token:
/// sin token no se entra a /app; con token no se queda en pantallas de auth.
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final accessToken = await _sessionStorage.readAccessToken();
    final location = state.matchedLocation;
    final hasSession = accessToken != null;

    if (!hasSession && location.startsWith('/app')) return '/login';
    if (hasSession && _authRoutes.contains(location)) return '/app';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(path: '/app', builder: (context, state) => const HomeShellPage()),
    GoRoute(
      path: '/app/foto',
      builder: (context, state) => const ProgressPhotoPage(),
    ),
    GoRoute(
      path: '/app/entrenamientos',
      builder: (context, state) => WorkoutsPage(
        draft: state.extra is WorkoutSessionDraft
            ? state.extra as WorkoutSessionDraft
            : null,
      ),
    ),
  ],
);
