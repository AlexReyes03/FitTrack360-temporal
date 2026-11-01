import 'package:flutter/material.dart';

import 'core/session_storage.dart';
import 'core/widgets/offline_banner.dart';
import 'design_system/tokens/app_colors.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: ColorScheme.dark(
          surface: AppColors.bgDeep,
          primary: AppColors.accentWhite,
          onPrimary: AppColors.textOnAccent,
          onSurface: AppColors.textPrimary,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SessionStorage _sessionStorage = SessionStorage();
  bool? _hasToken;

  @override
  void initState() {
    super.initState();
    _refreshSessionState();
  }

  Future<void> _refreshSessionState() async {
    final token = await _sessionStorage.readAccessToken();
    if (!mounted) return;
    setState(() => _hasToken = token != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            OfflineBanner(onRetry: _refreshSessionState),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'FitTrack360',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasToken == null
                ? ''
                : (_hasToken! ? 'Sesion guardada' : 'Sin sesion'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
              await _refreshSessionState();
            },
            child: const Text('Iniciar sesion'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              );
              await _refreshSessionState();
            },
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
