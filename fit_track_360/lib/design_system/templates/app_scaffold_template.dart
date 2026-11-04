import 'package:flutter/material.dart';
import '../widgets/app_background.dart';

class AppScaffoldTemplate extends StatelessWidget {
  final Widget body;

  const AppScaffoldTemplate({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(child: body),
    );
  }
}
