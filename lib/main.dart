import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:bip32_plus/bip32_plus.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sec/sec.dart';
import 'package:bitcoin_bech32_ng/bitcoin_bech32_ng.dart';

void main() {
  runApp(const MyApp());
}

class ConfirmLoginPage extends StatelessWidget {
  final String domain;
  final String action;

  const ConfirmLoginPage({
    super.key,
    required this.domain,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final actionText = switch (action) {
      'register' => 'register an account at',
      'link' => 'link your account at',
      'auth' => 'authenticate with',
      _ => 'sign in to',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm LNURL-auth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("You're about to $actionText $domain"),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LnurlAuthRequest {
  final Uri callback;
  final String k1;
  final String action;
  final String domain;

  LnurlAuthRequest({
    required this.callback,
    required this.k1,
    required this.action,
    required this.domain,
  });
}

class DerivedLinkingKey {
  final BigInt privateKey;
  final Uint8List compressedPublicKey;

  DerivedLinkingKey({
    required this.privateKey,
    required this.compressedPublicKey,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flare',
      home: MyHomePage(title: 'LNURL-auth client'),
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
  static const _seedStorageKey = 'lnurl_auth_master_seed';

  final _secureStorage = const FlutterSecureStorage();
  final _appLinks = AppLinks();
  final _secp256k1 = EC.secp256k1;
  final _codec = Bech32Codec();

  String _deepLinkText = 'Waiting for deep link...';
  String _seedStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _ensureSeedExists();
    _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _ensureSeedExists() async {
    var seedHex = await _secureStorage.read(key: _seedStorageKey);

    if (seedHex == null) {
      final seed = _secureRandomBytes(32);
      seedHex = hex.encode(seed);
      await _secureStorage.write(key: _seedStorageKey, value: seedHex);
    }

    if (!mounted) return;
    setState(() {
      _seedStatus = 'LNURL-auth seed is ready';
    });
  }

  Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Future<Uint8List> _getMasterSeed() async {
    final seedHex = await _secureStorage.read(key: _seedStorageKey);
    if (seedHex == null) {
      throw Exception('No seed found');
    }
    return Uint8List.fromList(hex.decode(seedHex));
  }

  LnurlAuthRequest _parseLnurlAuth(Uri uri) {
    Uri callback;

    if (uri.queryParameters['tag'] == 'login' && uri.queryParameters['k1'] != null) {
      callback = uri;
    } else {
      throw Exception('Unsupported LNURL-auth link format');
    }

    final tag = callback.queryParameters['tag'];
    final k1 = callback.queryParameters['k1'];
    final action = callback.queryParameters['action'] ?? 'login';

    if (tag != 'login') {
      throw Exception('Not an LNURL-auth request');
    }

    if (k1 == null || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(k1)) {
      throw Exception('Invalid or missing k1');
    }

    if (callback.host.isEmpty) {
      throw Exception('Missing callback host');
    }

    return LnurlAuthRequest(
      callback: callback,
      k1: k1.toLowerCase(),
      action: action,
      domain: callback.host.toLowerCase(),
    );
  }

  List<int> _lnurlAuthDerivationPath(String domain) {
    final digest = sha256.convert(utf8.encode(domain)).bytes;

    int toUInt31(List<int> bytes, int offset) {
      return ((bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3]) &
      0x7fffffff;
    }

    return [
      138,
      toUInt31(digest, 0),
      toUInt31(digest, 4),
      toUInt31(digest, 8),
      toUInt31(digest, 12),
    ];
  }

  Future<DerivedLinkingKey> _deriveLinkingKey(String domain) async {
    final seed = await _getMasterSeed();
    bip32.BIP32 node = bip32.BIP32.fromSeed(seed);

    final path = _lnurlAuthDerivationPath(domain);
    for (final index in path) {
      node = node.deriveHardened(index);
    }

    final privateKeyBytes = node.privateKey;
    if (privateKeyBytes == null || privateKeyBytes.length != 32) {
      throw Exception('Failed to derive LNURL-auth private key');
    }

    final privateKey = _bytesToBigInt(privateKeyBytes);
    if (privateKey == BigInt.zero) {
      throw Exception('Derived invalid private key');
    }

    final compressedPublicKey = _secp256k1.createPublicKey(privateKey, true);

    return DerivedLinkingKey(
      privateKey: privateKey,
      compressedPublicKey: compressedPublicKey,
    );
  }

  Future<String> _signK1Hex(String k1Hex, BigInt privateKey) async {
    final message = Uint8List.fromList(hex.decode(k1Hex));
    if (message.length != 32) {
      throw Exception('k1 must decode to 32 bytes');
    }

    final signature = _secp256k1.generateSignature(privateKey, message, true);
    final der = _encodeDerSignature(signature.r, signature.s);
    return hex.encode(der);
  }

  Uint8List _encodeDerSignature(BigInt r, BigInt s) {
    final rBytes = _encodeDerInteger(r);
    final sBytes = _encodeDerInteger(s);

    final sequence = <int>[
      0x30,
      rBytes.length + sBytes.length,
      ...rBytes,
      ...sBytes,
    ];

    return Uint8List.fromList(sequence);
  }

  List<int> _encodeDerInteger(BigInt value) {
    if (value < BigInt.zero) {
      throw Exception('DER integer must be non-negative');
    }

    var bytes = _bigIntToBytes(value);

    while (bytes.length > 1 && bytes[0] == 0x00 && (bytes[1] & 0x80) == 0) {
      bytes = bytes.sublist(1);
    }

    if (bytes.isEmpty) {
      bytes = [0x00];
    }

    if ((bytes[0] & 0x80) != 0) {
      bytes = [0x00, ...bytes];
    }

    return [
      0x02,
      bytes.length,
      ...bytes,
    ];
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    return BigInt.parse(hex.encode(bytes), radix: 16);
  }

  List<int> _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return [0];
    }

    var hexStr = value.toRadixString(16);
    if (hexStr.length.isOdd) {
      hexStr = '0$hexStr';
    }
    return hex.decode(hexStr);
  }

  Future<void> _sendLnurlAuth(LnurlAuthRequest request) async {
    final linkingKey = await _deriveLinkingKey(request.domain);
    final sigHex = await _signK1Hex(request.k1, linkingKey.privateKey);
    final keyHex = hex.encode(linkingKey.compressedPublicKey);

    final callbackUri = request.callback.replace(
      queryParameters: {
        ...request.callback.queryParameters,
        'sig': sigHex,
        'key': keyHex,
      },
    );

    final response = await http.get(callbackUri);

    if (response.statusCode != 200) {
      throw Exception('LNURL-auth failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['status'] != 'OK') {
      throw Exception('LNURL-auth rejected: ${response.body}');
    }
  }

  String decodeLnurlToUrl(String lnurl) {
    final bech32Data = bech32.decode(lnurl, lnurl.length);

    final bytes = _convertBits(bech32Data.data, 5, 8, false);
    return utf8.decode(bytes);
  }

  Uri decodeLnurlToUri(String lnurl) {
    final url = decodeLnurlToUrl(lnurl);
    return Uri.parse(url);
  }

  List<int> _convertBits(
      List<int> data,
      int fromBits,
      int toBits,
      bool pad,
      ) {
    int acc = 0;
    int bits = 0;
    final result = <int>[];
    final maxv = (1 << toBits) - 1;
    final maxAcc = (1 << (fromBits + toBits - 1)) - 1;

    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        throw FormatException('Invalid value: $value');
      }

      acc = ((acc << fromBits) | value) & maxAcc;
      bits += fromBits;

      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxv);
      }
    }

    if (pad) {
      if (bits > 0) {
        result.add((acc << (toBits - bits)) & maxv);
      }
    } else {
      if (bits >= fromBits) {
        throw const FormatException('Excess padding');
      }
      if (((acc << (toBits - bits)) & maxv) != 0) {
        throw const FormatException('Non-zero padding');
      }
    }

    return result;
  }

  Future<void> _handleUri(Uri uri) async {
    if (!mounted) return;
    final decoded = decodeLnurlToUrl(uri.path);

    setState(() {
      _deepLinkText = decoded;
    });

    try {
      final request = _parseLnurlAuth(Uri.parse(decoded));

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

      await _sendLnurlAuth(request);
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