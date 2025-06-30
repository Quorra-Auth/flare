import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class ConfirmLoginPage extends StatelessWidget {
  final String message;
  const ConfirmLoginPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("You're about to sign in to $message"),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Confirm")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flare',
      home: MyHomePage(title: 'Quorra Flutter client'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _secureStorage = const FlutterSecureStorage();
  String _deepLinkText = 'Waiting for deep link...';
  String _activationStatus = "Checking...";
  final AppLinks _appLinks = AppLinks();
  static const _keyStorageKey = 'ed25519_private_key';
  var uuid = Uuid();

  @override
  void initState() {
    super.initState();

    _checkRegistrationStatus();

    _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _checkRegistrationStatus() async {
    final existingKey = await _secureStorage.read(key: _keyStorageKey);
    setState(() {
      _activationStatus = existingKey != null ? 'Device is registered' : 'Device is not registered';
    });
  }

  Future<String> signMessage(String message, KeyPair keyPair) async {
    final algorithm = Ed25519();
    final signature = await algorithm.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );

    return base64Encode(signature.bytes);
  }

  Future<String> getPublicKeyBase64(SimplePublicKey publicKey) async {
    return base64.encode(publicKey.bytes);
  }

  String extractServerAddress(Uri uri) {
    String scheme = "http";
    if (uri.scheme == "quorra+https") {
      scheme = "https";
    }
    final address = "$scheme://${uri.host}:${uri.port}";
    return address;
  }

  Future<void> sendRegistrationRequest(Uri uri, SimplePublicKey publicKey) async {
    final token = uri.queryParameters["t"];
    final address = extractServerAddress(uri);
    if (token == null) {
      _showMessage('No token found in URI');
      return;
    }

    final keyB64 = await getPublicKeyBase64(publicKey);

    final response = await http.post(
      Uri.parse("$address/mobile/register"),
      headers: {
        'Content-Type': 'application/json',
        'x-registration-token': token,
      },
      body: jsonEncode({
        'pubkey': keyB64,
        'name': "Flare"
      }),
    );

    if (response.statusCode != 201) {
      _showMessage(
          'Registration failed: ${response.statusCode}, ${response.body}');
    }
  }

  Future<void> sendIdentifyRequest(Uri uri, String message, String signature) async {
    final address = extractServerAddress(uri);
    final session = uri.queryParameters["s"];

    final response = await http.post(
      Uri.parse("$address/mobile/aqr/identify?session=$session"),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'signature': signature,
        'message': message
      }),
    );

    if (response.statusCode != 200) {
      _showMessage(
          'Request failed: ${response.statusCode}, ${response.body}');
    }
  }

  Future<void> sendAuthenticateRequest(Uri uri, String message, String signature, String state) async {
    final address = extractServerAddress(uri);
    final session = uri.queryParameters["s"];

    final response = await http.post(
      Uri.parse("$address/mobile/aqr/authenticate?session=$session"),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'signature': signature,
        'message': message,
        'state': state
      }),
    );

    if (response.statusCode != 200) {
      _showMessage(
          'Request failed: ${response.statusCode}, ${response.body}');
    }
  }

  void _handleUri(Uri uri) async {
    setState(() {
      _deepLinkText = uri.toString();
    });

    if (uri.path == '/mobile/register') {
      final existingKey = await _secureStorage.read(key: _keyStorageKey);
      if (existingKey != null) {
        _showMessage('A key already exists. Registration is only allowed once.');
        return;
      }

      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final privateKey = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      final base64Seed = base64Encode(privateKey);

      await sendRegistrationRequest(uri, publicKey);

      await _secureStorage.write(key: _keyStorageKey, value: base64Seed);

      setState(() {
        _activationStatus = 'Device is registered';
      });

      _showMessage('Key pair generated and stored!\nPublic key: ${publicKey.bytes}');
    }
    else if (uri.path == '/mobile/login') {
      final base64Seed = await _secureStorage.read(key: _keyStorageKey);
      if (base64Seed == null) {
        _showMessage('App not activated! Scan an activation code first!');
        return;
      }
      final seed = base64Decode(base64Seed);
      final keyPair = await Ed25519().newKeyPairFromSeed(seed);

      final message = "identify"; // ${uuid.v4()}
      final signature = await signMessage(message, keyPair);
      await sendIdentifyRequest(uri, message, signature);

      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmLoginPage(message: "whatever"),
        ),
      );
      if (confirmed == true) {
        await sendAuthenticateRequest(uri, "accepted accepted", signature, "accepted");
      } else {
        await sendAuthenticateRequest(uri, "rejected rejected", signature, "rejected");
      }
    }
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_activationStatus),
            Text(_deepLinkText, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
