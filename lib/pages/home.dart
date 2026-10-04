import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../pages/confirmation.dart';
import '../services/auth.dart';
import '../services/lnurl.dart';
import '../services/seed.dart';
import '../utils/bech32.dart';
import '../widgets/centered_content.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _appLinks = AppLinks();
  final _lnurlService = LnurlService();

  late final SeedService _seedService;
  late final AuthService _authService;
  StreamSubscription<Uri>? _linkSub;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seedService = SeedService(const FlutterSecureStorage());
    _authService = AuthService(_seedService);
    _initialize();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _seedService.ensureSeedExists();
      _linkSub ??= _appLinks.uriLinkStream.listen(_handleUri);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleUri(Uri uri) async {
    if (!mounted || _loading || _error != null) return;

    try {
      final decoded = decodeLnurlToUrl(uri.path);
      final request = _lnurlService.parseLnurlAuth(Uri.parse(decoded));

      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmLoginPage(
            domain: request.domain,
            action: request.action,
            onConfirm: () => _authService.sendLnurlAuth(request),
          ),
        ),
      );

      _showMessage(
        confirmed == true
            ? 'Signed in to ${request.domain}'
            : 'Login cancelled',
      );
    } catch (e) {
      _showMessage(
        "Couldn't open this link: ${e.toString().replaceFirst('Exception: ', '')}",
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget content;
    if (_loading) {
      content = const CircularProgressIndicator();
    } else if (_error != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 72, color: scheme.error),
          const SizedBox(height: 24),
          Text('Something went wrong', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _initialize,
            child: const Text('Retry'),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 72, color: scheme.primary),
          const SizedBox(height: 24),
          Text('Flare is ready', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Open an LNURL-auth link or scan a login code to sign in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Flare')),
      body: CenteredContent(child: content),
    );
  }
}
