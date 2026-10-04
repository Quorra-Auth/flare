import 'package:material_ui/material_ui.dart';
import 'pages/home.dart';
import 'widgets/system_color_builder.dart';

class FlareApp extends StatelessWidget {
  const FlareApp({super.key});

  /// Fallback when the platform provides no dynamic colors.
  static const _seedColor = Colors.deepOrange;

  ThemeData _theme(ColorScheme? dynamicScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          dynamicScheme ??
          ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SystemColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Flare',
        debugShowCheckedModeBanner: false,
        theme: _theme(lightDynamic, Brightness.light),
        darkTheme: _theme(darkDynamic, Brightness.dark),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
