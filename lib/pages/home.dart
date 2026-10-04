import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../pages/confirmation.dart';
import '../pages/scanner.dart';
import '../services/auth.dart';
import '../services/lnurl.dart';
import '../services/seed.dart';
import '../utils/bech32.dart';
import '../utils/lnurl_input.dart';
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

  static final _canScan = Platform.isAndroid || Platform.isIOS;

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
      if (!mounted) return;
      setState(() => _loading = false);
      // Subscribe only once ready: app_links replays a startup link on listen.
      _linkSub ??= _appLinks.uriLinkStream.listen(_handleUri);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleUri(Uri uri) =>
      _handleLnurl(extractLnurl(uri.toString()));

  Future<void> _scan() async {
    final lnurl = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (lnurl != null) await _handleLnurl(lnurl);
  }

  Future<void> _handleLnurl(String? lnurl) async {
    if (!mounted || _loading || _error != null) return;

    try {
      if (lnurl == null) throw Exception('Not an LNURL link');
      final decoded = decodeLnurlToUrl(lnurl);
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
            _canScan
                ? 'Open an LNURL-auth link or scan a login code to sign in.'
                : 'Open an LNURL-auth link to sign in.',
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
      floatingActionButton: _canScan && !_loading && _error == null
          ? FloatingActionButton.extended(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR code'),
            )
          : null,
      body: CenteredContent(child: content),
    );
  }
}
