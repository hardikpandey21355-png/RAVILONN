import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_page.dart';

class RavilonApp extends StatelessWidget {
  const RavilonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ravilon',
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
