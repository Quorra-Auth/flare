import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32_plus/bip32_plus.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sec/sec.dart';

import '../models/derived_linking_key.dart';
import '../models/lnurl_auth_request.dart';
import '../utils/crypto.dart';
import 'seed.dart';

class AuthService {
  final SeedService seedService;
  final _secp256k1 = EC.secp256k1;

  AuthService(this.seedService);

  List<int> lnurlAuthDerivationPath(String domain) {
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

  Future<DerivedLinkingKey> deriveLinkingKey(String domain) async {
    final seed = await seedService.getMasterSeed();
    bip32.BIP32 node = bip32.BIP32.fromSeed(seed);

    final path = lnurlAuthDerivationPath(domain);
    for (final index in path) {
      node = node.deriveHardened(index);
    }

    final privateKeyBytes = node.privateKey;
    if (privateKeyBytes == null || privateKeyBytes.length != 32) {
      throw Exception('Failed to derive LNURL-auth private key');
    }

    final privateKey = bytesToBigInt(privateKeyBytes);
    if (privateKey == BigInt.zero) {
      throw Exception('Derived invalid private key');
    }

    final compressedPublicKey = _secp256k1.createPublicKey(privateKey, true);

    return DerivedLinkingKey(
      privateKey: privateKey,
      compressedPublicKey: compressedPublicKey,
    );
  }

  Future<String> signK1Hex(String k1Hex, BigInt privateKey) async {
    final message = Uint8List.fromList(hex.decode(k1Hex));
    if (message.length != 32) {
      throw Exception('k1 must decode to 32 bytes');
    }

    final signature = _secp256k1.generateSignature(privateKey, message, true);
    final der = encodeDerSignature(signature.r, signature.s);
    return hex.encode(der);
  }

  Future<void> sendLnurlAuth(LnurlAuthRequest request) async {
    final linkingKey = await deriveLinkingKey(request.domain);
    final sigHex = await signK1Hex(request.k1, linkingKey.privateKey);
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
}