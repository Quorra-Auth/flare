import 'dart:async';
import 'dart:io' show Platform;

import 'package:dbus/dbus.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xdg_desktop_portal/xdg_desktop_portal.dart';

/// Provides light and dark system color schemes.
///
/// Wraps [DynamicColorBuilder]. On Linux it additionally watches the XDG
/// desktop portal so the schemes update live when the user changes the
/// accent color, which dynamic_color only reads once at startup.
class SystemColorBuilder extends StatefulWidget {
  final Widget Function(ColorScheme? light, ColorScheme? dark) builder;

  const SystemColorBuilder({super.key, required this.builder});

  @override
  State<SystemColorBuilder> createState() => _SystemColorBuilderState();
}

class _SystemColorBuilderState extends State<SystemColorBuilder> {
  static const _namespace = 'org.freedesktop.appearance';
  static const _key = 'accent-color';

  XdgDesktopPortalClient? _portal;
  StreamSubscription<XdgSettingChangeEvent>? _sub;
  ColorScheme? _light;
  ColorScheme? _dark;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isLinux) _watchAccent();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _portal?.close();
    super.dispose();
  }

  Future<void> _watchAccent() async {
    try {
      final portal = _portal = XdgDesktopPortalClient();
      _sub = portal.settings.settingChanged
          .where((e) => e.namespace == _namespace && e.key == _key)
          .listen((e) => _setAccent(_parse(e.value)));
      _setAccent(_parse(await portal.settings.read(_namespace, _key)));
    } catch (e) {
      debugPrint('Accent color portal unavailable: $e');
    }
  }

  Color? _parse(DBusValue value) {
    if (value is! DBusStruct || value.children.length != 3) return null;
    final c = value.children.map((v) => v.asDouble()).toList();
    // The portal reports out-of-range values when no accent is set.
    if (c.any((v) => v < 0 || v > 1)) return null;
    return Color.from(alpha: 1, red: c[0], green: c[1], blue: c[2]);
  }

  void _setAccent(Color? accent) {
    if (!mounted || accent == null) return;
    setState(() {
      _light = ColorScheme.fromSeed(seedColor: accent);
      _dark = ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (light, dark) => widget.builder(_light ?? light, _dark ?? dark),
    );
  }
}
