import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/async_state.dart';
import '../core/network/api_client.dart';
import '../core/session_storage.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/exercises/presentation/exercise_detail_page.dart';
import '../features/exercises/presentation/exercises_page.dart';
import '../features/home/presentation/home_shell_page.dart';
import '../features/home/presentation/widgets/nav_placeholder_page.dart';
import '../features/meals/data/foods_api_repository.dart';
import '../features/meals/domain/food_search_repository.dart';
import '../features/meals/presentation/food_search_page.dart';
import '../features/meals/presentation/meals_page.dart';
import '../features/progress/domain/progress_photo.dart';
import '../features/progress/presentation/photo_comparison_page.dart';
import '../features/progress/presentation/progress_photo_page.dart';
import '../features/progress/presentation/progress_shell_page.dart';
import '../features/routines/presentation/routine_detail_page.dart';
import '../features/routines/presentation/routines_page.dart';
import '../features/settings/presentation/profile_page.dart';
import '../features/workouts/domain/workout_session_draft.dart';
import '../features/workouts/presentation/workout_detail_page.dart';
import '../features/workouts/presentation/workouts_page.dart';

const _authRoutes = {'/login', '/register', '/forgot-password'};

/// Path del placeholder del tracker diario (W11-09 lo llenara).
const appTrackerPath = '/app/tracker';

/// Path de busqueda USDA registrado en GoRouter (antes era Navigator.push).
const appFoodSearchPath = '/app/comidas/buscar';

/// Contrato de sesion del shell: sin token no se entra a `/app*`; con token no
/// se queda en pantallas de auth. Exportado para pruebas de contrato.
Future<String?> resolveAppSessionRedirect(GoRouterState state) async {
  final accessToken = await appSessionStorage.readAccessToken();
  final location = state.matchedLocation;
  final hasSession = accessToken != null;

  if (!hasSession && location.startsWith('/app')) return '/login';
  if (hasSession && _authRoutes.contains(location)) return '/app';
  return null;
}

/// Rutas del shell. El redirect decide por presencia de ID token Firebase.
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) => resolveAppSessionRedirect(state),
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
      path: '/app/progreso',
      builder: (context, state) => const ProgressShellPage(),
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
      path: appTrackerPath,
      builder: (context, state) => NavPlaceholderPage(
        title: 'Tracker',
        subtitle:
            'El tracker diario se implementara en la tarea W11-09. '
            'Esta ruta ya queda registrada para la navegacion de W11.',
        icon: Icons.insights_rounded,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/app');
          }
        },
      ),
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
      path: appFoodSearchPath,
      builder: (context, state) {
        final extra = state.extra;
        final repository = extra is FoodSearchRepository
            ? extra
            : FoodsApiRepository.fromClient(ApiClient());
        return FoodSearchPage(repository: repository);
      },
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
    GoRoute(
      path: '/app/rutinas',
      builder: (context, state) => const RoutinesPage(),
    ),
    GoRoute(
      path: '/app/rutinas/:id',
      builder: (context, state) =>
          RoutineDetailPage(routineId: state.pathParameters['id']!),
    ),
  ],
);
