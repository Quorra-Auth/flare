import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../pages/confirmation.dart';
import '../services/auth.dart';
import '../services/lnurl.dart';
import '../services/seed.dart';
import '../utils/bech32.dart';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _secureStorage = const FlutterSecureStorage();
  final _appLinks = AppLinks();

  late final SeedService _seedService;
  late final LnurlService _lnurlService;
  late final AuthService _authService;

  String _deepLinkText = 'Waiting for deep link...';
  String _seedStatus = 'Checking...';

  @override
  void initState() {
    super.initState();

    _seedService = SeedService(_secureStorage);
    _lnurlService = LnurlService();
    _authService = AuthService(_seedService);

    _initialize();
  }

  Future<void> _initialize() async {
    await _ensureSeedExists();
    _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _ensureSeedExists() async {
    await _seedService.ensureSeedExists();

    if (!mounted) return;
    setState(() {
      _seedStatus = 'LNURL-auth seed is ready';
    });
  }

  Future<void> _handleUri(Uri uri) async {
    if (!mounted) return;

    try {
      final decoded = decodeLnurlToUrl(uri.path);

      setState(() {
        _deepLinkText = decoded;
      });

      final request = _lnurlService.parseLnurlAuth(Uri.parse(decoded));

      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmLoginPage(
            domain: request.domain,
            action: request.action,
          ),
        ),
      );

      if (confirmed != true) {
        _showMessage('Login cancelled');
        return;
      }

      await _authService.sendLnurlAuth(request);
      _showMessage('LNURL-auth successful for ${request.domain}');
    } catch (e) {
      _showMessage('Failed to handle LNURL-auth: $e');
    }
  }

  void _showMessage(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_seedStatus),
              const SizedBox(height: 12),
              Text(_deepLinkText, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}