import 'package:go_router/go_router.dart';

import '../core/async_state.dart';
import '../core/network/api_client.dart';
import '../core/session_storage.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/exercises/data/exercise.dart';
import '../features/exercises/presentation/exercise_detail_page.dart';
import '../features/exercises/presentation/exercises_page.dart';
import '../features/home/presentation/app_shell_page.dart';
import '../features/home/presentation/home_shell_page.dart';
import '../features/meals/data/foods_api_repository.dart';
import '../features/meals/domain/food_search_repository.dart';
import '../features/meals/presentation/food_search_page.dart';
import '../features/meals/presentation/meals_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/progress/domain/progress_photo.dart';
import '../features/progress/presentation/photo_comparison_page.dart';
import '../features/progress/presentation/progress_photo_page.dart';
import '../features/progress/presentation/progress_shell_page.dart';
import '../features/routines/presentation/routine_detail_page.dart';
import '../features/routines/presentation/routines_page.dart';
import '../features/settings/presentation/privacy_notice_page.dart';
import '../features/settings/presentation/profile_page.dart';
import '../features/workouts/domain/workout_session_draft.dart';
import '../features/workouts/presentation/tracker_session_page.dart';
import '../features/workouts/presentation/workout_detail_page.dart';
import '../features/workouts/presentation/workouts_page.dart';

const _authRoutes = {'/login', '/register', '/forgot-password'};

/// Path del tracker de sesion activa (W11-09).
const appTrackerPath = '/app/tracker';

/// Path de busqueda USDA registrado en GoRouter (antes era Navigator.push).
const appFoodSearchPath = '/app/comidas/buscar';

/// Aviso de privacidad. Ruta pública: se consulta desde el registro antes de
/// aceptar el consentimiento y también con sesión iniciada.
const appPrivacyNoticePath = '/aviso-privacidad';

/// Path del centro de notificaciones.
const appNotificationsPath = '/app/notificaciones';

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

/// Arbol de rutas de la app. Exportado para pruebas de contrato del router.
///
/// Las 6 vistas principales viven en ramas de [StatefulShellRoute.indexedStack]
/// para conservar su estado y compartir el header y la barra inferior. Las
/// rutas secundarias quedan fuera del shell o anidadas en su rama, sin perder
/// su path publico.
List<RouteBase> buildAppRoutes() {
  return [
    GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => ForgotPasswordPage(
        initialEmail: state.extra is String ? state.extra as String : null,
      ),
    ),
    GoRoute(
      path: appPrivacyNoticePath,
      builder: (context, state) => const PrivacyNoticePage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShellPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app',
              builder: (context, state) => const HomeShellPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/entrenamientos',
              builder: (context, state) => WorkoutsPage(
                draft: state.extra is WorkoutSessionDraft
                    ? state.extra as WorkoutSessionDraft
                    : null,
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      WorkoutDetailPage(sessionId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/comidas',
              builder: (context, state) => const MealsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/ejercicios',
              builder: (context, state) => const ExercisesPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ExerciseDetailPage(
                    exerciseId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/progreso',
              builder: (context, state) => const ProgressShellPage(),
              routes: [
                GoRoute(
                  path: 'comparar',
                  builder: (context, state) {
                    final comparison = state.extra;
                    return PhotoComparisonPage(
                      state: comparison is PhotoComparison
                          ? AsyncData<PhotoComparison>(comparison)
                          : const AsyncEmpty<PhotoComparison>(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/app/perfil',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: appNotificationsPath,
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/app/foto',
      builder: (context, state) => const ProgressPhotoPage(),
    ),
    GoRoute(
      path: appTrackerPath,
      builder: (context, state) {
        final extra = state.extra;
        final args = extra is TrackerSessionArgs
            ? extra
            : extra is Exercise
            ? TrackerSessionArgs(exercise: extra)
            : null;
        return TrackerSessionPage(args: args);
      },
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
      path: '/app/rutinas',
      builder: (context, state) => const RoutinesPage(),
    ),
    GoRoute(
      path: '/app/rutinas/:id',
      builder: (context, state) =>
          RoutineDetailPage(routineId: state.pathParameters['id']!),
    ),
  ];
}

/// Router de la app. El redirect decide por presencia de ID token Firebase.
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) => resolveAppSessionRedirect(state),
  routes: buildAppRoutes(),
);
