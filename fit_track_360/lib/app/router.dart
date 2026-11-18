import 'package:go_router/go_router.dart';

import '../core/async_state.dart';
import '../core/session_storage.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/exercises/presentation/exercise_detail_page.dart';
import '../features/exercises/presentation/exercises_page.dart';
import '../features/home/presentation/home_shell_page.dart';
import '../features/meals/presentation/meals_page.dart';
import '../features/progress/domain/progress_photo.dart';
import '../features/progress/presentation/photo_comparison_page.dart';
import '../features/progress/presentation/progress_photo_page.dart';
import '../features/settings/presentation/profile_page.dart';
import '../features/workouts/domain/workout_session_draft.dart';
import '../features/workouts/presentation/workout_detail_page.dart';
import '../features/workouts/presentation/workouts_page.dart';

const _authRoutes = {'/login', '/register', '/forgot-password'};

/// Rutas del shell. El redirect decide por presencia de ID token Firebase:
/// sin sesión no se entra a /app; con sesión no se queda en pantallas de auth.
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final accessToken = await appSessionStorage.readAccessToken();
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
    GoRoute(path: '/app', builder: (context, state) => const HomeShellPage()),
    GoRoute(
      path: '/app/foto',
      builder: (context, state) => const ProgressPhotoPage(),
    ),
    GoRoute(
      path: '/app/progreso/comparar',
      builder: (context, state) {
        final comparison = state.extra;
        return PhotoComparisonPage(
          state: comparison is PhotoComparison
              ? AsyncData<PhotoComparison>(comparison)
              : const AsyncEmpty<PhotoComparison>(),
        );
      },
    ),
    GoRoute(
      path: '/app/entrenamientos',
      builder: (context, state) => WorkoutsPage(
        draft: state.extra is WorkoutSessionDraft
            ? state.extra as WorkoutSessionDraft
            : null,
      ),
    ),
    GoRoute(
      path: '/app/entrenamientos/:id',
      builder: (context, state) =>
          WorkoutDetailPage(sessionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/app/perfil',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/app/comidas',
      builder: (context, state) => const MealsPage(),
    ),
    GoRoute(
      path: '/app/ejercicios',
      builder: (context, state) => const ExercisesPage(),
    ),
    GoRoute(
      path: '/app/ejercicios/:id',
      builder: (context, state) =>
          ExerciseDetailPage(exerciseId: state.pathParameters['id']!),
    ),
  ],
);
