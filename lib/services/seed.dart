import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/crypto.dart';

class SeedService {
  static const seedStorageKey = 'lnurl_auth_master_seed';

  final FlutterSecureStorage secureStorage;

  const SeedService(this.secureStorage);

  Future<void> ensureSeedExists() async {
    var seedHex = await secureStorage.read(key: seedStorageKey);

    if (seedHex == null) {
      final seed = secureRandomBytes(32);
      seedHex = hex.encode(seed);
      await secureStorage.write(key: seedStorageKey, value: seedHex);
    }
  }

  Future<Uint8List> getMasterSeed() async {
    final seedHex = await secureStorage.read(key: seedStorageKey);
    if (seedHex == null) {
      throw Exception('No seed found');
    }
    return Uint8List.fromList(hex.decode(seedHex));
  }
}